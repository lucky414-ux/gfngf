# This file is a part of Julia. License is MIT: https://julialang.org/license

module TestSchur

using Test, LinearAlgebra, Random
using LinearAlgebra: BlasComplex, BlasFloat, BlasReal, QRPivoted

n = 10

# Split n into 2 parts for tests needing two matrices
n1 = div(n, 2)
n2 = 2*n1

Random.seed!(1234321)

areal = randn(n,n)/2
aimg  = randn(n,n)/2

@testset for eltya in (Float32, Float64, ComplexF32, ComplexF64, Int)
    a = eltya == Int ? rand(1:7, n, n) : convert(Matrix{eltya}, eltya <: Complex ? complex.(areal, aimg) : areal)
    asym = a' + a                 # symmetric indefinite
    apd  = a' * a                 # symmetric positive-definite
    for (a, asym, apd) in ((a, asym, apd),
                           (view(a, 1:n, 1:n),
                            view(asym, 1:n, 1:n),
                            view(apd, 1:n, 1:n)))
        ε = εa = eps(abs(float(one(eltya))))

        d,v = eigen(a)
        f   = schur(a)
        @test f.vectors*f.Schur*f.vectors' ≈ a
        @test sort(real(f.values)) ≈ sort(real(d))
        @test sort(imag(f.values)) ≈ sort(imag(d))
        @test istriu(f.Schur) || eltype(a)<:Real
        @test convert(Array, f) ≈ a
        @test_throws FieldError f.A

        sch, vecs, vals = schur(UpperTriangular(triu(a)))
        @test vecs*sch*vecs' ≈ triu(a)
        sch, vecs, vals = schur(UnitUpperTriangular(triu(a)))
        @test vecs*sch*vecs' ≈ UnitUpperTriangular(triu(a))
        sch, vecs, vals = schur(LowerTriangular(tril(a)))
        @test vecs*sch*vecs' ≈ tril(a)
        sch, vecs, vals = schur(UnitLowerTriangular(tril(a)))
        @test vecs*sch*vecs' ≈ UnitLowerTriangular(tril(a))
        sch, vecs, vals = schur(Hermitian(asym))
        @test vecs*sch*vecs' ≈ asym
        sch, vecs, vals = schur(Symmetric(a + transpose(a)))
        @test vecs*sch*vecs' ≈ a + transpose(a)
        sch, vecs, vals = schur(Tridiagonal(a + transpose(a)))
        @test vecs*sch*vecs' ≈ Tridiagonal(a + transpose(a))
        sch, vecs, vals = schur(Bidiagonal(a, :U))
        @test vecs*sch*vecs' ≈ Bidiagonal(a, :U)
        sch, vecs, vals = schur(Bidiagonal(a, :L))
        @test vecs*sch*vecs' ≈ Bidiagonal(a, :L)

        tstring = sprint((t, s) -> show(t, "text/plain", s), f.T)
        zstring = sprint((t, s) -> show(t, "text/plain", s), f.Z)
        vstring = sprint((t, s) -> show(t, "text/plain", s), f.values)
        fstring = sprint((t, s) -> show(t, "text/plain", s), f)
        @test fstring == "$(summary(f))\nT factor:\n$tstring\nZ factor:\n$(zstring)\neigenvalues:\n$vstring"
        @testset "Reorder Schur" begin
            # use asym for real schur to enforce tridiag structure
            # avoiding partly selection of conj. eigenvalues
            ordschura = eltya <: Complex ? a : asym
            S = schur(ordschura)
            select = bitrand(n)
            O = ordschur(S, select)
            sum(select) != 0 && @test S.values[findall(select)] ≈ O.values[1:sum(select)]
            @test O.vectors*O.Schur*O.vectors' ≈ ordschura
            @test_throws FieldError f.A
            Snew = LinearAlgebra.Schur(S.T, S.Z, S.values)
            SchurNew = ordschur!(copy(Snew), select)
            @test O.vectors ≈ SchurNew.vectors
            @test O.Schur ≈ SchurNew.Schur
        end

        if isa(a, Array)
            a1_sf = a[1:n1, 1:n1]
            a2_sf = a[n1+1:n2, n1+1:n2]
        else
            a1_sf = view(a, 1:n1, 1:n1)
            a2_sf = view(a, n1+1:n2, n1+1:n2)
        end
        @testset "Generalized Schur" begin
            f = schur(a1_sf, a2_sf)
            @test f.Q*f.S*f.Z' ≈ a1_sf
            @test f.Q*f.T*f.Z' ≈ a2_sf
            @test istriu(f.S) || eltype(a)<:Real
            @test istriu(f.T) || eltype(a)<:Real
            @test_throws FieldError f.A

            sstring = sprint((t, s) -> show(t, "text/plain", s), f.S)
            tstring = sprint((t, s) -> show(t, "text/plain", s), f.T)
            qstring = sprint((t, s) -> show(t, "text/plain", s), f.Q)
            zstring = sprint((t, s) -> show(t, "text/plain", s), f.Z)
            αstring = sprint((t, s) -> show(t, "text/plain", s), f.α)
            βstring = sprint((t, s) -> show(t, "text/plain", s), f.β)
            fstring = sprint((t, s) -> show(t, "text/plain", s), f)
            @test fstring == "$(summary(f))\nS factor:\n$sstring\nT factor:\n$(tstring)\nQ factor:\n$(qstring)\nZ factor:\n$(zstring)\nα:\n$αstring\nβ:\n$βstring"
        end
        @testset "Reorder Generalized Schur" begin
            NS = schur(a1_sf, a2_sf)
            # Currently just testing with selecting gen eig values < 1
            select = abs2.(NS.values) .< 1
            m = sum(select)
            S = ordschur(NS, select)
            # Make sure that the new factorization still factors matrix
            @test S.Q*S.S*S.Z' ≈ a1_sf
            @test S.Q*S.T*S.Z' ≈ a2_sf
            # Make sure that we have sorted it correctly
            @test NS.values[findall(select)] ≈ S.values[1:m]

            Snew = LinearAlgebra.GeneralizedSchur(NS.S, NS.T, NS.alpha, NS.beta, NS.Q, NS.Z)
            SchurNew = ordschur!(copy(Snew), select)
            @test S.Q ≈ SchurNew.Q
            @test S.S ≈ SchurNew.S
            @test S.T ≈ SchurNew.T
            @test S.Z ≈ SchurNew.Z
            @test S.alpha ≈ SchurNew.alpha
            @test S.beta  ≈ SchurNew.beta
            sS,sT,sQ,sZ = schur(a1_sf,a2_sf)
            @test NS.Q ≈ sQ
            @test NS.T ≈ sT
            @test NS.S ≈ sS
            @test NS.Z ≈ sZ
        end
    end
    @testset "0x0 matrix" for A in (zeros(eltya, 0, 0), view(rand(eltya, 2, 2), 1:0, 1:0))
        T, Z, λ = LinearAlgebra.schur(A)
        @test T == A
        @test Z == A
        @test λ == zeros(0)
    end

    if eltya <: Real
        @testset "quasitriangular to triangular" begin
            S = schur(a)
            SC = Schur{Complex}(S)
            @test eltype(SC) == complex(eltype(S))
            @test istriu(SC.T)
            @test SC.Z*SC.Z' ≈ I
            @test SC.Z*SC.T*SC.Z' ≈ a
            @test sort(SC.values,by=LinearAlgebra.eigsortby) ≈ sort(S.values,by=LinearAlgebra.eigsortby)
            @test Schur{Complex}(SC) === SC === Schur{eltype(SC)}(SC)
            @test Schur{eltype(S)}(S) === S
            if eltype(S) === Float32
                S64 = Schur{Float64}(S)
                @test eltype(S64) == Float64
                @test S64.Z == S.Z
                @test S64.T == S.T
                @test S64.values == S.values
            end
        end
    end

    @testset "0x0 $eltya matrices" begin
        A = zeros(eltya, 0, 0)
        B = zeros(eltya, 0, 0)
        S = LinearAlgebra.schur(A, B)
        @test S.S == A
        @test S.T == A
        @test S.Q == A
        @test S.Z == A
        @test S.alpha == zeros(0)
        @test S.beta == zeros(0)
    end
