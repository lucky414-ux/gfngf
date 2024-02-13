# This file is a part of Julia. License is MIT: https://julialang.org/license

# for curmod_str
include("testenv.jl")

@testset "ExponentialBackOff" begin
    @test length(ExponentialBackOff(n=10)) == 10
    @test collect(ExponentialBackOff(n=10, first_delay=0.01))[1] == 0.01
    @test maximum(ExponentialBackOff(n=10, max_delay=0.06)) == 0.06
    ratio(x) = x[2:end]./x[1:end-1]
    @test all(x->x ≈ 10.0, ratio(collect(ExponentialBackOff(n=10, max_delay=Inf, factor=10, jitter=0.0))))
    Libc.srand(12345)
    x = ratio(collect(ExponentialBackOff(n=100, max_delay=Inf, factor=1, jitter=0.1)))
    xm = sum(x) / length(x)
    @test abs(xm - 1.0) < 0.01
    Libc.srand()
end
@testset "retrying after errors" begin
    function foo_error(c, n)
        c[1] += 1
        if c[1] <= n
            error("foo")
        end
        return 7
    end

    # Success on first attempt
    c = [0]
    @test retry(foo_error)(c,0) == 7
    @test c[1] == 1

    # Success on second attempt
    c = [0]
    @test retry(foo_error)(c,1) == 7
    @test c[1] == 2

    # 2 failed retry attempts, so exception is raised
    c = [0]
    ex = try retry(foo_error, delays=ExponentialBackOff(n=2))(c,3) catch e; e end
    @test ex.msg == "foo"
    @test c[1] == 3

    c = [0]
    ex = try retry(foo_error, check=(s,e)->(s,isa(e, ErrorException)))(c,2) catch e; e end
    @test typeof(ex) == ErrorException
    @test ex.msg == "foo"
    @test c[1] == 2

    c = [0]
    ex = try retry(foo_error, check=(s,e)->(s,e.msg == "foo"))(c,2) catch e; e end
    @test typeof(ex) == ErrorException
    @test ex.msg == "foo"
    @test c[1] == 2

    # No retry if condition does not match
    c = [0]
    ex = try retry(foo_error, check=(s,e)->(s,e.msg == "bar"))(c,2) catch e; e end
    @test typeof(ex) == ErrorException
    @test ex.msg == "foo"
    @test c[1] == 1

    c = [0]
    ex = try retry(foo_error, check=(s,e)->(s,try e.http_status_code == "503"; catch; end != true))(c,2) catch e; e end
    @test typeof(ex) == ErrorException
    @test ex.msg == "foo"
    @test c[1] == 2

    c = [0]
    ex = try retry(foo_error, check=(s,e)->(s,isa(e,SystemError)))(c,2) catch e; e end
    @test typeof(ex) == ErrorException
    @test ex.msg == "foo"
    @test c[1] == 1

    # Test example in docstring where the check function doesn't return the state.
    c = [0]
    @test retry(foo_error, check=(s,e)->e.msg == "foo")(c,1) == 7
    @test c[1] == 2

    # Functions with keyword arguments
    foo_kwargs(x; y=5) = x + y
    @test retry(foo_kwargs)(3) == 8
    @test retry(foo_kwargs)(3; y=4) == 7

    # non-Functions
    @test retry(Float64)(1) === 1.0
end

@testset "SystemError initialization" begin
    e = SystemError("fail")
    @test e.extrainfo === nothing
end

@testset "MethodError for methods without line numbers" begin
    try
        eval(Expr(:function, :(f44319()), 0))
        f44319(1)
    catch e
        s = sprint(showerror, e)
        @test s == """MethodError: no method matching f44319(::Int$(Sys.WORD_SIZE))
                      The function `f44319` exists, but no method is defined for this combination of argument types.

                      Closest candidates are:\n  f44319()\n   @ $curmod_str none:0
                      """
    end
end

@testset "All types ending with Exception or Error subtype Exception" begin
    function test_exceptions(mod, visited=Set{Module}())
        if mod ∉ visited
            push!(visited, mod)
            for name in names(mod, all=true)
                isdefined(mod, name) || continue
                value = getfield(mod, name)

                if value isa Module
                    test_exceptions(value, visited)
                elseif value isa Type
                    str = string(value)
                    if endswith(str, "Exception") || endswith(str, "Error")
                        @test value <: Exception
                    end
                end
            end
        end
        visited
    end
    visited = test_exceptions(Base)
    test_exceptions(Core, visited)
end
