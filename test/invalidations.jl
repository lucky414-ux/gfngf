const BASE_TEST_PATH = joinpath(Sys.BINDIR, "..", "share", "julia", "test")
isdefined(Main, :MethodInvalidations) || @eval Main include(joinpath($(BASE_TEST_PATH), "testhelpers", "MethodInvalidations.jl"))

using .Main.MethodInvalidations

f(x) = x
g(x) = f(x)
g(2)

invs = @method_invalidations k(x) = x
@test !invalidated(invs, g)
invs = @method_invalidations f(x::Int) = 2x
@test invalidated(invs, g)

import Base
struct A end

invs = @method_invalidations Base.convert(::Type{T}, ::A) where T<:Union{AbstractString,AbstractChar,Number} = 1
@test !invalidated(invs, Base.show_unquoted)
