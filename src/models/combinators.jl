export add, convolved, smoothed, components

"""
    $(TYPEDEF)
Abstract type that denotes a composite model. Where we have
combined two models together.

# Implementation
Any implementation of a composite type must define the following methods:

- visibility_point
- uv_combinator
- imanalytic
- visanalytic
- ComradeBase.intensity_point if model intensity is `IsAnalytic`
- intensitymap! if model intensity is `NotAnalytic`
- intensitymap if model intensity is `NotAnalytic`
- flux
- radialextent
- visibilitymap_analytic (optional)
- visibilitymap_numeric (optional)
"""
abstract type CompositeModel{M1,M2} <: AbstractModel end


function modelimage(::NotAnalytic,
    model::CompositeModel,
    image::IntensityMap,
    alg::FourierTransform=FFTAlg(),
    pulse = DeltaPulse(),
    thread::StaticBool = False())

    m1 = @set model.m1 = modelimage(model.m1, image, alg, pulse, thread)
    @set m1.m2 = modelimage(m1.m2, copy(image), alg, pulse, thread)
end

function modelimage(::NotAnalytic,
    model::CompositeModel,
    cache::AbstractCache,
    thread::StaticBool = False())

    m1 = @set model.m1 = modelimage(model.m1, cache)
    @set m1.m2 = modelimage(m1.m2, cache)
end

function visibilitymap(m::CompositeModel, dims::AbstractDims)
    m1 = visibilitymap(m.m1, dims)
    m2 = visibilitymap(m.m2, dims)
    return uv_combinator(m).(m1,m2)
end



radialextent(m::CompositeModel) = max(radialextent(m.m1), radialextent(m.m2))

@inline visanalytic(::Type{<:CompositeModel{M1,M2}}) where {M1,M2} = visanalytic(M1)*visanalytic(M2)
@inline imanalytic(::Type{<:CompositeModel{M1,M2}}) where {M1,M2} = imanalytic(M1)*imanalytic(M2)


"""
    $(TYPEDEF)

Pointwise addition of two models in the image and visibility domain.
An end user should instead call [`added`](@ref added) or `Base.+` when
constructing a model

# Example

```julia-repl
julia> m1 = Disk() + Gaussian()
julia> m2 = added(Disk(), Gaussian()) + Ring()
```
"""
struct AddModel{T1,T2} <: CompositeModel{T1,T2}
    m1::T1
    m2::T2
end

"""
    added(m1::AbstractModel, m2::AbstractModel)

Combine two models to create a composite [`AddModel`](@ref Comrade.AddModel).
This adds two models pointwise, i.e.
```julia-repl
julia> m1 = Gaussian()
julia> m2 = Disk()
julia> visibility(added(m1,m2), 1.0, 1.0) == visibility(m1, 1.0, 1.0) + visibility(m2, 1.0, 1.0)
true
```
"""
@inline added(m1::AbstractModel, m2::AbstractModel) = AddModel(m1, m2)


"""
    Base.:+(m1::AbstractModel, m2::AbstractModel)

Combine two models to create a composite [`AddModel`](@ref Comrade.AddModel).
This adds two models pointwise, i.e.

```julia-repl
julia> m1 = Gaussian()
julia> m2 = Disk()
julia> visibility(m1+m2, 1.0, 1.0) == visibility(m1, 1.0, 1.0) + visibility(m2, 1.0, 1.0)
true
```

"""
Base.:+(m1::AbstractModel, m2::AbstractModel) = added(m1, m2)
Base.:-(m1::AbstractModel, m2::AbstractModel) = added(m1, -1.0*m2)



# struct NModel{V<:AbstractVector, M<:AbstractModel}
#     m::V{M}
# end

# function visibilities(m::NModel, u, v)
#     f(x) = visibilities(x, u, v)
#     return sum(f, m.m)
# end

# function intensitymap(m::NModel, fov, dims)

# end


"""
    components(m::AbstractModel)

Returns the model components for a composite model. This
will return a Tuple with all the models you have constructed.

# Example

```julia-repl
julia> m = Gaussian() + Disk()
julia> components(m)
(Gaussian{Float64}(), Disk{Float64}())
```
"""
components(m::AbstractModel) = (m,)
components(m::CompositeModel{M1,M2}) where
    {M1<:AbstractModel, M2<:AbstractModel} = (components(m.m1)..., components(m.m2)...)

flux(m::AddModel) = flux(m.m1) + flux(m.m2)


function intensitymap(m::AddModel, dims::AbstractDims)
    sim1 = intensitymap(m.m1, dims)
    sim2 = intensitymap(m.m2, dims)
    return sim1 + sim2
end

function intensitymap(::NotAnalytic, m::AddModel, dims::AbstractDims)
    sim1 = intensitymap(m.m1, dims)
    sim2 = intensitymap(m.m2, dims)
    return sim1 + sim2
end


