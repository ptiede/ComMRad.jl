export stretched, shifted, rotated, renormed


"""
    $(TYPEDEF)

Abstract type for image modifiers. These are some model wrappers
that can transform any model using simple Fourier transform properties.
By default these modified models will have the same analytic properties
as the base unmodified model, i.e.

```julia-repl
julia> visanalytic(stretched(Disk(), 2.0, 2.0)) == visanalytic(Disk())
true
```

Additionally these are classic examples of non-primitive images i.e.,
```julia-repl
julia> isprimitive(Comrade.AbstractModifier) == Comrade.NotAnalytic()
```

As a result of this the implementation of a model is slightly different

- [`transform_uv`](@ref)
- [`transform_image`](@ref)
- [`scale_uv`](@ref)
- [`scale_image`](@ref)
- [`radialextent`](@ref)

This methods assume the modifiers are of the form

I(x,y) -> fᵢ(x,y)I(gᵢ(x,y))
V(u,v) -> fᵥ(u,v)V(gᵥ(u,v))

where `g` are the transform_image/uv functions and `f` are the scale_image/uv
function.

See those docstrings for guidance on implementation details.
"""
abstract type AbstractModifier{M<:AbstractModel} <: AbstractModel end

"""
    basemodel(model::AbstractModel)

Returns the base model from a modified `model`. If there is no basemodel
this just return the `model` itself.

# Example
```julia-repl
julia> basemodel(stretched(Disk(), 1.0, 2.0)) == Disk()
true
```
"""
basemodel(model::AbstractModifier) = model.model
basemodel(model::AbstractModel) = model

"""
    unmodified(model::AbstractModel)

Returns the un-modified model

### Example
```julia-repl
julia> m = stretched(rotated(Gaussian(), π/4), 2.0, 1.0)
julia> umodified(m) == Gaussian()
true
```
"""
unmodified(model::AbstractModel) = basemodel(model)
unmodified(model::AbstractModifier) = unmodified(basemodel(model))


flux(m::AbstractModifier) = flux(m.model)

Base.@constprop :aggressive @inline visanalytic(::Type{<:AbstractModifier{M}}) where {M} = visanalytic(M)
Base.@constprop :aggressive @inline imanalytic(::Type{<:AbstractModifier{M}}) where {M} = imanalytic(M)
Base.@constprop :aggressive @inline ispolarized(::Type{<:AbstractModifier{M}}) where {M} = ispolarized(M)

radialextent(m::AbstractModifier) = radialextent(basemodel(m))

"""
    scale_image(model::AbstractModifier, x, y)

Returns a number of how to to scale the image intensity at `x` `y` for an modified `model`
"""
function scale_image end


"""
    transform_image(model::AbstractModifier, x, y)

Returns a transformed `x` and `y` according to the `model` modifier
"""
function transform_image end

"""
    scale_image(model::AbstractModifier, u, u)

Returns a number on how to scale the image visibility at `u` `v` for an modified `model`
"""
function scale_uv end

"""
    transform_uv(model::AbstractModifier, u, u)

Returns a transformed `u` and `v` according to the `model` modifier
"""
function transform_uv end

struct TransformState{T<:Number,C}
    u::T
    v::T
    scale::C
end

unitscale(T, ::Type{M}) where {M} = unitscale(T, ispolarized(M))
unitscale(T, ::NotPolarized) = one(T)
unitscale(T, ::IsPolarized) = I



# @inline function apply_uv_transform(m::AbstractModifier, t::TransformState)
#     ut, vt = transform_uv(m, t.u, t.v)
#     scale = t.scale*scale_uv(m, t.u, t.v)
#     return apply_uv_transform(basemodel(m), TransformState(ut, vt, scale))
# end

# @inline function apply_uv_transform(::AbstractModel, t::TransformState)
#     return t
# end


# @inline function apply_uv_transform(m::AbstractModifier, u, v, scale)
#     ut, vt = transform_uv(m, u, v)
#     scale = scale*scale_uv(m, u, v)
#     return apply_uv_transform(basemodel(m), ut, vt, scale)
# end

# @inline function apply_uv_transform(::AbstractModel, u, v, scale)
#     return (u, v), scale
# end

