# This file is a part of Julia. License is MIT: https://julialang.org/license

# macro wrappers for various reflection functions

import Base: typesof, insert!

separate_kwargs(args...; kwargs...) = (args, values(kwargs))

"""
Transform a dot expression into one where each argument has been replaced by a
variable "xj" (with j an integer from 1 to the returned i).
The list `args` contains the original arguments that have been replaced.
"""
function recursive_dotcalls!(ex, args, i=1)
    if !(ex isa Expr) || ((ex.head !== :. || !(ex.args[2] isa Expr)) &&
                          (ex.head !== :call || string(ex.args[1])[1] != '.'))
        newarg = Symbol('x', i)
        if Meta.isexpr(ex, :...)
            push!(args, only(ex.args))
            return Expr(:..., newarg), i+1
        else
            push!(args, ex)
            return newarg, i+1
        end
    end
    (start, branches) = ex.head === :. ? (1, ex.args[2].args) : (2, ex.args)
    for j in start:length(branches)
        branch, i = recursive_dotcalls!(branches[j], args, i)
        branches[j] = branch
    end
    return ex, i
end

function gen_call_with_extracted_types(__module__, fcn, ex0, kws=Expr[])
    if isa(ex0, Expr)
        if ex0.head === :do && Meta.isexpr(get(ex0.args, 1, nothing), :call)
            if length(ex0.args) != 2
                return Expr(:call, :error, "ill-formed do call")
            end
            i = findlast(a->(Meta.isexpr(a, :kw) || Meta.isexpr(a, :parameters)), ex0.args[1].args)
            args = copy(ex0.args[1].args)
            insert!(args, (isnothing(i) ? 2 : i+1), ex0.args[2])
            ex0 = Expr(:call, args...)
        end
        if ex0.head === :. || (ex0.head === :call && ex0.args[1] !== :.. && string(ex0.args[1])[1] == '.')
            codemacro = startswith(string(fcn), "code_")
            if codemacro && ex0.args[2] isa Expr
                # Manually wrap a dot call in a function
                args = Any[]
                ex, i = recursive_dotcalls!(copy(ex0), args)
                xargs = [Symbol('x', j) for j in 1:i-1]
                dotfuncname = gensym("dotfunction")
                dotfuncdef = Expr(:local, Expr(:(=), Expr(:call, dotfuncname, xargs...), ex))
                return quote
                    $(esc(dotfuncdef))
                    local args = typesof($(map(esc, args)...))
                    $(fcn)($(esc(dotfuncname)), args; $(kws...))
                end
            elseif !codemacro
                fully_qualified_symbol = true # of the form A.B.C.D
                ex1 = ex0
                while ex1 isa Expr && ex1.head === :.
                    fully_qualified_symbol = (length(ex1.args) == 2 &&
                                              ex1.args[2] isa QuoteNode &&
                                              ex1.args[2].value isa Symbol)
                    fully_qualified_symbol || break
                    ex1 = ex1.args[1]
                end
                fully_qualified_symbol &= ex1 isa Symbol
                if fully_qualified_symbol
                    return quote
                        local arg1 = $(esc(ex0.args[1]))
                        if isa(arg1, Module)
                            $(if string(fcn) == "which"
                                  :(which(arg1, $(ex0.args[2])))
                              else
                                  :(error("expression is not a function call"))
                              end)
                        else
                            local args = typesof($(map(esc, ex0.args)...))
                            $(fcn)(Base.getproperty, args)
                        end
                    end
                else
                    return Expr(:call, :error, "dot expressions are not lowered to "
                                * "a single function call, so @$fcn cannot analyze "
                                * "them. You may want to use Meta.@lower to identify "
                                * "which function call to target.")
                end
            end
        end
        if any(a->(Meta.isexpr(a, :kw) || Meta.isexpr(a, :parameters)), ex0.args)
            return quote
                local arg1 = $(esc(ex0.args[1]))
                local args, kwargs = $separate_kwargs($(map(esc, ex0.args[2:end])...))
                $(fcn)(Core.kwfunc(arg1),
                       Tuple{typeof(kwargs), Core.Typeof(arg1), map(Core.Typeof, args)...};
                       $(kws...))
            end
        elseif ex0.head === :call
            return Expr(:call, fcn, esc(ex0.args[1]),
                        Expr(:call, typesof, map(esc, ex0.args[2:end])...),
                        kws...)
        elseif ex0.head === :(=) && length(ex0.args) == 2
            lhs, rhs = ex0.args
            if isa(lhs, Expr)
                if lhs.head === :(.)
                    return Expr(:call, fcn, Base.setproperty!,
                                Expr(:call, typesof, map(esc, lhs.args)..., esc(rhs)), kws...)
                elseif lhs.head === :ref
                    return Expr(:call, fcn, Base.setindex!,
                                Expr(:call, typesof, esc(lhs.args[1]), esc(rhs), map(esc, lhs.args[2:end])...), kws...)
                end
            end
        elseif ex0.head === :vcat || ex0.head === :typed_vcat
            if ex0.head === :vcat
                f, hf = Base.vcat, Base.hvcat
                args = ex0.args
            else
                f, hf = Base.typed_vcat, Base.typed_hvcat
                args = ex0.args[2:end]
            end
            if any(a->isa(a,Expr) && a.head === :row, args)
                rows = Any[ (isa(x,Expr) && x.head === :row ? x.args : Any[x]) for x in args ]
                lens = map(length, rows)
                return Expr(:call, fcn, hf,
                            Expr(:call, typesof,
                                 (ex0.head === :vcat ? [] : Any[esc(ex0.args[1])])...,
                                 Expr(:tuple, lens...),
                                 map(esc, vcat(rows...))...), kws...)
            else
                return Expr(:call, fcn, f,
                            Expr(:call, typesof, map(esc, ex0.args)...), kws...)
            end
        elseif ex0.head === :ncat || ex0.head === :typed_ncat
            if ex0.head === :ncat
                f = Base.hvncat
                args = ex0.args
            else
                f = Base.typed_hvncat
                args = ex0.args[2:end]
            end
            d = args[1]
            args = args[2:end]
            xs = []
            function extract_elements(x)
                if isa(x, Expr)
                    if x.head === :nrow
                        extract_elements.(x.args[2:end])
                    elseif x.head === :row
                        extract_elements.(x.args)
                    else
                        push!(xs, x)
                    end
                else
                    push!(xs, x)
                end
            end
            function get_shape(a, is_row_first, d)
                is_row(x) = x.head === :row || x.head === :nrow
                function get_next(x)
                    if !is_row(x) ||
                        x.head === :nrow && d > x.args[1] + 1 ||
                        x.head === :row && d > 1
                        return [x]
                    elseif x.head === :nrow
                        return x.args[2:end]
                    else
                        return x.args
                    end
                end
                if d == 0 || d == 1 && !is_row_first
                    return length(a)
                elseif d == 3 && is_row_first
                    return get_shape(a, is_row_first, d - 1)
                else
                    ashape = map(x -> get_shape(get_next(x), is_row_first, d - 1), a)
                    if length(ashape) > 1
                        counts = ashape .|> first
                        prev_counts = ashape .|> last
                        return [sum(counts), counts, vcat(map(x -> vcat(x...), prev_counts)...)]
                    else
                        return [sum(ashape), ashape]
                    end
                end
            end
            if any(a -> isa(a, Expr) && (a.head === :nrow || a.head === :row), args)
                extract_elements.(args)
                shape = get_shape(args, true, d)
                return Expr(:call, fcn, f,
                            Expr(:call, typesof,
                                (ex0.head === :ncat ? [] : Any[esc(ex0.args[1])])...,
                                Expr(:tuple, map(x -> tuple(x...), shape)...), # shape variant, need dims variant and 1d variant
                                true, #placeholder
                                map(esc, xs)...), kws...)
            else
                extract_elements.(args)
                return Expr(:call, error, "hello 2 $(args), $xs")
            end
        else
            for (head, f) in (:ref => Base.getindex, :hcat => Base.hcat, :(.) => Base.getproperty, :vect => Base.vect, Symbol("'") => Base.adjoint, :typed_hcat => Base.typed_hcat, :string => string)
                if ex0.head === head
                    return Expr(:call, fcn, f,
                                Expr(:call, typesof, map(esc, ex0.args)...), kws...)
                end
            end
        end
    end
    if isa(ex0, Expr) && ex0.head === :macrocall # Make @edit @time 1+2 edit the macro by using the types of the *expressions*
        return Expr(:call, fcn, esc(ex0.args[1]), Tuple{#=__source__=#LineNumberNode, #=__module__=#Module, Any[ Core.Typeof(a) for a in ex0.args[3:end] ]...}, kws...)
    end

    ex = Meta.lower(__module__, ex0)
    if !isa(ex, Expr)
        return Expr(:call, :error, "expression is not a function call or symbol")
    end

    exret = Expr(:none)
    if ex.head === :call
        if any(e->(isa(e, Expr) && e.head === :(...)), ex0.args) &&
            (ex.args[1] === GlobalRef(Core,:_apply_iterate) ||
             ex.args[1] === GlobalRef(Base,:_apply_iterate))
            # check for splatting
            exret = Expr(:call, ex.args[2], fcn,
                        Expr(:tuple, esc(ex.args[3]),
                            Expr(:call, typesof, map(esc, ex.args[4:end])...)))
        else
            exret = Expr(:call, fcn, esc(ex.args[1]),
                         Expr(:call, typesof, map(esc, ex.args[2:end])...), kws...)
        end
    end
    if ex.head === :thunk || exret.head === :none
        exret = Expr(:call, :error, "expression is not a function call, "
                                  * "or is too complex for @$fcn to analyze; "
                                  * "break it down to simpler parts if possible. "
                                  * "In some cases, you may want to use Meta.@lower.")
    end
    return exret
end

"""
Same behaviour as `gen_call_with_extracted_types` except that keyword arguments
of the form "foo=bar" are passed on to the called function as well.
The keyword arguments must be given before the mandatory argument.
"""
function gen_call_with_extracted_types_and_kwargs(__module__, fcn, ex0)
    kws = Expr[]
    arg = ex0[end] # Mandatory argument
    for i in 1:length(ex0)-1
        x = ex0[i]
        if x isa Expr && x.head === :(=) # Keyword given of the form "foo=bar"
            if length(x.args) != 2
                return Expr(:call, :error, "Invalid keyword argument: $x")
            end
            push!(kws, Expr(:kw, esc(x.args[1]), esc(x.args[2])))
        else
            return Expr(:call, :error, "@$fcn expects only one non-keyword argument")
        end
    end
    return gen_call_with_extracted_types(__module__, fcn, arg, kws)
end

for fname in [:which, :less, :edit, :functionloc]
    @eval begin
        macro ($fname)(ex0)
            gen_call_with_extracted_types(__module__, $(Expr(:quote, fname)), ex0)
        end
    end
end

macro which(ex0::Symbol)
    ex0 = QuoteNode(ex0)
    return :(which($__module__, $ex0))
end

for fname in [:code_warntype, :code_llvm, :code_native]
    @eval begin
        macro ($fname)(ex0...)
            gen_call_with_extracted_types_and_kwargs(__module__, $(Expr(:quote, fname)), ex0)
        end
    end
end

macro code_typed(ex0...)
    thecall = gen_call_with_extracted_types_and_kwargs(__module__, :code_typed, ex0)
    quote
        local results = $thecall
        length(results) == 1 ? results[1] : results
    end
end

macro code_lowered(ex0...)
    thecall = gen_call_with_extracted_types_and_kwargs(__module__, :code_lowered, ex0)
    quote
        local results = $thecall
        length(results) == 1 ? results[1] : results
    end
end

macro time_imports(ex)
    quote
        try
            Base.Threads.atomic_add!(Base.TIMING_IMPORTS, 1)
            $(esc(ex))
        finally
            Base.Threads.atomic_sub!(Base.TIMING_IMPORTS, 1)
        end
    end
end

"""
    @functionloc

Applied to a function or macro call, it evaluates the arguments to the specified call, and
returns a tuple `(filename,line)` giving the location for the method that would be called for those arguments.
It calls out to the `functionloc` function.
"""
:@functionloc

"""
    @which

Applied to a function or macro call, it evaluates the arguments to the specified call, and
returns the `Method` object for the method that would be called for those arguments. Applied
to a variable, it returns the module in which the variable was bound. It calls out to the
[`which`](@ref) function.

See also: [`@less`](@ref), [`@edit`](@ref).
"""
:@which

"""
    @less

Evaluates the arguments to the function or macro call, determines their types, and calls the `less`
function on the resulting expression.

See also: [`@edit`](@ref), [`@which`](@ref), [`@code_lowered`](@ref).
"""
:@less

"""
    @edit

Evaluates the arguments to the function or macro call, determines their types, and calls the `edit`
function on the resulting expression.

See also: [`@less`](@ref), [`@which`](@ref).
"""
:@edit

"""
    @code_typed

Evaluates the arguments to the function or macro call, determines their types, and calls
[`code_typed`](@ref) on the resulting expression. Use the optional argument `optimize` with

    @code_typed optimize=true foo(x)

to control whether additional optimizations, such as inlining, are also applied.
"""
:@code_typed

"""
    @code_lowered

Evaluates the arguments to the function or macro call, determines their types, and calls
[`code_lowered`](@ref) on the resulting expression.
"""
:@code_lowered

"""
    @code_warntype

Evaluates the arguments to the function or macro call, determines their types, and calls
[`code_warntype`](@ref) on the resulting expression.
"""
:@code_warntype

"""
    @code_llvm

Evaluates the arguments to the function or macro call, determines their types, and calls
[`code_llvm`](@ref) on the resulting expression.
Set the optional keyword arguments `raw`, `dump_module`, `debuginfo`, `optimize`
by putting them and their value before the function call, like this:

    @code_llvm raw=true dump_module=true debuginfo=:default f(x)
    @code_llvm optimize=false f(x)

`optimize` controls whether additional optimizations, such as inlining, are also applied.
`raw` makes all metadata and dbg.* calls visible.
`debuginfo` may be one of `:source` (default) or `:none`,  to specify the verbosity of code comments.
`dump_module` prints the entire module that encapsulates the function.
"""
:@code_llvm

"""
    @code_native

Evaluates the arguments to the function or macro call, determines their types, and calls
[`code_native`](@ref) on the resulting expression.

Set any of the optional keyword arguments `syntax`, `debuginfo`, `binary` or `dump_module`
by putting it before the function call, like this:

    @code_native syntax=:intel debuginfo=:default binary=true dump_module=false f(x)

* Set assembly syntax by setting `syntax` to `:att` (default) for AT&T syntax or `:intel` for Intel syntax.
* Specify verbosity of code comments by setting `debuginfo` to `:source` (default) or `:none`.
* If `binary` is `true`, also print the binary machine code for each instruction precedented by an abbreviated address.
* If `dump_module` is `false`, do not print metadata such as rodata or directives.

See also: [`code_native`](@ref), [`@code_llvm`](@ref), [`@code_typed`](@ref) and [`@code_lowered`](@ref)
"""
:@code_native

"""
    @time_imports

A macro to execute an expression and produce a report of any time spent importing packages and their
dependencies. Any compilation time will be reported as a percentage, and how much of which was recompilation, if any.

If a package's dependencies have already been imported either globally or by another dependency they will
not appear under that package and the package will accurately report a faster load time than if it were to
be loaded in isolation.

!!! compat "Julia 1.9"
    Reporting of any compilation and recompilation time was added in Julia 1.9

```julia-repl
julia> @time_imports using CSV
      0.4 ms    ┌ IteratorInterfaceExtensions
     11.1 ms  ┌ TableTraits 84.88% compilation time
    145.4 ms  ┌ SentinelArrays 66.73% compilation time
     42.3 ms  ┌ Parsers 19.66% compilation time
      4.1 ms  ┌ Compat
      8.2 ms  ┌ OrderedCollections
      1.4 ms    ┌ Zlib_jll
      2.3 ms    ┌ TranscodingStreams
      6.1 ms  ┌ CodecZlib
      0.3 ms  ┌ DataValueInterfaces
     15.2 ms  ┌ FilePathsBase 30.06% compilation time
      9.3 ms    ┌ InlineStrings
      1.5 ms    ┌ DataAPI
     31.4 ms  ┌ WeakRefStrings
     14.8 ms  ┌ Tables
     24.2 ms  ┌ PooledArrays
   2002.4 ms  CSV 83.49% compilation time
```

!!! note
    During the load process a package sequentially imports where necessary all of its dependencies, not just
    its direct dependencies. That is also true for the dependencies themselves so nested importing will likely
    occur, but not always. Therefore the nesting shown in this output report is not equivalent to the dependency
    tree, but does indicate where import time has accumulated.

"""
:@time_imports
