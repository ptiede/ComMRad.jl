using .Dynesty


samplertype(::Type{<:NestedSampler}) = IsCube()

function AbstractMCMC.sample(post::TransformedPosterior, sampler::NestedSampler, args...; kwargs...)
    ℓ(x) = logdensityof(post, x)
    kw = delete!(Dict(kwargs), :init_params)
    res = sample(ℓ, identity, sampler, args...; kw...)
    samples, weights = res["samples"], exp.(res["logwt"] .- res["logz"][end])
    chain = transform.(Ref(post), eachrow(samples)) |> TupleVector
    stats = (logl = res["logl"],
             logz = res["logz"][end],
             logzerr = res["logz"][end],
             weights = weights,
            ) |> TupleVector
    return chain, stats
end
