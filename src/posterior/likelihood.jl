struct ConditionedLikelihood{F, O}
    kernel::F
    obs::O
end
@inline DensityInterface.logdensityof(d::ConditionedLikelihood, μ) = logdensityof(@inline(d.kernel(μ)), d.obs)


"""
    likelihood(d::ConditionedLikelihood, μ)

Returns the likelihood of the model, with parameters μ. That is, we return the
distribution of the data given the model parameters μ. Samples from this distribution
are simulated data.
"""
likelihood(d::ConditionedLikelihood, μ) = d.kernel(μ)


struct _Visibility{S,L}
    S::S
    L::L
end

function (v::_Visibility)(μ)
    return ComplexVisLikelihood(baseimage(μ), v.S, v.L)
end

# internal function that creates the likelihood for a set of complex visibilities
function makelikelihood(data::Stoked.EHTObservationTable{<:Stoked.EHTVisibilityDatum})
    Σ = noise(data).^2
    vis = measurement(data)
    lnorm = VLBILikelihoods.lognorm(ComplexVisLikelihood(vis, Σ))
    ℓ = ConditionedLikelihood(_Visibility(Σ, lnorm), vis)
    return ℓ
end

struct _Coherency{S,L}
    S::S
    L::L
end

function (c::_Coherency)(μ)
    return CoherencyLikelihood(baseimage(μ), c.S, c.L)
end

function makelikelihood(data::Stoked.EHTObservationTable{<:Stoked.EHTCoherencyDatum})
    Σ = map(x->x.^2, noise(data))
    vis = measurement(data)
    lnorm = VLBILikelihoods.lognorm(CoherencyLikelihood(vis, Σ))
    ℓ = ConditionedLikelihood(_Coherency(Σ, lnorm), vis)
    return ℓ
end

struct _VisAmp{S}
    S::S
end

function (v::_VisAmp)(μ)
    return RiceAmplitudeLikelihood(abs.(baseimage(μ)), v.S)
end

# internal function that creates the likelihood for a set of visibility amplitudes
function makelikelihood(data::Stoked.EHTObservationTable{<:Stoked.EHTVisibilityAmplitudeDatum})
    Σ = noise(data).^2
    amp = measurement(data)
    ℓ = ConditionedLikelihood(_VisAmp(Σ), amp)
    return ℓ
end

struct _LCamp{F,S,L}
    f::F
    S::S
    L::L
end

function (c::_LCamp)(μ)
    return AmplitudeLikelihood(c.f(baseimage(μ)), c.S, c.L)
end

# internal function that creates the likelihood for a set of log closure amplitudes
function makelikelihood(data::Stoked.EHTObservationTable{<:Stoked.EHTLogClosureAmplitudeDatum})
    Σlca = factornoisecovariance(arrayconfig(data))
    f = Base.Fix2(logclosure_amplitudes, designmat(arrayconfig(data)))
    amp = measurement(data)
    lnorm = VLBILikelihoods.lognorm(AmplitudeLikelihood(amp, Σlca))
    ℓ = ConditionedLikelihood(_LCamp(f, Σlca, lnorm), amp)
    return ℓ
end

struct _CPhase{F,S,L}
    f::F
    S::S
    L::L
end

function (c::_CPhase)(μ)
    return ClosurePhaseLikelihood(c.f(baseimage(μ)), c.S, c.L)
end

# internal function that creates the likelihood for a set of closure phase datum
function makelikelihood(data::Stoked.EHTObservationTable{<:Stoked.EHTClosurePhaseDatum})
    Σcp = factornoisecovariance(arrayconfig(data))
    f = Base.Fix2(closure_phases, designmat(arrayconfig(data)))
    phase = measurement(data)
    lnorm = VLBILikelihoods.lognorm(ClosurePhaseLikelihood(phase, Σcp))
    ℓ = ConditionedLikelihood(_CPhase(f, Σcp, lnorm), phase)
    return ℓ
end
