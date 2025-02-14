using ChainRulesTestUtils
using ChainRulesCore
using FiniteDifferences
using Enzyme
using PythonCall
using FFTW
using StructArrays
using StaticArrays
using Distributions
using VLBIImagePriors
using StaticArrays
using Tables
using Plots
import TransformVariables as TV
using VLBIImagePriors

ntequal(x::NamedTuple{N}, y::NamedTuple{N}) where {N} = map(_ntequal, (x), (y))
ntequal(x, y) = false
_ntequal(x::T, y::T) where {T<:NamedTuple} = ntequal(values(x), values(y))
_ntequal(x::T, y::T) where {T<:Tuple} = map(_ntequal, x, y)
_ntequal(x, y) = x ≈ y

function build_mfvis(vistuple...)
    configs = arrayconfig.(vistuple)
    vis = vistuple[1]
    newdatatables = Stoked.StructArray(reduce(vcat, Stoked.datatable.(configs)))
    newscans = reduce(vcat, getproperty.(configs, :scans))
    newconfig = Stoked.EHTArrayConfiguration(vis.config.bandwidth,
                                              vis.config.tarr,
                                              newscans,
                                              vis.config.mjd,
                                              vis.config.ra,
                                              vis.config.dec,
                                              vis.config.source,
                                              :UTC,
                                              newdatatables)
    newmeasurement = reduce(vcat, Stoked.measurement.(vistuple))
    newnoise = reduce(vcat, Stoked.noise.(vistuple))

    return Stoked.EHTObservationTable{Stoked.datumtype(vis)}(newmeasurement,newnoise,newconfig)
end


function isequalmissing(x, y)
    xm = x |> ismissing |> collect
    ym = y |> ismissing |> collect
    return xm == ym
end


function test_caltable(c1, sites)
    @test Tables.istable(typeof(c1))
    @test Tables.rowaccess(typeof(c1))
    @test Tables.rows(c1) === c1
    @test Tables.columnaccess(c1)
    clmns = Tables.columns(c1)
    @test clmns[1] == Stoked.times(c1)
    @test clmns[2] == Stoked.frequencies(c1)
    @test Bool(prod(skipmissing(Tables.matrix(clmns)[:,begin+2:end]) .== skipmissing(Stoked.gmat(c1))))
    @test c1.Ti == Stoked.times(c1)
    @test c1.Ti == Tables.getcolumn(c1, 1)
    @test c1.Fr == Stoked.frequencies(c1)
    @test c1.Fr == Tables.getcolumn(c1, 2)
    @test isequalmissing(c1.AA, Tables.getcolumn(c1, 3))

    @test maximum(abs, skipmissing(c1.AA) .- skipmissing(Tables.getcolumn(c1, :AA))) ≈ 0
    @test maximum(abs, skipmissing(c1.AA) .- skipmissing(Tables.getcolumn(c1, 3))) ≈ 0
    @test Tables.columnnames(c1) == [:Ti, :Fr, sites...]

    c1row = Tables.getrow(c1, 30)
    @test eltype(c1) == typeof(c1row)
    @test c1row.Ti == c1.Ti[30]
    @test c1row.AA == c1.AA[30]
    @test c1row.Fr == c1.Fr[30]
    @test Tables.getcolumn(c1row, :AA) == c1.AA[30]
    @test Tables.getcolumn(c1row, :Ti) == c1.Ti[30]
    @test Tables.getcolumn(c1row, :Fr) == c1.Fr[30]
    @test Tables.getcolumn(c1row, 3) == c1.AA[30]
    @test Tables.getcolumn(c1row, 2) == c1.Fr[30]
    @test Tables.getcolumn(c1row, 1) == c1.Ti[30]
    @test propertynames(c1) == propertynames(c1row) == [:Ti, :Fr, sites...]
    @test Tables.getcolumn(c1row, Float64, 1, :Ti) == c1.Ti[30]
    @test Tables.getcolumn(c1row, Float64, 2, :Fr) == c1.Fr[30]
    @test Tables.getcolumn(c1row, Float64, 3, :AA) == c1.AA[30]
    @test isequalmissing(c1[1:10, :AA], c1.AA[1:10])
    @test isequalmissing(c1[[1,2], :AA], c1.AA[[1,2]])
    @test isequalmissing(@view(c1[1:10, :AA]), @view(c1.AA[1:10]))
    @test isequalmissing(@view(c1[[1,2], :AA]), @view(c1.AA[[1,2]]))

    Tables.schema(c1) isa Tables.Schema
    Tables.getcolumn(c1, Float64, 1, :test)
    Tables.getcolumn(c1, Float64, 2, :test)

    c1[1, :AA]
    c1[!, :AA]
    c1[:, :AA]
    @test length(c1) == length(c1.AA)
    @test c1[1 ,:] isa Stoked.CalTableRow
    @test length(Tables.getrow(c1, 1:5)) == 5

    Plots.plot(c1)
    Plots.plot(c1, datagains=true)
    Plots.plot(c1, sites=(:AA,))
    plotcaltable(c1)

    show(c1)