# @inline function _visibilities(m::AbstractModifier, u, v, time, freq)
#     uv, scale = apply_uv_transform(m, u, v)
#     ut = first.(uv)
#     vt = last.(uv)
#     scale.*_visibilities(unmodified(m), ut, vt, time, freq)
# end


# # function visibilities(m, p::NamedTuple)
# #     m = Base.Fix1(m∘NamedTuple{keys(p)})
# #     return visibilities(m, NamedTuple{keys(p)}(p))
# # end

# function apply_uv_transform(m::AbstractModifier, u::AbstractVector, v::AbstractVector)
#     res = apply_uv_transform.(Ref(m), u, v, 1.0)
#     return first.(res), last.(res)
# end



# function apply_uv_transform(m::AbstractModifier, u::AbstractVector, v::AbstractVector)
#     res = apply_uv_transform.(Ref(m), u, v, 1.0)
#     return getindex.(res,1), getindex.(res,2), getindex.(res,3)
#     res = apply_uv_transform.(Ref(m), u, v, 1.0)
#     return getindex.(res,1), getindex.(res,2), getindex.(res,3)
# end
# @inline function _visibilities(m::M, p) {M<:AbstractModifier}

# @inline function _visibilities(m::M, p) {M<:AbstractModifier}

#     return _visibilities(visanalytic(M), m, u, v, args...)
# end

# @inline function _visibilities(m::AbstractModifier{M}, p) where {M}
#     return _visibilities(ispolarized(M), m, p)
# end



# @inline function _visibilities(m::AbstractModifier, p)
#     (;U, V) = p
#     st = StructArray{TransformState{eltype(U), Complex{eltype(U)}}}(u=U, v=V, scale=fill(one(Complex{eltype(U)}), length(U)))
#     auv = Base.Fix1(apply_uv_transform, m)
#     mst = map(auv, st)
#     mst.scale.*visibilities(unmodified(m), (U=mst.u, V=mst.v))
# end

function update_uv(p::NamedTuple, uv)
    p1 = @set p.U = uv.U
    p2 = @set p1.V = uv.V
    return p2
end

function update_xy(p::NamedTuple, xy)
    p1 = @set p.X = xy.X
    p2 = @set p1.Y = xy.Y
    return p2
end


# @inline function _visibilities(::IsPolarized, m::AbstractModifier, p)
#     (;U, V) = p

#     S = eltype(U)
#     unit = StokesParams(complex(one(S)), complex(one(S)), complex(one(S)),complex(one(S)))
#     st = StructArray{TransformState{eltype(U), typeof(unit)}}(u=U, v=V, scale=Fill(unit, length(U)))
#     mst = apply_uv_transform.(Ref(m), st)

#     pup = update_uv(p, (U=mst.u, V=mst.v))
#     mst.scale.*visibilities(unmodified(m), pup)
# end

# @inline function _visibilities(m::AbstractModifier, p)
#     (;U, V) = p
#     st = StructArray{TransformState{eltype(U), Complex{eltype(U)}}}(u=U, v=V, scale=fill(one(Complex{eltype(U)}), length(U)))
#     mst = apply_uv_transform.(Ref(m), st)
#     pup = update_uv(p, (U=mst.u, V=mst.v))
#     mst.scale.*visibilities(unmodified(m), pup)
# end



# I need some special pass-throughs for the non-analytic FFT transform
# since you evaluate the visibilities pointwise
function modelimage(::NotAnalytic,
    model::AbstractModifier,
    image::IntensityMap, alg::FFTAlg, pulse = DeltaPulse(), thread::StaticBool=False())

    @set model.model = modelimage(NotAnalytic(), model.model, image, alg, pulse, thread)
end

# I need some special pass-throughs for the non-analytic NUFT transform
# since you evaluate the visibilities as a vector
function modelimage(::NotAnalytic,
    model::AbstractModifier,
    image::IntensityMap, alg::NUFT,
    pulse = DeltaPulse(), thread::StaticBool=False())
    _modelimage(model, image, alg, pulse, thread)
end