end

@testset "Generalized Schur convergence" begin
    # Check for convergence issues, #40279
    problematic_pencils = [
        (   ComplexF64[0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0; 3.7796350217469814 -3.3125635598133054 0.0 0.0 0.0 0.0 0.0 0.0 6.418270043493963 -6.625127119626611 0.0 0.0 0.0 0.0 0.0 -1.0; -3.312563559813306 3.779635021746982 0.0 0.0 0.0 0.0 0.0 0.0 -6.625127119626612 6.418270043493964 -1.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 3.7796350217469814 0.0 0.0 -3.3125635598133054 0.0 0.0 0.0 -1.0 6.418270043493963 0.0 0.0 -6.625127119626611 0.0 0.0; 0.0 0.0 0.0 3.779635021746982 -3.312563559813306 0.0 0.0 0.0 0.0 0.0 0.0 6.418270043493964 -6.625127119626612 0.0 -1.0 0.0; 0.0 0.0 0.0 -3.3125635598133054 3.7796350217469814 0.0 0.0 0.0 0.0 0.0 0.0 -6.625127119626611 6.418270043493963 -1.0 0.0 0.0; 0.0 0.0 -3.312563559813306 0.0 0.0 3.779635021746982 0.0 0.0 0.0 0.0 -6.625127119626612 0.0 -1.0 6.418270043493964 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 3.7796350217469814 -3.3125635598133054 0.0 0.0 0.0 -1.0 0.0 0.0 6.418270043493963 -6.625127119626611; 0.0 0.0 0.0 0.0 0.0 0.0 -3.312563559813306 3.779635021746982 -1.0 0.0 0.0 0.0 0.0 0.0 -6.625127119626612 6.418270043493964],
            ComplexF64[1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -3.7796350217469814 3.312563559813306 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 3.3125635598133054 -3.779635021746982 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -3.7796350217469814 0.0 0.0 3.312563559813306 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -3.779635021746982 3.3125635598133054 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 3.312563559813306 -3.7796350217469814 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 3.3125635598133054 0.0 0.0 -3.779635021746982 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -3.7796350217469814 3.312563559813306; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 3.3125635598133054 -3.779635021746982]
        ),
        (   ComplexF64[0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0; 0.0 0.0 0.0 0.0 0.0 0.0 -1.0 0.0 0.0 0.0 0.0 0.0 -2.62 0.0 0.0 0.0 0.0 0.0 -1.0 -1.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -2.62 0.0 0.0 0.0 0.0 0.0 -1.0 -1.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0 0.0 0.0 0.0 0.0 0.0 -2.62 0.0 0.0 0.0 0.0 0.0 -1.0 -1.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -2.62 0.0 0.0 0.0 0.0 0.0 -1.0 -1.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0 0.0 0.0 0.0 0.0 0.0 -2.62 0.0 0.0 0.0 0.0 0.0 -1.0 -1.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -2.62 -1.0 0.0 0.0 0.0 0.0 -1.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0 0.0 0.0 0.0 0.0 -1.0 -2.62 0.0 0.0 0.0 0.0 0.0; 0.0 -1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0 -1.0 0.0 0.0 0.0 0.0 0.0 -2.62 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0 -1.0 0.0 0.0 0.0 0.0 0.0 -2.62 0.0 0.0 0.0; 0.0 0.0 0.0 -1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0 -1.0 0.0 0.0 0.0 0.0 0.0 -2.62 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0 -1.0 0.0 0.0 0.0 0.0 0.0 -2.62 0.0; 0.0 0.0 0.0 0.0 0.0 -1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0 -1.0 0.0 0.0 0.0 0.0 0.0 -2.62],
            ComplexF64[1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0]
        ),
        (   ComplexF64[0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0; 0.33748484079831426 -0.10323794456968927 0.0 0.0 0.0 0.0 0.0 0.0 -2.5940303184033713 -0.20647588913937853 0.0 0.0 0.0 0.0 0.0 -1.0; -0.10323794456968927 0.3374848407983142 0.0 0.0 0.0 0.0 0.0 0.0 -0.20647588913937853 -2.5940303184033713 -1.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.33748484079831426 0.0 0.0 -0.10323794456968927 0.0 0.0 0.0 -1.0 -2.5940303184033713 0.0 0.0 -0.20647588913937853 0.0 0.0; 0.0 0.0 0.0 0.3374848407983142 -0.10323794456968927 0.0 0.0 0.0 0.0 0.0 0.0 -2.5940303184033713 -0.20647588913937853 0.0 -1.0 0.0; 0.0 0.0 0.0 -0.10323794456968927 0.33748484079831426 0.0 0.0 0.0 0.0 0.0 0.0 -0.20647588913937853 -2.5940303184033713 -1.0 0.0 0.0; 0.0 0.0 -0.10323794456968927 0.0 0.0 0.3374848407983142 0.0 0.0 0.0 0.0 -0.20647588913937853 0.0 -1.0 -2.5940303184033713 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.33748484079831426 -0.10323794456968927 0.0 0.0 0.0 -1.0 0.0 0.0 -2.5940303184033713 -0.20647588913937853; 0.0 0.0 0.0 0.0 0.0 0.0 -0.10323794456968927 0.3374848407983142 -1.0 0.0 0.0 0.0 0.0 0.0 -0.20647588913937853 -2.5940303184033713],
            ComplexF64[1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -0.33748484079831426 0.10323794456968927 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.10323794456968927 -0.3374848407983142 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -0.33748484079831426 0.0 0.0 0.10323794456968927 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -0.3374848407983142 0.10323794456968927 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.10323794456968927 -0.33748484079831426 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.10323794456968927 0.0 0.0 -0.3374848407983142 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -0.33748484079831426 0.10323794456968927; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.10323794456968927 -0.3374848407983142]
        ),
        (   ComplexF64[0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0; 1.7391668762048442 -1.309613611600033 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 2.150333752409688 -2.619227223200066 0.0 -1.0 0.0 0.0 0.0 0.0 0.0 0.0; -1.3096136116000332 1.739166876204844 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -2.6192272232000664 2.150333752409688 -1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 1.739166876204844 0.0 0.0 -1.3096136116000332 0.0 0.0 0.0 0.0 0.0 -1.0 2.150333752409688 0.0 0.0 -2.6192272232000664 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 1.739166876204844 0.0 0.0 0.0 0.0 -1.3096136116000332 0.0 -1.0 0.0 0.0 2.150333752409688 0.0 0.0 0.0 0.0 -2.6192272232000664 0.0; 0.0 0.0 0.0 0.0 1.7391668762048442 0.0 0.0 0.0 0.0 -1.309613611600033 0.0 0.0 0.0 0.0 2.150333752409688 -1.0 0.0 0.0 0.0 -2.619227223200066; 0.0 0.0 -1.309613611600033 0.0 0.0 1.7391668762048442 0.0 0.0 0.0 0.0 0.0 0.0 -2.619227223200066 0.0 -1.0 2.150333752409688 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 1.739166876204844 -1.3096136116000332 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 2.150333752409688 -2.6192272232000664 0.0 -1.0; 0.0 0.0 0.0 0.0 0.0 0.0 -1.309613611600033 1.7391668762048442 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -2.619227223200066 2.150333752409688 -1.0 0.0; 0.0 0.0 0.0 -1.309613611600033 0.0 0.0 0.0 0.0 1.7391668762048442 0.0 0.0 0.0 0.0 -2.619227223200066 0.0 0.0 0.0 -1.0 2.150333752409688 0.0; 0.0 0.0 0.0 0.0 -1.3096136116000332 0.0 0.0 0.0 0.0 1.739166876204844 0.0 0.0 0.0 0.0 -2.6192272232000664 0.0 -1.0 0.0 0.0 2.150333752409688],
            ComplexF64[1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.7391668762048442 1.3096136116000332 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.309613611600033 -1.739166876204844 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.739166876204844 0.0 0.0 1.309613611600033 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.739166876204844 0.0 0.0 0.0 0.0 1.309613611600033 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.7391668762048442 0.0 0.0 0.0 0.0 1.3096136116000332; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.3096136116000332 0.0 0.0 -1.7391668762048442 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.739166876204844 1.309613611600033 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.3096136116000332 -1.7391668762048442 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.3096136116000332 0.0 0.0 0.0 0.0 -1.7391668762048442 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.309613611600033 0.0 0.0 0.0 0.0 -1.739166876204844]
        ),
        (   ComplexF64[0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0; 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.90076923076925 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -12.019230769230788 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0000000000000007; 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.90076923076925 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0000000000000007 -12.019230769230788 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.90076923076925 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0000000000000007 -12.019230769230788 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769246 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0000000000000007 -12.019230769230784 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.90076923076925 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0000000000000007 -12.019230769230788 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.90076923076925 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0000000000000007 -12.019230769230788 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.90076923076925 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0000000000000007 -12.019230769230788 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769246 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0000000000000007 -12.019230769230784 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.90076923076925 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0000000000000007 -12.019230769230788 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.90076923076925 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -1.0000000000000007 -12.019230769230788; -6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -12.019230769230784 -1.0000000000000007 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769248 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 -6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -12.019230769230784 -1.0000000000000007 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769248 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 -6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -12.019230769230784 -1.0000000000000007 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769248 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 -6.009615384615393 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384622 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -12.019230769230784 -1.0000000000000007 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769244 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 -6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -12.019230769230784 -1.0000000000000007 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769248 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 -6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -12.019230769230784 -1.0000000000000007 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769248 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -12.019230769230784 -1.0000000000000007 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769248 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615393 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384622 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -12.019230769230784 -1.0000000000000007 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769244 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -12.019230769230784 -1.0000000000000007 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769248 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.490384615384624 -1.0000000000000007 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -12.019230769230784 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 11.900769230769248],
            ComplexF64[1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615393 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615392 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615392 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615392 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615393 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615392 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615392; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384622 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615392 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384622 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 6.009615384615394 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 -6.490384615384624]
        )]

    for (A, B) in problematic_pencils
        f = schur(A, B)
        @test f.Q*f.S*f.Z' ≈ A
        @test f.Q*f.T*f.Z' ≈ B
    end
end

@testset "adjoint and transpose for schur (#40941)" begin
    A = rand(3, 3)
    B = schur(A', A)
    C = B.left*B.S*B.right'
    D = schur(transpose(A), A)
    E = D.left*D.S*D.right'
    @test A' ≈ C ≈ E
end

@testset "UpperHessenberg schur" begin
    A = UpperHessenberg(rand(ComplexF64, 100, 100))
    B = Array(A)
    fact1 = schur(A)
    fact2 = schur(B)
    @test fact1.values ≈ fact2.values
    @test fact1.Z * fact1.T * fact1.Z' ≈ B

    A = UpperHessenberg(rand(Int32, 50, 50))
    B = Array(A)
    fact1 = schur(A)
    fact2 = schur(B)
    @test fact1.values ≈ fact2.values
    @test fact1.Z * fact1.T * fact1.Z' ≈ B
end

end # module TestSchur