end

@testset "SkyModel" begin

    f = test_model
    g = imagepixels(μas2rad(150.0), μas2rad(150.0), 256, 256)
    skym = SkyModel(f, test_prior(), g)
    show(IOBuffer(), MIME"text/plain"(), skym)

    x = rand(Stoked.NamedDist(test_prior()))
    m = Stoked.skymodel(skym, x)
    skyf = FixedSkyModel(m, g)

    @testset "ObservedSkyModel" begin
        _,vis, amp, lcamp, cphase = load_data()

        oskym, = Stoked.set_array(skym, arrayconfig(vis))
        oskyf, = Stoked.set_array(skyf, arrayconfig(vis))

        @test Stoked.skymodel(oskym, x) == m
        @test Stoked.idealvisibilities(oskym, (;sky=x)) ≈ Stoked.idealvisibilities(oskyf, (;sky=x))
    end
end

@testset "GMRF" begin
    δ = rand(GMRF(64.0, (128, 128)))
    m = modify(Gaussian(), Stretch(μas2rad(40.0)))
    g = imagepixels(μas2rad(150.0), μas2rad(150.0), 128, 128)
    img = apply_fluctuations(exp, m, g, δ)
    mimg = intensitymap(m, g)
    img2 = apply_fluctuations(exp, mimg, δ)
    @test img isa IntensityMap
    @test img2 ≈ img

    img3 = apply_fluctuations(mimg, δ)

    img4 = apply_fluctuations(CenteredLR(), m, g, δ)
    @test_throws ArgumentError apply_fluctuations(CenteredLR(), mimg, δ)
    img5 = apply_fluctuations(CenteredLR(), mimg./flux(mimg), δ)
    @test img4 ≈ img5

end

function FiniteDifferences.to_vec(k::SiteArray)
    v, b = to_vec(parent(k))
    back(x) = SiteArray(b(x), k.times, k.frequencies, k.sites)
    return v, back
end


