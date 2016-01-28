# This file is a part of Julia. License is MIT: http://julialang.org/license

# Tests for /base/stacktraces.jl

# Some tests don't currently work for Appveyor 32-bit Windows
const APPVEYOR_WIN32 = (
    OS_NAME == :Windows && WORD_SIZE == 32 && get(ENV, "APPVEYOR", "False") == "True"
)

if !APPVEYOR_WIN32
    let
        @noinline child() = stacktrace()
        @noinline parent() = child()
        @noinline grandparent() = parent()
        line_numbers = @__LINE__ - [3, 2, 1]

        # Basic tests.
        stack = grandparent()
        @assert length(stack) >= 3 "Compiler has unexpectedly inlined functions"
        @test [:child, :parent, :grandparent] == [f.func for f in stack[1:3]]
        for (line, frame) in zip(line_numbers, stack[1:3])
            @test [Symbol(@__FILE__), line] in
                ([frame.file, frame.line], [frame.inlined_file, frame.inlined_line])
        end
        @test [false, false, false] == [f.from_c for f in stack[1:3]]

        # Test remove_frames!
        stack = StackTraces.remove_frames!(grandparent(), :parent)
        @test stack[1] == StackFrame(:grandparent, @__FILE__, line_numbers[3])

        stack = StackTraces.remove_frames!(grandparent(), [:child, :something_nonexistent])
        @test stack[1:2] == [
            StackFrame(:parent, @__FILE__, line_numbers[2]),
            StackFrame(:grandparent, @__FILE__, line_numbers[3])
        ]
    end
end

let
    # Test from_c
    default, with_c, without_c = stacktrace(), stacktrace(true), stacktrace(false)
    @test default == without_c
    @test length(with_c) > length(without_c)
    @test !isempty(filter(frame -> frame.from_c, with_c))
    @test isempty(filter(frame -> frame.from_c, without_c))
end

@test StackTraces.lookup(C_NULL) == StackTraces.UNKNOWN

let
    # No errors should mean nothing in catch_backtrace
    @test catch_backtrace() == StackFrame[]

    @noinline bad_function() = throw(UndefVarError(:nonexistent))
    function try_catch()
        try
            bad_function()
        catch
            return catch_stacktrace()
        end
    end
    line_numbers = @__LINE__ - [8, 5]

    # Test try...catch with catch_stacktrace
    @test try_catch()[1:2] == [
        StackFrame(:bad_function, @__FILE__, line_numbers[1]),
        StackFrame(:try_catch, @__FILE__, line_numbers[2])
    ]
end

let
    # Test try...catch with stacktrace
    function try_stacktrace()
        try
            error()
        catch
            true  # noop corrects stacktrace line numbers
            return stacktrace()
        end
    end
    line_number = @__LINE__ - 3

    @test try_stacktrace()[1] == StackFrame(:try_stacktrace, @__FILE__, line_number)

    # TODO: Demonstrates an issue that occurs when stacktraces is called at the beginning
    # of a catch. Once the issue is corrected, this test case will fail and line_number
    # should be adjusted to `@__LINE__ - 3` below.
    function try_stacktrace_bad()
        try
            error()
            true  # Line reported by stacktraces
            # Ignored
        catch
            return stacktrace()  # Line that should be reported
        end
    end
    line_number = @__LINE__ - 6

    @test try_stacktrace_bad()[1] == StackFrame(:try_stacktrace_bad, @__FILE__, line_number)
end
