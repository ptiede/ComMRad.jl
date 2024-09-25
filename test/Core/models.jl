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


@testset "SkyModel" begin

    f = test_model
    g = imagepixels(μas2rad(150.0), μas2rad(150.0), 256, 256)
    skym = SkyModel(f, test_prior(), g)
    show(IOBuffer(), MIME"text/plain"(), skym)

    x = rand(Comrade.NamedDist(test_prior()))
    m = Comrade.skymodel(skym, x)
    skyf = FixedSkyModel(m, g)

    @testset "ObservedSkyModel" begin
        _,vis, amp, lcamp, cphase = load_data()

        oskym, = Comrade.set_array(skym, arrayconfig(vis))
        oskyf, = Comrade.set_array(skyf, arrayconfig(vis))

        @test Comrade.skymodel(oskym, x) == m
        @test Comrade.idealvisibilities(oskym, (;sky=x)) ≈ Comrade.idealvisibilities(oskyf, (;sky=x))
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
        ointm, printm = Comrade.set_array(intm, arrayconfig(dvis))
        show(IOBuffer(), MIME"text/plain"(), ointm)
        x = rand(printm)
        sl = Comrade.SiteLookup(x.lg)

        @test sl isa Comrade.SiteLookup
        s2 =  SiteArray(parent(x.lg), sl)
        @test s2 == x.lg
        @test Comrade.times(s2) == Comrade.times(x.lg)
        @test Comrade.frequencies(s2) == Comrade.frequencies(x.lg)
        @test Comrade.sites(s2) == Comrade.sites(x.lg)

        @test Comrade.sitemap(exp, parent(x.lg), sl) ≈ exp.(x.lg)
        Comrade.sitemap(cumsum, parent(x.lg), sl)

        @test x.lg[1] == parent(x.lg)[1]
        x.lg[1] = 1.0
        @test x.lg[1] == 1.0

        sarr = x.lg[1:16]
        @test_throws DimensionMismatch similar(sarr, Float64, (4,4)) isa Comrade.SiteArray

        @test Comrade.SiteArray(x.lg, sl) == x.lg

        Comrade.time(x.lg, 5.0..6.0)
        Comrade.frequency(x.lg, 1.0..400.0)

        # ps = ProjectTo(x.lg)
        # @test ps(x.lg) == x.lg
        # @test ps(NoTangent()) isa NoTangent
        # @test ps(Tangent{typeof(x.lg)}(data = parent(x.lg))) == x.lg

    end

    @testset "StokesI" begin
        vis = Comrade.measurement(dvis)

        G = SingleStokesGain(x->exp(x.lg + 1im*x.gp))
        intprior = (lg = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1))),
                    gp = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, inv(π^2))); refant=SEFDReference(0.0))
                    )

        intm = InstrumentModel(G, intprior)
        show(IOBuffer(), MIME"text/plain"(), intm)

        ointm, printm = Comrade.set_array(intm, arrayconfig(dvis))
        x = rand(printm)
        x.lg .= 0
        x.gp .= 0
        vout = Comrade.apply_instrument(vis, ointm, (;instrument=x))
        # test_rrule(Comrade.apply_instrument, vis, ointm⊢NoTangent(), (;instrument=x))
        @test vout ≈ vis


        ointid, pr = Comrade.set_array(Comrade.IdealInstrumentModel(), arrayconfig(dvis))
        vout = Comrade.apply_instrument(vis, ointid, (;))
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
            vout = Comrade.apply_instrument(vis, ointm, (;instrument=x))
            @test vout[inds1] ≈ 2 .*vis[inds1]
            @test vout[inds2] ≈ 2 .*vis[inds2]
            @test vout[ninds] ≈ vis[ninds]

            # Now Phases
            x.lg .= 0
            xgps = x.gp[S=s]
            xgps .= π/4
            vout = Comrade.apply_instrument(vis, ointm, (;instrument=x))
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
            vout = Comrade.apply_instrument(vis, ointm, (;instrument=x))
            @test vout[inds1] ≈ vis[inds1] .* exp(log(2) + 1im*π/4)
            @test vout[inds2] ≈ vis[inds2] .* exp(log(2) -1im*π/4)
            @test vout[ninds] ≈ vis[ninds]
        end

    end


    @testset "Coherencies" begin
        vis = CoherencyMatrix.(Comrade.measurement(dcoh), Ref(CirBasis()))
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
        gprat= ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1))),
        dRx  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
        dRy  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
        dLx  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
        dLy  = ArrayPrior(IIDSitePrior(TrackSeg(), Normal(0.0, 0.2))),
        )


        intm = InstrumentModel(J, intprior)
        intm2 = InstrumentModel(J2, intprior)
        intjg = InstrumentModel(JG, (;lg = ArrayPrior(IIDSitePrior(ScanSeg(), Normal(0.0, 0.1)))))
        show(IOBuffer(), MIME"text/plain"(), intm)



        ointm, printm = Comrade.set_array(intm, arrayconfig(dcoh))
        ointm2, printm2 = Comrade.set_array(intm2, arrayconfig(dcoh))
        ointjg, printjg = Comrade.set_array(intjg, arrayconfig(dcoh))

        x = rand(printjg)
        fj = forward_jones(JG, x)
        @test fj[1][1] == x.lg[1]


        Fpre = Comrade.preallocate_jones(F, arrayconfig(dcoh), CirBasis())
        Rpre = Comrade.preallocate_jones(JonesR(;add_fr=true), arrayconfig(dcoh), CirBasis())
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

        pintm, _ = Comrade.set_array(InstrumentModel(JonesR(;add_fr=true)), arrayconfig(dcoh))


        x = rand(printm)
        x.lgR .= 0
        x.lgrat .= 0
        x.gpR .= 0
        x.gprat .= 0
        x.dRx .= 0
        x.dRy .= 0
        x.dLx .= 0
        x.dLy .= 0

        vout = Comrade.apply_instrument(vis, ointm, (;instrument=x))
        vper = Comrade.apply_instrument(vis, pintm, (;instrument=NamedTuple()))
        @test vout ≈ vper

        # test_rrule(Comrade.apply_instrument, vis, ointm⊢NoTangent(), (;instrument=x))

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
            vout = Comrade.apply_instrument(vis, ointm, (;instrument=x))
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
            vout = Comrade.apply_instrument(vis, ointm, (;instrument=x))
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

            vout = Comrade.apply_instrument(vis, ointm, (;instrument=x))
            D = SMatrix{2,2}(1.0, 0.3 + 0.4im, 0.1 + 0.2im, 1.0)
            @test vout[inds1] ≈ Ref(D) .*vper[inds1]
            @test vout[inds2] ≈ vper[inds2] .* Ref(adjoint(D))
            @test vout[ninds] ≈ vper[ninds]
        end

        @testset "caltable test" begin
            c1 = caltable(x.lgR)
            @test Tables.istable(typeof(c1))
            @test Tables.rowaccess(typeof(c1))
            @test Tables.rows(c1) === c1
            @test Tables.columnaccess(c1)
            clmns = Tables.columns(c1)
            @test clmns[1] == Comrade.scantimes(c1)
            @test Bool(prod(skipmissing(Tables.matrix(clmns)[:,begin+1:end]) .== skipmissing(Comrade.gmat(c1))))
            @test c1.time == Comrade.scantimes(c1)
            @test c1.time == Tables.getcolumn(c1, 1)
            @test maximum(abs, skipmissing(c1.AA) .- skipmissing(Tables.getcolumn(c1, :AA))) ≈ 0
            @test maximum(abs, skipmissing(c1.AA) .- skipmissing(Tables.getcolumn(c1, 2))) ≈ 0
            @test Tables.columnnames(c1) == [:time, sort(sites(amp))...]

            c1row = Tables.getrow(c1, 30)
            @test eltype(c1) == typeof(c1row)
            @test c1row.time == c1.time[30]
            @test c1row.AA == c1.AA[30]
            @test Tables.getcolumn(c1row, :AA) == c1.AA[30]
            @test Tables.getcolumn(c1row, :time) == c1.time[30]
            @test Tables.getcolumn(c1row, 2) == c1.AA[30]
            @test Tables.getcolumn(c1row, 1) == c1.time[30]
            @test propertynames(c1) == propertynames(c1row) == [:time, sort(sites(amp))...]

            Tables.schema(c1) isa Tables.Schema
            Tables.getcolumn(c1, Float64, 1, :test)
            Tables.getcolumn(c1, Float64, 2, :test)

            c1[1, :AA]
            c1[!, :AA]
            c1[:, :AA]
            @test length(c1) == length(c1.AA)
            @test c1[1 ,:] isa Comrade.CalTableRow
            @test length(Tables.getrow(c1, 1:5)) == 5

            plot(c1)
            plot(c1, datagains=true)
            plot(c1, sites=(:AA,))

            show(c1)
        end

    end

    @testset "Integration" begin
        _,dvis, amp, lcamp, cphase, dcoh = load_data()
        ts = Comrade.timestamps(ScanSeg(),  arrayconfig(dvis))
        tt = Comrade.timestamps(TrackSeg(), arrayconfig(dvis))
        ti = Comrade.timestamps(IntegSeg(), arrayconfig(dvis))
        @test length(tt) < length(ts) ≤ length(ti)
    end


end
