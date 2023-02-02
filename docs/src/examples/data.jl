# # Loading Data into Comrade

# The VLBI field does not have a standarized data format, and the EHT uses a
# particular uvfits format that is similar to the optical interferometry oifits format.
# As a result, we reuse the excellent `eht-imaging` package to load data into `Comrade`.

# Once the data is loaded we then convert the data into the tabular format `Comrade`
# expects. Note that in the future this may change to a Julia package as the Julia radio
# astronomy group grows.

# To get started we will load `Comrade` and `Plots` to enable visualizations of the data

using Comrade
using Plots

# To load the data we will use `eht-imaging`. We will use the 2017 public M87 data which can be downloaded from
# [cyverse](https://datacommons.cyverse.org/browse/iplant/home/shared/commons_repo/curated/EHTC_FirstM87Results_Apr2019)

obseht = load_ehtim_uvfits(joinpath(@__DIR__, "../assets/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits"))
# Add scan and coherently average over them. The eht data has been phase calibrated so that
# this is fine to do.
obs = scan_average(obseht)
# !!! Warning
#    We use a custom scan-averaging function to ensure that the scan-times are homogenized.

# We can now extract data products that `Comrade` can use
coh = extract_coherency(obs) # Coherency matrices
vis = extract_vis(obs) #complex visibilites
amp = extract_amp(obs) # visibility amplitudes
cphase = extract_cphase(obs) # extract minimal set of closure phases
lcamp = extract_lcamp(obs) # extract minimal set of log-closure amplitudes

# !!! Warning
#    Always use our `extract_cphase` and `extract_lcamp` functions to find the closures
#    eht-imaging will sometimes incorrectly calculate a non-redundant set of closures.

# We can also recover the array used in the observation using
ac = arrayconfig(vis)
plot(ac) # Plot the baseline coverage

# To plot the data we just call

l = @layout [a b; c d]
pc = plot(coh)
pv = plot(vis)
pa = plot(amp)
pcp = plot(cphase)
plc = plot(lcamp)

plot(pv, pa, pcp, plc; layout=l)