@inline function visibility_point(m::AbstractModifier, u, v, time, freq)
    ut, vt = transform_uv(m, u, v)
    scale = scale_uv(m, u, v)
    scale*visibility_point(basemodel(m), ut, vt, time, freq)
end

@inline function ComradeBase.intensity_point(m::AbstractModifier, p)
    xt, yt = transform_image(m, p.X, p.Y)
    scale = scale_image(m, p.X, p.Y)
    scale*ComradeBase.intensity_point(basemodel(m), update_xy(p, (X=xt, Y=yt)))
end

"""
    $(TYPEDEF)

Shifts the model by `Δx` units in the x-direction and `Δy` units
in the y-direction.

An end user should not call this directly but instead
the [`shifted`](@ref) function instead.
"""
struct ShiftedModel{M<:AbstractModel,T} <: AbstractModifier{M}
    model::M
    Δx::T
    Δy::T
end

#function ShiftedModel(model::AbstractModel, Δx::Number, Δy::Number)
#    T =
#    return ShiftedModel{(model, promote(Δx, Δy)...)
#end

"""
    $(SIGNATURES)

Shifts the model `m` in the image domain by an amount `Δx,Δy`
in the x and y directions respectively.
"""
shifted(model, Δx, Δy) = ShiftedModel(model, Δx, Δy)
# This is a simple overload to simplify the type system
shifted(model::ShiftedModel, Δx, Δy)      = ShiftedModel(basemodel(model), Δx+model.Δx, Δy+model.Δy)
radialextent(model::ShiftedModel, Δx, Δy) = radialextent(model.model) + hypot(abs(Δx), abs(Δy))

@inline transform_image(model::ShiftedModel, x, y) = (x-model.Δx, y-model.Δy)
@inline transform_uv(::ShiftedModel, u, v) = (u, v)

@inline scale_image(model::ShiftedModel{M}, x, y) where {M} = unitscale(typeof(model.Δx), M)
@inline scale_uv(model::ShiftedModel{M}, u, v) where {M}    = cispi(2*(u*model.Δx + v*model.Δy))*unitscale(typeof(model.Δx), M)

@inline visanalytic(::Type{<:ShiftedModel{M}}) where {M} = visanalytic(M)


"""
    $(TYPEDEF)

Renormalizes the flux of the model to the new value `scale*flux(model)`.
We have also overloaded the Base.:* operator as syntactic sugar
although I may get rid of this.

An end user should not call this directly but instead
the [`renormed`](@ref) function or Base.:* instead.

# Example
```julia-repl
julia> renormed(Gaussian(), 2.0) == 2.0*Gaussian()
true
```
"""
struct RenormalizedModel{M<:AbstractModel,T} <: AbstractModifier{M}
    model::M
    scale::T
    RenormalizedModel(model::M, f::T) where {M,T} = new{M,T}(model, f)
end



"""
    $(SIGNATURES)

Renormalizes the model `m` to have total flux `f*flux(m)`.
This can also be done directly by calling `Base.:*` i.e.,

```julia-repl
julia> renormed(m, f) == f*M
true
```
"""
renormed(model::M, f) where {M<:AbstractModel} = RenormalizedModel(model, f)
Base.:*(model::AbstractModel, f::Number) = renormed(model, f)
Base.:*(f::Number, model::AbstractModel) = renormed(model, f)
Base.:/(f::Number, model::AbstractModel) = renormed(model, inv(f))
Base.:/(model::AbstractModel, f::Number) = renormed(model, inv(f))
# Dispatch on RenormalizedModel so that I just make a new RenormalizedModel with a different f
# This will make it easier on the compiler.
Base.:*(model::RenormalizedModel, f::Number) = renormed(model.model, model.scale*f)
# Overload the unary negation operator to be the same model with negative flux
Base.:-(model::AbstractModel) = renormed(model, -1.0)
flux(m::RenormalizedModel) = m.scale*flux(m.model)

@inline transform_image(::RenormalizedModel, x, y) = (x, y)
@inline transform_uv(::RenormalizedModel, u, v) = (u, v)

@inline scale_image(model::RenormalizedModel{M}, x, y) where {M} = model.scale*unitscale(typeof(model.scale), M)
@inline scale_uv(model::RenormalizedModel{M}, u, v) where {M}    = model.scale*unitscale(typeof(model.scale), M)