function intensitymap!(sim::IntensityMap, m::AddModel)
    csim = deepcopy(sim)
    intensitymap!(csim, m.m1)
    sim .= csim
    intensitymap!(csim, m.m2)
    sim .= sim .+ csim
    return sim
end

@inline uv_combinator(::AddModel) = Base.:+
@inline xy_combinator(::AddModel) = Base.:+

# @inline function _visibilities(model::CompositeModel{M1,M2}, u, v, t, ν, cache) where {M1,M2}
#     _combinatorvis(visanalytic(M1), visanalytic(M2), uv_combinator(model), model, u, v, t, ν, cache)
# end

# @inline function _visibilities(model::M, u::AbstractArray, v::AbstractArray, args...) where {M <: CompositeModel}
#     return _visibilities(visanalytic(M), model, u, v, args...)
# end


@inline function visibilitymap_numeric(model::AddModel, p)
    return visibilitymap_numeric(model.m1, p) .+ visibilitymap_numeric(model.m2, p)
end



#function ChainRulesCore.rrule(config::RuleConfig{>:HasReverseMode}, ::typeof(_visibilities), model::AddModel, u::AbstractArray, v::AbstractArray, args...)
#    v1_and_vdot = rrule_via_ad(config, _visibilities, model.m1, u, v, args...)
#    v2_and_vdot = rrule_via_ad(config, _visibilities, model.m2, u, v, args...)
#
#    vdot1 = last(v1_and_vdot)
#    vdot2 = last(v2_and_vdot)
#    project_model = ProjectTo(model)
#    function _addmodel_visibilities_pullback(Δy)
#        vd1 = vdot1(Δy)
#        vd2 = vdot2(Δy)
#        println(project_model(vd1[2],vd2[2]))
#        return (NoTangent(), project_model())
#    end
#    return first(v1_and_vdot) + first(v2_and_vdot), _addmodel_visibilities_pullback
#end

# function _visibilities(model::AddModel, u::AbstractArray, v::AbstractArray, args...)
#     return visibilities(model.m1, u, v) + visibilities(model.m2, u, v)
# end


@inline function visibility_point(model::CompositeModel{M1,M2}, u, v, time, freq) where {M1,M2}
    f = uv_combinator(model)
    v1 = visibility_point(model.m1, u, v, time, freq)
    v2 = visibility_point(model.m2, u, v, time, freq)
    return f(v1,v2)
end

@inline function intensity_point(model::CompositeModel, p)
    f = xy_combinator(model)
    v1 = intensity_point(model.m1, p)
    v2 = intensity_point(model.m2, p)
    return f(v1,v2)
end



"""
    $(TYPEDEF)

Pointwise addition of two models in the image and visibility domain.
An end user should instead call [`convolved`](@ref convolved).
Also see [`smoothed(m, σ)`](@ref smoothed) for a simplified function that convolves
a model `m` with a Gaussian with standard deviation `σ`.
"""
struct ConvolvedModel{M1, M2} <: CompositeModel{M1,M2}
    m1::M1
    m2::M2
end

"""
    convolved(m1::AbstractModel, m2::AbstractModel)

Convolve two models to create a composite [`ConvolvedModel`](@ref Comrade.ConvolvedModel).

```julia-repl
julia> m1 = Ring()
julia> m2 = Disk()
julia> convolved(m1, m2)
```
"""
convolved(m1::AbstractModel, m2::AbstractModel) = ConvolvedModel(m1, m2)

"""
    smoothed(m::AbstractModel, σ::Number)
Smooths a model `m` with a Gaussian kernel with standard deviation `σ`.

# Notes
This uses [`convolved`](@ref) to created the model, i.e.
```julia-repl
julia> m1 = Disk()
julia> m2 = Gaussian()
julia> convolved(m1, m2) == smoothed(m1, 1.0)
true
```
"""
smoothed(m, σ::Number) = convolved(m, stretched(Gaussian(), σ, σ))

@inline imanalytic(::Type{<:ConvolvedModel}) = NotAnalytic()


@inline uv_combinator(::ConvolvedModel) = Base.:*

flux(m::ConvolvedModel) = flux(m.m1)*flux(m.m2)

function intensitymap_numeric(model::ConvolvedModel, dims::AbstractDims)
    mat = similar(dims.X, size(dims))
    img = IntensityMap(mat, dims)
    return intensitymap_numeric!(img, model)
end

function intensitymap_numeric!(sim::IntensityMap, model::ConvolvedModel)
    dims = axiskeys(sim)
    (;X, Y) = dims
    vis1 = visibilitymap(model.m1, dims)
    vis2 = visibilitymap(model.m2, dims)
    U = vis1.U
    V = vis1.V
    vis = ifftshift(phasedecenter!(keyless_unname(vis1.*vis2), X, Y, U, V))
    ifft!(vis)
    sim .= real.(vis)
end


@inline function visibilitymap_numeric(model::ConvolvedModel, p)
    return visibilitymap_numeric(model.m1, p).*visibilitymap_numeric(model.m2, p)
end
