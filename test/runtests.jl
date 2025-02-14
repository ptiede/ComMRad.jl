#if lowercase(get(ENV, "CI", "false")) == "true"
#    include("install_pycall.jl")
#end
using Pkg, Distributions
using ChainRulesTestUtils
using Pyehtim
using Optimization
using Stoked
using Test
using LinearAlgebra
using CairoMakie
import Plots

#using PyCall

include(joinpath(@__DIR__, "test_util.jl"))

Pkg.develop(PackageSpec(url="https://github.com/ptiede/StokedBase.jl"))
@testset "Stoked.jl" begin
    include(joinpath(@__DIR__, "Core/core.jl"))
    include(joinpath(@__DIR__, "ext/comradeahmc.jl"))
    include(joinpath(@__DIR__, "ext/comradeoptimization.jl"))
    include(joinpath(@__DIR__, "ext/comradepigeons.jl"))
    include(joinpath(@__DIR__, "ext/comradedynesty.jl"))
    include(joinpath(@__DIR__, "ext/comradenested.jl"))
end
