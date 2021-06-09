abstract type GeometricModel{T} <: AbstractModel{T} end
VisStyle(::Type{<:GeometricModel}) = VisAnalytic()



@inline flux(::GeometricModel{T}) where {T} = one(T)

"""
    $(TYPEDEF)
Gaussian geometrical model.
This is a Gaussian with unit flux and standard deviation.

## Notes
To change the Gaussian flux, and shape please use the modifier functions
"""
struct Gaussian{T} <: GeometricModel{T} end
Gaussian() = Gaussian{Float64}()

@inline function intensity(::ImAnalytic, ::Gaussian, x,y, args...)
    return exp(-(x^2+y^2)/2)/2π
end

@inline function _visibility(::Gaussian{T}, u, v, args...) where {T}
    return exp(-2π^2*(u^2 + v^2)) + zero(T)im
end


raw"""
    $(TYPEDEF)
Tophat disk geometrical model. The model is given by
```math
    I(x,y) = \begin{cases} \pi^{-1} & x^2+y^2 < 1 \\ 0 & x^2+y^2 \geq 0 \end{cases}
```
"""
struct Disk{T} <: GeometricModel{T} end
Disk() = Disk{Float64}()

@inline function intensity(::ImAnalytic, ::Disk{T}, x, y, args...) where {T}
    r = x^2 + y^2
    return r < 1 ?  one(T)/(π) : zero(T)
end

@inline function _visibility(::VisAnalytic, ::Disk{T}, x, y, args...) where {T}
    ur = 2π*hypot(x,y) + eps(T)
    return 2*besselj1(ur)/(ur) + zero(T)im
end


struct MRing{T,N} <: GeometricModel{T}
    """
    Radius of the thin ring
    """
    radius::T
    """
    Real Fourier mode coefficients
    """
    α::NTuple{N,T}
    """
    Imaginary Fourier mode coefficients
    """
    β::NTuple{N,T}
end

@inline function intensity(::ImAnalytic, m::MRing{T,N}, x::Number, y::Number, fov=160.0, nx=128, args...) where {T,N}
    r = hypot(x,y)
    θ = atan(x,y)
    dr = fov/(nx-1)
    if (abs(r-m.radius) < dr/2)
        acc = one(T)
        for n in 1:N
            s,c = sincos(n*θ)
            acc += m.α[n]*c - m.β[n]*s
        end
        return acc/(2π*m.radius*dr)
    else
        return zero(T)
    end
end


@inline function _visibility(::VisAnalytic, m::MRing{T,N}, u, v, args...) where {T,N}
    k = 2π*sqrt(u^2 + v^2)*m.radius + eps(T)*m.radius
    vis = besselj0(k) + zero(T)*im
    θ = atan(u, v)
    @inbounds for n in 1:N
        s,c = sincos(n*θ)
        vis += 2*(m.α[n]*c - m.β[n]*s)*(1im)^n*besselj(n, k)
    end
    return vis
end

"""
    $(TYPEDEF)
Creates the ConcordanceCrescent model, i.e. a flat-top crescent
with a displacment and a slash. Note this creates a crescent with
unit flux. If you want a different flux please use the `renomed`
modifier.

## Fields
## Notes
Unlike the Gaussian and Disk models this does not create the
unit version. In fact, this model could have been created using
the `Disk` and primitives by using ROSE.jl's model composition
functionality.
"""
struct ConcordanceCrescent{T} <: GeometricModel{T}
    """
    Outer radius of the crescent
    """
    router::T
    """
    Inner radius of the crescent
    (i.e. inside this radius there is a hole)
    """
    rinner::T
    """
    Displacment of the inner disk radius
    """
    shift::T
    """
    Strength of the linear slash. Note that
    s∈[0.0,1.0] to ensure positivity in the image.
    """
    slash::T
end

# Crescent normalization to ensure the
function _crescentnorm(m::ConcordanceCrescent)
    f = (1+m.slash)*(m.router^2 - m.rinner^2) -
        (1-m.slash)*m.shift*m.rinner*m.rinner/m.router
    return 2/π/f
end

function intensity(::ImAnalytic, m::ConcordanceCrescent{T}, x, y, args...) where {T}
    r2 = x^2 + y ^2
    norm = _crescentnorm(m)
    if (r2 < m.router^2 && (x-m.shift)^2 + y^2 > m.rinner^2 )
        return norm/2*((1+x/m.router) + m.slash*(1-x/m.router))
    else
        return zero(T)
    end
end

function _visibility(::VisAnalytic, m::ConcordanceCrescent{T}, u, v, args...) where {T}
    k = 2π*sqrt(u^2 + v^2) + eps(T)
    norm = π*_crescentnorm(m)/k
    phaseshift = exp(2im*π*m.shift*u)
    b0outer,b0inner = besselj0(k*m.router), besselj0(k*m.rinner)
    b1outer,b1inner = besselj1(k*m.router), besselj1(k*m.rinner)
    b2outer,b2inner = besselj(2,k*m.router), besselj(2, k*m.rinner)

    v1 = (1+m.slash)*m.router*b1outer
    v2 = ((1+m.slash) + (1-m.slash)*m.shift/m.router)*
            phaseshift*m.rinner*b1inner
    v3 = -2im*π*u*(1-m.slash)*(m.router*b0outer -
                           m.router*b2outer -
                           2*b1outer/k
                          )/(2*k)
    v4 = -2im*π*u*(1-m.slash)*(m.rinner*b0inner -
                          m.rinner*b2inner -
                          2*b1inner/k
                         )/(2*k)*(m.rinner/m.router)*phaseshift
    return norm*(v1-v2+v3-v4)
end
