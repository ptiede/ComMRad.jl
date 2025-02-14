#println(PyCall.libpython)
using Pyehtim
using Stoked
using FFTW
using Statistics
using Test
using Plots
using VLBIImagePriors

include(joinpath(@__DIR__, "../test_util.jl"))

include(joinpath(@__DIR__, "observation.jl"))
include(joinpath(@__DIR__, "partially_fixed.jl"))
include(joinpath(@__DIR__, "models.jl"))
include(joinpath(@__DIR__, "bayes.jl"))