#function _visibilities(m::RenormalizedModel, u::AbstractArray, v::AbstractArray)
#    m.scale*_visibilities(basemodel(m), u, v)
#end

@inline visanalytic(::Type{<:RenormalizedModel{M}}) where {M} = visanalytic(M)


"""
    $(TYPEDEF)

Stretched the model in the x and y directions, i.e. the new intensity is
    Iₛ(x,y) = 1/(αβ) I(x/α, y/β),
where were renormalize the intensity to preserve the models flux.

An end user should not call this directly but instead
the [`stretched`](@ref) function instead.
"""
struct StretchedModel{M<:AbstractModel,T} <: AbstractModifier{M}
    model::M
    α::T
    β::T
end

#function Stretched(model::AbstractModel, a::Number, b::Number)
#    return Stretched(model, promote(a, b)...)
#end


"""
    $(SIGNATURES)

Stretches the model `m` according to the formula
    Iₛ(x,y) = 1/(αβ) I(x/α, y/β),
where were renormalize the intensity to preserve the models flux.
"""
stretched(model, α, β) = StretchedModel(model, α, β)
radialextent(model::StretchedModel) = hypot(model.α, model.β)*radialextent(basemodel(model))

@inline transform_image(model::StretchedModel, x, y) = (x/model.α, y/model.β)
@inline transform_uv(model::StretchedModel, u, v) = (u*model.α, v*model.β)

@inline scale_image(model::StretchedModel{M,T}, x, y) where {M,T} = inv(model.α*model.β)*unitscale(T, M)
@inline scale_uv(::StretchedModel{M,T}, u, v) where {M,T} = unitscale(T, M)

@inline visanalytic(::Type{<:StretchedModel{M}}) where {M} = visanalytic(M)


"""
    $(TYPEDEF)

Type for the rotated model. This is more fine grained constrol of
rotated model.

An end user should not call this directly but instead
the [`rotated`](@ref) function instead.
"""
struct RotatedModel{M<:AbstractModel,T} <: AbstractModifier{M}
    model::M
    s::T
    c::T
end
function RotatedModel(model::T, ξ::F) where {T, F}
    s,c = sincos(ξ)
    return RotatedModel(model, s, c)
end

@inline visanalytic(::Type{<:RotatedModel{M}}) where {M} = visanalytic(M)

"""
    $(SIGNATURES)

Rotates the model by an amount `ξ` in radians in the clockwise direction.
"""
rotated(model, ξ) = RotatedModel(model, ξ)

"""
    $(SIGNATURES)

Returns the rotation angle of the rotated `model`
"""
posangle(model::RotatedModel) = atan(model.s, model.c)

@inline function transform_image(model::RotatedModel, x, y)
    s,c = model.s, model.c
    return c*x - s*y, s*x + c*y
end

@inline function transform_uv(model::RotatedModel, u, v)
    s,c = model.s, model.c
    return c*u - s*v, + s*u + c*v
end


function scale_image(model::RotatedModel{M}, x, y) where {M}
    scale_image(ispolarized(M), model, x, y)
end


@inline scale_image(::NotPolarized, model::RotatedModel{M,T}, x, y) where {M,T} = unitscale(T, M)

@inline function spinor2_rotate(c, s)
    u = oneunit(c)
    z = zero(s)
    c2 = c^2 - s^2
    s2 = 2*c*s
    return SMatrix{4,4}(u,  z,  z,  z,
                        z,  c2, s2, z,
                        z, -s2, c2, z,
                        z,   z,  z, u)

end

@inline function scale_image(::IsPolarized, model::RotatedModel, x, y)
    return spinor2_rotate(model.c, model.s)
end

@inline function scale_uv(model::RotatedModel{M}, u, v) where {M}
    scale_uv(ispolarized(M), model, u, v)
end


@inline scale_uv(::NotPolarized, model::RotatedModel, u, v) = oneunit(model.c)

@inline function scale_uv(::IsPolarized, model::RotatedModel, x, y)
    return spinor2_rotate(model.c, model.s)
end
