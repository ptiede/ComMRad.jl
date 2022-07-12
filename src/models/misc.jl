export ZeroModel

"""
    $(TYPEDEF)

Defines a model that is `empty` that is it return zero for everything.

# Notes
This returns 0 by using `FillArrays` so everything should be non-allocating
"""
struct ZeroModel{T} <: AbstractModel end

ZeroModel() = ZeroModel{Float64}()

visanalytic(::Type{<:ZeroModel}) = IsAnalytic()
imanalytic(::Type{<:ZeroModel}) = IsAnalytic()

visibility_point(::ZeroModel{T}, args...) where {T} = zero(T)
intensity_point(::ZeroModel{T}, args...) where {T} = zero(T)

_visibilities(::ZeroModel{T}, u, v, args...) where {T} = Fill(zero(T), length(u))
intensitymap(::ZeroModel{T}, fovx, fovy, nx, ny, args...) where {T} = IntensityMap(Fill(zero(T), ny, nx), fovx, fovy, args...)

@inline AddModel(::ZeroModel, x) = x
@inline AddModel(x, ::ZeroModel) = x

@inline ConvolvedModel(m::ZeroModel, ::Any) = m
@inline ConvolvedModel(::Any, m::ZeroModel) = m


# Now here we use a bit of meta programming to deal with combinators
for m in [:RenormalizedModel, :RotatedModel, :ShiftedModel, :StretchedModel]
    @eval begin
      $m(z::ZeroModel{T}, arg::Vararg{X,N}) where {T,X<:Number,N} = z
    end
end