@testset "InstrumentModel" begin
    _,dvis, amp, lcamp, cphase, dcoh = load_data()


    @testset "SiteArray" begin

        G = SingleStokesGain(x->exp(x.lg + 1im*x.gp))
        intprior = (lg = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1))),
                    gp = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, inv(π^2))); refant=SEFDReference(0.0))
                    )

        intm = InstrumentModel(G, intprior)
        ointm, printm = Stoked.set_array(intm, arrayconfig(dvis))
        show(IOBuffer(), MIME"text/plain"(), ointm)
        x = rand(printm)
        sl = Stoked.SiteLookup(x.lg)

        @test sl isa Stoked.SiteLookup
        s2 =  SiteArray(parent(x.lg), sl)
        @test s2 == x.lg
        @test Stoked.times(s2) == Stoked.times(x.lg)
        @test Stoked.frequencies(s2) == Stoked.frequencies(x.lg)
        @test Stoked.sites(s2) == Stoked.sites(x.lg)

        @test Stoked.sitemap(exp, parent(x.lg), sl) ≈ exp.(x.lg)
        Stoked.sitemap(cumsum, parent(x.lg), sl)

        @test x.lg[1] == parent(x.lg)[1]
        x.lg[1] = 1.0
        @test x.lg[1] == 1.0

        sarr = x.lg[1:16]
        @test_throws DimensionMismatch similar(sarr, Float64, (4,4)) isa Stoked.SiteArray

        @test Stoked.SiteArray(x.lg, sl) == x.lg

        @inferred Stoked.time(x.lg, 5.0..6.0)
        @inferred Stoked.frequency(x.lg, 1.0..400.0)

        @test x.lg ≈ SiteArray(x.lg, x.lg.times, x.lg.frequencies, x.lg.sites)
        @inferred x.lg[1,1,1]
        x.lg[1,1,1,1] = 1.0
        @test x.lg[1] ≈ 1.0

        # ps = ProjectTo(x.lg)
        # @test ps(x.lg) == x.lg
        # @test ps(NoTangent()) isa NoTangent
        # @test ps(Tangent{typeof(x.lg)}(data = parent(x.lg))) == x.lg

    end

    @testset "StokesI" begin
        vis = Stoked.measurement(dvis)

        G = SingleStokesGain(x->exp(x.lg + 1im*x.gp))
        intprior = (lg = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1))),
                    gp = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, inv(π^2))); refant=SEFDReference(0.0))
                    )

        intm = InstrumentModel(G, intprior)
        show(IOBuffer(), MIME"text/plain"(), intm)

        ointm, printm = Stoked.set_array(intm, arrayconfig(dvis))
        x = rand(printm)
        x.lg .= 0
        x.gp .= 0
        vout = Stoked.apply_instrument(vis, ointm, (;instrument=x))
        # test_rrule(Stoked.apply_instrument, vis, ointm⊢NoTangent(), (;instrument=x))
        @test vout ≈ vis


        ointid, pr = Stoked.set_array(Stoked.IdealInstrumentModel(), arrayconfig(dvis))
        vout = Stoked.apply_instrument(vis, ointid, (;))
        @test vout ≈ vis

        # Now check that everything is being applied right
        for s in sites(dvis)
            x.lg .= 0
            x.gp .= 0

            inds1 = findall(x->(x[1]==s), dvis[:baseline].sites)
            inds2 = findall(x->(x[2]==s), dvis[:baseline].sites)
            ninds = findall(x->(x[1]!=s && x[2]!=s), dvis[:baseline].sites)

            # Now amps
            x.lg .= 0
            xlgs = x.lg[S=s]
            xlgs .= log(2)
            vout = Stoked.apply_instrument(vis, ointm, (;instrument=x))
            @test vout[inds1] ≈ 2 .*vis[inds1]
            @test vout[inds2] ≈ 2 .*vis[inds2]
            @test vout[ninds] ≈ vis[ninds]

            # Now Phases
            x.lg .= 0
            xgps = x.gp[S=s]
            xgps .= π/4
            vout = Stoked.apply_instrument(vis, ointm, (;instrument=x))
            @test vout[inds1] ≈ vis[inds1] .* exp(1im*π/4)
            @test vout[inds2] ≈ vis[inds2] .* exp(-1im*π/4)
            @test vout[ninds] ≈ vis[ninds]

            # Now Phases and amps
            x.lg .= 0
            x.gp .= 0
            xlgs = x.lg[S=s]
            xlgs .= log(2)
            xgps = x.gp[S=s]
            xgps .= π/4
            vout = Stoked.apply_instrument(vis, ointm, (;instrument=x))
            @test vout[inds1] ≈ vis[inds1] .* exp(log(2) + 1im*π/4)
            @test vout[inds2] ≈ vis[inds2] .* exp(log(2) -1im*π/4)
            @test vout[ninds] ≈ vis[ninds]
        end

    end


    @testset "Coherencies" begin
        vis = CoherencyMatrix.(Stoked.measurement(dcoh), Ref(CirBasis()))
        G = JonesG() do x
            gR = exp(x.lgR + 1im*x.gpR)
            gL = gR*exp(x.lgrat + 1im*x.gprat)
            return gR, gL
        end

        D = JonesD() do x
            dR = complex(x.dRx, x.dRy)
            dL = complex(x.dLx, x.dLy)
            return dR, dL
        end

        R = JonesR(;add_fr=true)

        J = JonesSandwich(*, G, D, R)
        J2 = JonesSandwich(G, D, R) do g, d, r
            return g*d*r
        end


        F = JonesF()

        JG = GenericJones(x->(x.lg, x.lg, x.lg, x.lg))


        intprior = (
        lgR  = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1))),
        gpR  = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, inv(π  ^2))); phase=true, refant=SEFDReference(0.0)),
        lgrat= ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1)), phase=false),
        gprat= ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1)), refant=SingleReference(:AA, 0.0)),
        dRx  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
        dRy  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
        dLx  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
        dLy  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
        )


        intm = InstrumentModel(J, intprior)
        intm2 = InstrumentModel(J2, intprior)
        intjg = InstrumentModel(JG, (;lg = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1)))))
        show(IOBuffer(), MIME"text/plain"(), intm)



        ointm, printm = Stoked.set_array(intm, arrayconfig(dcoh))
        ointm2, printm2 = Stoked.set_array(intm2, arrayconfig(dcoh))
        ointjg, printjg = Stoked.set_array(intjg, arrayconfig(dcoh))

        x = rand(printjg)
        fj = forward_jones(JG, x)
        @test fj[1][1] == x.lg[1]


        Fpre = Stoked.preallocate_jones(F, arrayconfig(dcoh), CirBasis())
        Rpre = Stoked.preallocate_jones(JonesR(;add_fr=true), arrayconfig(dcoh), CirBasis())
        @test Fpre.matrices[1] ≈ Rpre.matrices[1]
        @test Fpre.matrices[2] ≈ Rpre.matrices[2]

        @testset "ObservedArrayPrior" begin
            @inferred logpdf(printm, rand(printm))
            @inferred logpdf(printm2, rand(printm2))
            x = rand(printm)
            @test logpdf(printm, x) ≈ logpdf(printm2, x)
            @test asflat(printm) isa TV.AbstractTransform
            p = rand(printm)
            t = asflat(printm)
            pout =  TV.transform(t, TV.inverse(t, p))
            dp = ntequal(p, pout)
            @test dp.lgR
            @test dp.lgrat
            @test dp.gprat
            @test dp.dRx
            @test dp.dRy
            @test dp.dLx
            @test dp.dLy
        end

        pintm, _ = Stoked.set_array(InstrumentModel(JonesR(;add_fr=true)), arrayconfig(dcoh))


        x = rand(printm)
        x.lgR .= 0
        x.lgrat .= 0
        x.gpR .= 0
        x.gprat .= 0
        x.dRx .= 0
        x.dRy .= 0
        x.dLx .= 0
        x.dLy .= 0

        vout = Stoked.apply_instrument(vis, ointm, (;instrument=x))
        vper = Stoked.apply_instrument(vis, pintm, (;instrument=NamedTuple()))
        @test vout ≈ vper

        # test_rrule(Stoked.apply_instrument, vis, ointm⊢NoTangent(), (;instrument=x))

        # # Now check that everything is being applied right
        for s in sites(dcoh)
            x.lgR .= 0
            x.lgrat .= 0
            x.gpR .= 0
            x.gprat .= 0
            x.dRx .= 0
            x.dRy .= 0
            x.dLx .= 0
            x.dLy .= 0


            inds1 = findall(x->(x[1]==s), dcoh[:baseline].sites)
            inds2 = findall(x->(x[2]==s), dcoh[:baseline].sites)
            ninds = findall(x->(x[1]!=s && x[2]!=s), dcoh[:baseline].sites)

            # Now amp-offsets
            x.lgR .= 0
            x.lgrat .= 0
            x.gpR .= 0
            x.gprat .= 0
            x.dRx .= 0
            x.dRy .= 0
            x.dLx .= 0
            x.dLy .= 0

            xlgRs = x.lgR[S=s]
            xlgRs .= log(2)
            xlgrat = x.lgrat[S=s]
            xlgrat .= -log(2)
            vout = Stoked.apply_instrument(vis, ointm, (;instrument=x))
            G = SMatrix{2,2}(2.0, 0.0, 0.0, 1.0)
            @test vout[inds1] ≈ Ref(G) .*vper[inds1]
            @test vout[inds2] ≈ vper[inds2] .* Ref(G)
            @test vout[ninds] ≈ vper[ninds]

            # Now phases
            x.lgR .= 0
            x.lgrat .= 0
            x.gpR .= 0
            x.gprat .= 0
            x.dRx .= 0
            x.dRy .= 0
            x.dLx .= 0
            x.dLy .= 0

            xgpRs = x.gpR[S=s]
            xgpRs .= π/3
            xgprat = x.gprat[S=s]
            xgprat .= -π/3
            vout = Stoked.apply_instrument(vis, ointm, (;instrument=x))
            G = SMatrix{2,2}(exp(1im*π/3), 0.0, 0.0, exp(1im*0.0))
            @test vout[inds1] ≈ Ref(G) .*vper[inds1]
            @test vout[inds2] ≈ vper[inds2] .* Ref(adjoint(G))
            @test vout[ninds] ≈ vper[ninds]


            # Now dterms
            x.lgR .= 0
            x.lgrat .= 0
            x.gpR .= 0
            x.gprat .= 0
            x.dRx .= 0
            x.dRy .= 0
            x.dLx .= 0
            x.dLy .= 0

            xdRxs = x.dRx[S=s]
            xdRxs .= 0.1
            xdRys = x.dRy[S=s]
            xdRys .= 0.2
            xdLxs = x.dLx[S=s]
            xdLxs .= 0.3
            xdLys = x.dLy[S=s]
            xdLys .= 0.4

            vout = Stoked.apply_instrument(vis, ointm, (;instrument=x))
            D = SMatrix{2,2}(1.0, 0.3 + 0.4im, 0.1 + 0.2im, 1.0)
            @test vout[inds1] ≈ Ref(D) .*vper[inds1]
            @test vout[inds2] ≈ vper[inds2] .* Ref(adjoint(D))
            @test vout[ninds] ≈ vper[ninds]
        end

        @testset "caltable test" begin
            c1 = caltable(x.lgR)
            test_caltable(c1, sort(sites(amp)))
        end

    end


    @testset "Coherencies Multifrequency" begin
        dcoh2 = deepcopy(dcoh)
        dcoh2.config[:Fr] .= 345e9
        dcohmf = build_mfvis(dcoh, dcoh2)
        vissi = CoherencyMatrix.(Stoked.measurement(dcoh), Ref(CirBasis()))
        vismf = CoherencyMatrix.(Stoked.measurement(dcohmf), Ref(CirBasis()))
        G = JonesG() do x
            gR = exp(x.lgR + 1im*x.gpR)
            gL = gR*exp(x.lgrat + 1im*x.gprat)
            return gR, gL
        end

        D = JonesD() do x
            dR = complex(x.dRx, x.dRy)
            dL = complex(x.dLx, x.dLy)
            return dR, dL
        end

        R = JonesR(;add_fr=true)

        J = JonesSandwich(*, G, D, R)
        F = JonesF()

        intprior = (
            lgR  = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1))),
            gpR  = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, inv(π  ^2))); phase=true, refant=SEFDReference(0.0)),
            lgrat= ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1)), phase=false),
            gprat= ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1))),
            dRx  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
            dRy  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
            dLx  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
            dLy  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
        )


        intm = InstrumentModel(J, intprior)
        show(IOBuffer(), MIME"text/plain"(), intm)

        ointsi, printsi = Stoked.set_array(intm, arrayconfig(dcoh))
        ointmf, printmf = Stoked.set_array(intm, arrayconfig(dcohmf))

        @testset "Site lookup" begin
            trsi = asflat(printsi)
            trmf = asflat(printmf)

            lsi = trsi.transformations.lgR.site_map.lookup
            lmf = trmf.transformations.lgR.site_map.lookup
            l = length(trsi.transformations.lgR.site_map.frequencies)
            for s in keys(lsi)
                s1 = Symbol(string(s, 1))
                s2 = Symbol(string(s, 2))
                @test lsi[s] == lmf[s1]# make sure these match
                @test lsi[s] == lmf[s2] .- l # should be a mirror but offset by the total length
            end

            # Check that both have complete coverage
            @test reduce(vcat, lsi) |> sort == 1:l 
            @test reduce(vcat, lmf) |> sort == 1:2l

        end


        Rsi = Stoked.preallocate_jones(F, arrayconfig(dcoh), CirBasis())
        Rmf = Stoked.preallocate_jones(R, arrayconfig(dcohmf), CirBasis())
        # Check that the copied matrices are identical
        @test Rsi.matrices[1] ≈ Rmf.matrices[1][1:length(Rsi.matrices[1])]
        @test Rsi.matrices[1] ≈ Rmf.matrices[1][length(Rsi.matrices[1])+1:end]
        @test Rsi.matrices[2] ≈ Rmf.matrices[2][1:length(Rsi.matrices[1])]
        @test Rsi.matrices[2] ≈ Rmf.matrices[2][length(Rsi.matrices[1])+1:end]

        for p in propertynames(ointsi.bsitelookup)
            L = length(ointsi.bsitelookup[p].indices_1)
            @test ointsi.bsitelookup[p].indices_1 == ointmf.bsitelookup[p].indices_1[1:L]
            @test ointsi.bsitelookup[p].indices_2 == ointmf.bsitelookup[p].indices_2[1:L]
            @test 2*L == length(ointmf.bsitelookup[p].indices_1)
        end

        pintmf, _ = Stoked.set_array(InstrumentModel(R), arrayconfig(dcohmf))

        xsi = rand(printsi)
        xmf = rand(printmf)

        for s in sites(dcoh)
            map(x->fill!(x, 0.0), xsi)
            map(x->fill!(x, 0.0), xmf)

            inds1si = findall(x->(x[1]==s), dcoh[:baseline].sites)
            inds2si = findall(x->(x[2]==s), dcoh[:baseline].sites)
            nindssi = findall(x->(x[1]!=s && x[2]!=s), dcoh[:baseline].sites)

            inds1mf = findall(x->(x[1]==s), dcohmf[:baseline].sites)
            inds2mf = findall(x->(x[2]==s), dcohmf[:baseline].sites)
            nindsmf = findall(x->(x[1]!=s && x[2]!=s), dcohmf[:baseline].sites)

            xsilgR = xsi.lgR[S=s]
            xsilgR .= log(2)
            xmflgR = xmf.lgR[S=s]
            xmflgR[1:length(xsilgR)] .= xsilgR
            xmflgR[length(xsilgR)+1:end] .= 2 .* xsilgR

            xsilgrat = xsi.lgrat[S=s]
            xsilgrat .= -log(2)
            xmflgrat = xmf.lgrat[S=s]
            xmflgrat[1:length(xsilgrat)] .= xsilgrat
            xmflgrat[length(xsilgrat)+1:end] .= xsilgrat
            vmf = Stoked.apply_instrument(vismf, ointmf, (;instrument=xmf))
            vsi = Stoked.apply_instrument(vissi, ointsi, (;instrument=xsi))
            Gmf = SMatrix{2,2}(2.0, 0.0, 0.0, 2.0)
            @test vsi[inds1si] ≈ vmf[inds1si]
            @test vsi[inds1si] .* Ref(Gmf) ≈ vmf[inds1mf[length(inds1si)+1:end]] 

            # Now phases
            map(x->fill!(x, 0.0), xsi)
            map(x->fill!(x, 0.0), xmf)

            xsigpR = xsi.gpR[S=s]
            xsigpR .= π/3
            xmfgpR = xmf.gpR[S=s]
            xmfgpR[1:length(xsigpR)] .= xsigpR
            xmfgpR[length(xsilgR)+1:end] .= 2 .* xsigpR

            xsigprat = xsi.gprat[S=s]
            xsigprat .= -π/6
            xmfgprat = xmf.gprat[S=s]
            xmfgprat[1:length(xsigprat)] .= xsigprat
            xmfgprat[length(xsigprat)+1:end] .= xsigprat

            vmf = Stoked.apply_instrument(vismf, ointmf, (;instrument=xmf))
            vsi = Stoked.apply_instrument(vissi, ointsi, (;instrument=xsi))
            Gmf = SMatrix{2,2}(exp(1im*π/3), 0.0, 0.0, exp(1im*π/3))
            @test vsi[inds1si] ≈ vmf[inds1si]
            @test vsi[inds1si] .* Ref(Gmf) ≈ vmf[inds1mf[length(inds1si)+1:end]] 


        end
        

        @testset "caltable test" begin
            xmf = rand(printmf)
            c1 = caltable(xmf.lgR)
            test_caltable(c1, sort(sites(amp)))
        end

    end

    @testset "Integration" begin
        _,dvis, amp, lcamp, cphase, dcoh = load_data()
        ts = Stoked.timestamps(ScanSeg(),  arrayconfig(dvis))
        tt = Stoked.timestamps(TrackSeg(), arrayconfig(dvis))
        ti = Stoked.timestamps(IntegSeg(), arrayconfig(dvis))
        @test length(tt) < length(ts) ≤ length(ti)
    end

    @testset "IntegrationTime" begin
        ti = Stoked.IntegrationTime(10, 5.0, 0.1)
        @test Stoked.mjd(ti) == ti.mjd
        @test ti.t0 ∈ Stoked.interval(ti)
        @test Stoked._center(ti) == ti.t0
        @test Stoked._region(ti) == 0.1
    end

    @testset "FrequencyChannel" begin
        fc = Stoked.FrequencyChannel(230e9, 8e9, 1)
        @test Stoked.channel(fc) == 1
        @test fc.central ∈ Stoked.interval(fc)
        @test Stoked._center(fc) == fc.central
        @test Stoked._region(fc) == 8e9
        @test 86e9 < fc
        @test fc < 345e9
    end



end
