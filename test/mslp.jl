# Intended to be run from nep-pack/ directory or nep-pack/test directory
workspace()
push!(LOAD_PATH, string(@__DIR__, "/../src"))
push!(LOAD_PATH, string(@__DIR__, "/../src/gallery_extra"))
push!(LOAD_PATH, string(@__DIR__, "/../src/gallery_extra/waveguide"))

using LinSolvers
using IterativeSolvers
using Base.Test
using LinearMaps;
using Gallery;
using NEPSolver;
using NEPCore;

A=sprandn(100,100,0.1);
B=sprandn(100,100,0.1);

target=0;
nev=3;
nep=nep_gallery("dep0");
@testset "MSLP" begin
    # Full matrix test
    λ1,v1=mslp(nep)
    @test norm(compute_Mlincomb(nep,λ1,v1))<1e-10

    Av=[sparse(nep.A[1]),sparse(nep.A[2])];
    nep.A=Av;
    # Sparse matrix test
    λ2,v2=mslp(nep)
    @test norm(compute_Mlincomb(nep,λ2,v2))<1e-10

    @test λ1≈λ2 # They should be exactly the same
    
end
