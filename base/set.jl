# This file is a part of Julia. License is MIT: https://julialang.org/license

eltype(::Type{<:AbstractSet{T}}) where {T} = @isdefined(T) ? T : Any

struct Set{T} <: AbstractSet{T}
    dict::Dict{T,Nothing}

    Set{T}() where {T} = new(Dict{T,Nothing}())
    Set{T}(s::Set{T}) where {T} = new(Dict{T,Nothing}(s.dict))
end

Set{T}(itr) where {T} = union!(Set{T}(), itr)
Set() = Set{Any}()


"""
    Set([itr])

Construct a [`Set`](@ref) of the values generated by the given iterable object, or an
empty set. Should be used instead of [`BitSet`](@ref) for sparse integer sets, or
for sets of arbitrary objects.
"""
Set(itr) = Set{eltype(itr)}(itr)
function Set(g::Generator)
    T = @default_eltype(g)
    (isconcretetype(T) || T === Union{}) || return grow_to!(Set{T}(), g)
    return Set{T}(g)
end

empty(s::AbstractSet{T}, ::Type{U}=T) where {T,U} = Set{U}()

# return an empty set with eltype T, which is mutable (can be grown)
# by default, a Set is returned
emptymutable(s::AbstractSet{T}, ::Type{U}=T) where {T,U} = Set{U}()

_similar_for(c::AbstractSet, T, itr, isz) = empty(c, T)

function show(io::IO, s::Set)
    print(io, "Set(")
    show_vector(io, s)
    print(io, ')')
end

isempty(s::Set) = isempty(s.dict)
length(s::Set)  = length(s.dict)
in(x, s::Set) = haskey(s.dict, x)
push!(s::Set, x) = (s.dict[x] = nothing; s)
pop!(s::Set, x) = (pop!(s.dict, x); x)
pop!(s::Set, x, deflt) = x in s ? pop!(s, x) : deflt

function pop!(s::Set)
    isempty(s) && throw(ArgumentError("set must be non-empty"))
    idx = start(s.dict)
    val = s.dict.keys[idx]
    _delete!(s.dict, idx)
    val
end

delete!(s::Set, x) = (delete!(s.dict, x); s)

copy(s::Set) = copymutable(s)

# Set is the default mutable fall-back
copymutable(s::AbstractSet{T}) where {T} = Set{T}(s)

sizehint!(s::Set, newsz) = (sizehint!(s.dict, newsz); s)
empty!(s::Set) = (empty!(s.dict); s)
rehash!(s::Set) = (rehash!(s.dict); s)

start(s::Set)       = start(s.dict)
done(s::Set, state) = done(s.dict, state)
# NOTE: manually optimized to take advantage of Dict representation
next(s::Set, i)     = (s.dict.keys[i], skip_deleted(s.dict, i+1))

"""
    union(s, itrs...)
    ∪(s, itrs...)

Construct the union of sets. Maintain order with arrays.

# Examples
```jldoctest
julia> union([1, 2], [3, 4])
4-element Array{Int64,1}:
 1
 2
 3
 4

julia> union([1, 2], [2, 4])
3-element Array{Int64,1}:
 1
 2
 4

julia> union([4, 2], 1:2)
3-element Array{Int64,1}:
 4
 2
 1

julia> union(Set([1, 2]), 2:3)
Set([2, 3, 1])
```
"""
function union end

_in(itr) = x -> x in itr

union(s, sets...) = union!(emptymutable(s, promote_eltype(s, sets...)), s, sets...)
union(s::AbstractSet) = copy(s)

const ∪ = union

"""
    union!(s::Union{AbstractSet,AbstractVector}, itrs...)

Construct the union of passed in sets and overwrite `s` with the result.
Maintain order with arrays.

# Examples
```jldoctest
julia> a = Set([1, 3, 4, 5]);

julia> union!(a, 1:2:8);

julia> a
Set([7, 4, 3, 5, 1])
```
"""
union!(s::AbstractSet, sets...) = foldl(union!, s, sets)

# default generic 2-args implementation with push!
union!(s::AbstractSet, itr) = foldl(push!, s, itr)

function union!(s::Set{T}, itr) where T
    haslength(itr) && sizehint!(s, length(itr))
    for x=itr
        push!(s, x)
        length(s) == max_values(T) && break
    end
    s
end


"""
    intersect(s, itrs...)
    ∩(s, itrs...)

Construct the intersection of sets.
Maintain order with arrays.

# Examples
```jldoctest
julia> intersect([1, 2, 3], [3, 4, 5])
1-element Array{Int64,1}:
 3

julia> intersect([1, 4, 4, 5, 6], [4, 6, 6, 7, 8])
2-element Array{Int64,1}:
 4
 6

julia> intersect(Set([1, 2]), BitSet([2, 3]))
Set([2])
```
"""
intersect(s::AbstractSet, itr, itrs...) = intersect!(intersect(s, itr), itrs...)
intersect(s) = union(s)
intersect(s::AbstractSet, itr) = mapfilter(_in(s), push!, itr, emptymutable(s))

const ∩ = intersect

"""
    intersect!(s::Union{AbstractSet,AbstractVector}, itrs...)

Intersect all passed in sets and overwrite `s` with the result.
Maintain order with arrays.
"""
intersect!(s::AbstractSet, itrs...) = foldl(intersect!, s, itrs)
intersect!(s::AbstractSet, s2::AbstractSet) = filter!(_in(s2), s)
intersect!(s::AbstractSet, itr) = intersect!(s, union!(emptymutable(s), itr))

"""
    setdiff(s, itrs...)

Construct the set of elements in `s` but not in any of the iterables in `itrs`.
Maintain order with arrays.

# Examples
```jldoctest
julia> setdiff([1,2,3], [3,4,5])
2-element Array{Int64,1}:
 1
 2
```
"""
setdiff(s::AbstractSet, itrs...) = setdiff!(copymutable(s), itrs...)
setdiff(s) = union(s)

"""
    setdiff!(s, itrs...)

Remove from set `s` (in-place) each element of each iterable from `itrs`.
Maintain order with arrays.

# Examples
```jldoctest
julia> a = Set([1, 3, 4, 5]);

julia> setdiff!(a, 1:2:6);

julia> a
Set([4])
```
"""
setdiff!(s::AbstractSet, itrs...) = foldl(setdiff!, s, itrs)
setdiff!(s::AbstractSet, itr) = foldl(delete!, s, itr)


"""
    symdiff(s, itrs...)

Construct the symmetric difference of elements in the passed in sets.
When `s` is not an `AbstractSet`, the order is maintained.
Note that in this case the multiplicity of elements matters.

# Examples
```jldoctest
julia> symdiff([1,2,3], [3,4,5], [4,5,6])
3-element Array{Int64,1}:
 1
 2
 6

julia> symdiff([1,2,1], [2, 1, 2])
2-element Array{Int64,1}:
 1
 2

julia> symdiff(unique([1,2,1]), unique([2, 1, 2]))
0-element Array{Int64,1}
```
"""
symdiff(s, sets...) = symdiff!(emptymutable(s, promote_eltype(s, sets...)), s, sets...)
symdiff(s) = symdiff!(copy(s))

"""
    symdiff!(s::Union{AbstractSet,AbstractVector}, itrs...)

Construct the symmetric difference of the passed in sets, and overwrite `s` with the result.
When `s` is an array, the order is maintained.
Note that in this case the multiplicity of elements matters.
"""
symdiff!(s::AbstractSet, itrs...) = foldl(symdiff!, s, itrs)

function symdiff!(s::AbstractSet, itr)
    for x in itr
        x in s ? delete!(s, x) : push!(s, x)
    end
    s
end

==(l::AbstractSet, r::AbstractSet) = length(l) == length(r) && l ⊆ r
# convenience functions for AbstractSet
# (if needed, only their synonyms ⊊ and ⊆ must be specialized)
<( l::AbstractSet, r::AbstractSet) = l ⊊ r
<=(l::AbstractSet, r::AbstractSet) = l ⊆ r

"""
    issubset(a, b)
    ⊆(a,b) -> Bool
    ⊈(a,b) -> Bool
    ⊊(a,b) -> Bool

Determine whether every element of `a` is also in `b`, using [`in`](@ref).

# Examples
```jldoctest
julia> issubset([1, 2], [1, 2, 3])
true

julia> issubset([1, 2, 3], [1, 2])
false
```
"""
function issubset(l, r)
    for elt in l
        if !in(elt, r)
            return false
        end
    end
    return true
end
# use the implementation below when it becoms as efficient
# issubset(l, r) = all(_in(r), l)

const ⊆ = issubset

"""
    issetequal(a, b)

Determine whether `a` and `b` have the same elements. Equivalent
to `a ⊆ b && b ⊆ a`.

# Examples
```jldoctest
julia> issetequal([1, 2], [1, 2, 3])
false

julia> issetequal([1, 2], [2, 1])
true
```
"""
issetequal(l, r) = length(l) == length(r) && l ⊆ r
issetequal(l::AbstractSet, r::AbstractSet) = l == r

⊊(l, r) = length(l) < length(r) && l ⊆ r
⊈(l, r) = !⊆(l, r)

⊇(l, r) = r ⊆ l
⊉(l, r) = r ⊈ l
⊋(l, r) = r ⊊ l

"""
    unique(itr)

Return an array containing only the unique elements of collection `itr`,
as determined by [`isequal`](@ref), in the order that the first of each
set of equivalent elements originally appears. The element type of the
input is preserved.

# Examples
```jldoctest
julia> unique([1, 2, 6, 2])
3-element Array{Int64,1}:
 1
 2
 6

julia> unique(Real[1, 1.0, 2])
2-element Array{Real,1}:
 1
 2
```
"""
function unique(itr)
    T = @default_eltype(itr)
    out = Vector{T}()
    seen = Set{T}()
    i = start(itr)
    if done(itr, i)
        return out
    end
    x, i = next(itr, i)
    if !isconcretetype(T) && IteratorEltype(itr) == EltypeUnknown()
        S = typeof(x)
        return _unique_from(itr, S[x], Set{S}((x,)), i)
    end
    push!(seen, x)
    push!(out, x)
    return unique_from(itr, out, seen, i)
end

_unique_from(itr, out, seen, i) = unique_from(itr, out, seen, i)
@inline function unique_from(itr, out::Vector{T}, seen, i) where T
    while !done(itr, i)
        x, i = next(itr, i)
        S = typeof(x)
        if !(S === T || S <: T)
            R = promote_typejoin(S, T)
            seenR = convert(Set{R}, seen)
            outR = convert(Vector{R}, out)
            if !in(x, seenR)
                push!(seenR, x)
                push!(outR, x)
            end
            return _unique_from(itr, outR, seenR, i)
        end
        if !in(x, seen)
            push!(seen, x)
            push!(out, x)
        end
    end
    return out
end

"""
    unique(f, itr)

Returns an array containing one value from `itr` for each unique value produced by `f`
applied to elements of `itr`.

# Examples
```jldoctest
julia> unique(x -> x^2, [1, -1, 3, -3, 4])
3-element Array{Int64,1}:
 1
 3
 4
```
"""
function unique(f::Callable, C)
    out = Vector{eltype(C)}()
    seen = Set()
    for x in C
        y = f(x)
        if !in(y, seen)
            push!(seen, y)
            push!(out, x)
        end
    end
    out
end

# If A is not grouped, then we will need to keep track of all of the elements that we have
# seen so far.
function _unique!(A::AbstractVector)
    seen = Set{eltype(A)}()
    idxs = eachindex(A)
    i = state = start(idxs)
    for x in A
        if x ∉ seen
            push!(seen, x)
            i, state = next(idxs, state)
            A[i] = x
        end
    end
    resize!(A, i - first(idxs) + 1)
end

# If A is grouped, so that each unique element is in a contiguous group, then we only
# need to keep track of one element at a time. We replace the elements of A with the
# unique elements that we see in the order that we see them. Once we have iterated
# through A, we resize A based on the number of unique elements that we see.
function _groupedunique!(A::AbstractVector)
    isempty(A) && return A
    idxs = eachindex(A)
    y = first(A)
    state = start(idxs)
    i, state = next(idxs, state)
    for x in A
        if !isequal(x, y)
            i, state = next(idxs, state)
            y = A[i] = x
        end
    end
    resize!(A, i - first(idxs) + 1)
end

"""
    unique!(A::AbstractVector)

Remove duplicate items as determined by [`isequal`](@ref), then return the modified `A`.
`unique!` will return the elements of `A` in the order that they occur. If you do not care
about the order of the returned data, then calling `(sort!(A); unique!(A))` will be much
more efficient as long as the elements of `A` can be sorted.

# Examples
```jldoctest
julia> unique!([1, 1, 1])
1-element Array{Int64,1}:
 1

julia> A = [7, 3, 2, 3, 7, 5];

julia> unique!(A)
4-element Array{Int64,1}:
 7
 3
 2
 5

julia> B = [7, 6, 42, 6, 7, 42];

julia> sort!(B);  # unique! is able to process sorted data much more efficiently.

julia> unique!(B)
3-element Array{Int64,1}:
  6
  7
 42
```
"""
function unique!(A::Union{AbstractVector{<:Real}, AbstractVector{<:AbstractString},
                          AbstractVector{<:Symbol}})
    if isempty(A)
        return A
    elseif issorted(A) || issorted(A, rev=true)
        return _groupedunique!(A)
    else
        return _unique!(A)
    end
end
# issorted fails for some element types, so the method above has to be restricted to
# elements with isless/< defined.
function unique!(A)
    if isempty(A)
        return A
    else
        return _unique!(A)
    end
end

"""
    allunique(itr) -> Bool

Return `true` if all values from `itr` are distinct when compared with [`isequal`](@ref).

# Examples
```jldoctest
julia> a = [1; 2; 3]
3-element Array{Int64,1}:
 1
 2
 3

julia> allunique([a, a])
false
```
"""
function allunique(C)
    seen = Set{eltype(C)}()
    for x in C
        if in(x, seen)
            return false
        else
            push!(seen, x)
        end
    end
    true
end

allunique(::Set) = true

allunique(r::AbstractRange{T}) where {T} = (step(r) != zero(T)) || (length(r) <= 1)

filter(pred, s::AbstractSet) = mapfilter(pred, push!, s, emptymutable(s))
filter!(f, s::Set) = unsafe_filter!(f, s)

# it must be safe to delete the current element while iterating over s:
unsafe_filter!(pred, s::AbstractSet) = mapfilter(!pred, delete!, s, s)

# TODO: delete mapfilter in favor of comprehensions/foldl/filter when competitive
function mapfilter(pred, f, itr, res)
    for x in itr
        pred(x) && f(res, x)
    end
    res
end

const hashs_seed = UInt === UInt64 ? 0x852ada37cfe8e0ce : 0xcfe8e0ce
function hash(s::AbstractSet, h::UInt)
    hv = hashs_seed
    for x in s
        hv ⊻= hash(x)
    end
    hash(hv, h)
end

convert(::Type{T}, s::T) where {T<:AbstractSet} = s
convert(::Type{T}, s::AbstractSet) where {T<:AbstractSet} = T(s)


## replace/replace! ##

function check_count(count::Integer)
    count < 0 && throw(DomainError(count, "`count` must not be negative (got $count)"))
    return min(count, typemax(Int)) % Int
end

# TODO: use copy!, which is currently unavailable from here since it is defined in Future
_copy_oftype(x, ::Type{T}) where {T} = copyto!(similar(x, T), x)
# TODO: use similar() once deprecation is removed and it preserves keys
_copy_oftype(x::AbstractDict, ::Type{T}) where {T} = merge!(empty(x, T), x)
_copy_oftype(x::AbstractSet, ::Type{T}) where {T} = union!(empty(x, T), x)

_copy_oftype(x::AbstractArray{T}, ::Type{T}) where {T} = copy(x)
_copy_oftype(x::AbstractDict{K,V}, ::Type{Pair{K,V}}) where {K,V} = copy(x)
_copy_oftype(x::AbstractSet{T}, ::Type{T}) where {T} = copy(x)

_similar_or_copy(x::Any) = similar(x)
_similar_or_copy(x::Any, ::Type{T}) where {T} = similar(x, T)
# Make a copy on construction since it is faster than inserting elements separately
_similar_or_copy(x::Union{AbstractDict,AbstractSet}) = copy(x)
_similar_or_copy(x::Union{AbstractDict,AbstractSet}, ::Type{T}) where {T} = _copy_oftype(x, T)

# to make replace/replace! work for a new container type Cont, only
# _replace!(new::Callable, res::Cont, A::Cont, count::Int)
# has to be implemented

"""
    replace!(A, old_new::Pair...; [count::Integer])

For each pair `old=>new` in `old_new`, replace all occurrences
of `old` in collection `A` by `new`.
Equality is determined using [`isequal`](@ref).
If `count` is specified, then replace at most `count` occurrences in total.
See also [`replace`](@ref replace(A, old_new::Pair...)).

# Examples
```jldoctest
julia> replace!([1, 2, 1, 3], 1=>0, 2=>4, count=2)
4-element Array{Int64,1}:
 0
 4
 1
 3

julia> replace!(Set([1, 2, 3]), 1=>0)
Set([0, 2, 3])
```
"""
replace!(A, old_new::Pair...; count::Integer=typemax(Int)) =
    replace_pairs!(A, A, check_count(count), old_new)

function replace_pairs!(res, A, count::Int, old_new::Tuple{Vararg{Pair}})
    @inline function new(x)
        for o_n in old_new
            isequal(first(o_n), x) && return last(o_n)
        end
        return x # no replace
    end
    _replace!(new, res, A, count)
end

"""
    replace!(pred::Function, A, new; [count::Integer])

Replace all occurrences `x` in collection `A` for which `pred(x)` is true
by `new`.

# Examples
```jldoctest
julia> A = [1, 2, 3, 1];

julia> replace!(isodd, A, 0, count=2)
4-element Array{Int64,1}:
 0
 2
 0
 1
```
"""
replace!(pred::Callable, A, new; count::Integer=typemax(Int)) =
    replace!(x -> ifelse(pred(x), new, x), A, count=check_count(count))

"""
    replace!(new::Function, A; [count::Integer])

Replace each element `x` in collection `A` by `new(x)`.
If `count` is specified, then replace at most `count` values in total
(replacements being defined as `new(x) !== x`).

# Examples
```jldoctest
julia> replace!(x -> isodd(x) ? 2x : x, [1, 2, 3, 4])
4-element Array{Int64,1}:
 2
 2
 6
 4

julia> replace!(Dict(1=>2, 3=>4)) do kv
           first(kv) < 3 ? first(kv)=>3 : kv
       end
Dict{Int64,Int64} with 2 entries:
  3 => 4
  1 => 3

julia> replace!(x->2x, Set([3, 6]))
Set([6, 12])
```
"""
replace!(new::Callable, A; count::Integer=typemax(Int)) =
    _replace!(new, A, A, check_count(count))

"""
    replace(A, old_new::Pair...; [count::Integer])

Return a copy of collection `A` where, for each pair `old=>new` in `old_new`,
all occurrences of `old` are replaced by `new`.
Equality is determined using [`isequal`](@ref).
If `count` is specified, then replace at most `count` occurrences in total.
See also [`replace!`](@ref).

# Examples
```jldoctest
julia> replace([1, 2, 1, 3], 1=>0, 2=>4, count=2)
4-element Array{Int64,1}:
 0
 4
 1
 3
```
"""
function replace(A, old_new::Pair...; count::Union{Integer,Nothing}=nothing)
    V = promote_valuetype(old_new...)
    if count isa Nothing
        T = promote_type(subtract_singletontype(eltype(A), old_new...), V)
        replace_pairs!(_similar_or_copy(A, T), A, typemax(Int), old_new)
    else
        U = promote_type(eltype(A), V)
        replace_pairs!(_similar_or_copy(A, U), A, check_count(count), old_new)
    end
end

promote_valuetype(x::Pair{K, V}) where {K, V} = V
promote_valuetype(x::Pair{K, V}, y::Pair...) where {K, V} =
    promote_type(V, promote_valuetype(y...))

# Subtract singleton types which are going to be replaced
@pure issingletontype(T::DataType) = isdefined(T, :instance)
issingletontype(::Type) = false
function subtract_singletontype(::Type{T}, x::Pair{K}) where {T, K}
    if issingletontype(K)
        Core.Compiler.typesubtract(T, K)
    else
        T
    end
end
subtract_singletontype(::Type{T}, x::Pair{K}, y::Pair...) where {T, K} =
    subtract_singletontype(subtract_singletontype(T, y...), x)

"""
    replace(pred::Function, A, new; [count::Integer])

Return a copy of collection `A` where all occurrences `x` for which
`pred(x)` is true are replaced by `new`.
If `count` is specified, then replace at most `count` occurrences in total.

# Examples
```jldoctest
julia> replace(isodd, [1, 2, 3, 1], 0, count=2)
4-element Array{Int64,1}:
 0
 2
 0
 1
```
"""
function replace(pred::Callable, A, new; count::Integer=typemax(Int))
    T = promote_type(eltype(A), typeof(new))
    _replace!(x -> ifelse(pred(x), new, x), _similar_or_copy(A, T), A, check_count(count))
end

"""
    replace(new::Function, A; [count::Integer])

Return a copy of `A` where each value `x` in `A` is replaced by `new(x)`
If `count` is specified, then replace at most `count` values in total
(replacements being defined as `new(x) !== x`).

# Examples
```jldoctest
julia> replace(x -> isodd(x) ? 2x : x, [1, 2, 3, 4])
4-element Array{Int64,1}:
 2
 2
 6
 4

julia> replace(Dict(1=>2, 3=>4)) do kv
           first(kv) < 3 ? first(kv)=>3 : kv
       end
Dict{Int64,Int64} with 2 entries:
  3 => 4
  1 => 3
```
"""
replace(new::Callable, A; count::Integer=typemax(Int)) =
    _replace!(new, _similar_or_copy(A), A, check_count(count))

# Handle ambiguities
replace!(a::Callable, b::Pair; count::Integer=-1) = throw(MethodError(replace!, (a, b)))
replace!(a::Callable, b::Pair, c::Pair; count::Integer=-1) = throw(MethodError(replace!, (a, b, c)))
replace(a::Callable, b::Pair; count::Integer=-1) = throw(MethodError(replace, (a, b)))
replace(a::Callable, b::Pair, c::Pair; count::Integer=-1) = throw(MethodError(replace, (a, b, c)))
replace(a::AbstractString, b::Pair, c::Pair) = throw(MethodError(replace, (a, b, c)))

### replace! for AbstractDict/AbstractSet

askey(k, ::AbstractDict) = k.first
askey(k, ::AbstractSet) = k

function _replace!(new::Callable, res::T, A::T,
                   count::Int) where T<:Union{AbstractDict,AbstractSet}
    c = 0
    if res === A # cannot replace elements while iterating over A
        repl = Pair{eltype(A),eltype(A)}[]
        for x in A
            y = new(x)
            if x !== y
                push!(repl, x => y)
                c += 1
            end
            c == count && break
        end
        for oldnew in repl
            pop!(res, askey(first(oldnew), res))
        end
        for oldnew in repl
            push!(res, last(oldnew))
        end
    else
        for x in A
            y = new(x)
            if x !== y
                pop!(res, askey(x, res))
                push!(res, y)
                c += 1
            end
            c == count && break
        end
    end
    res
end

### replace! for AbstractArray

function _replace!(new::Callable, res::AbstractArray, A::AbstractArray, count::Int)
    c = 0
    if count >= length(A) # simpler loop allows for SIMD
        for i in eachindex(A)
            @inbounds Ai = A[i]
            y = new(Ai)
            @inbounds res[i] = y
        end
    else
        for i in eachindex(A)
            @inbounds Ai = A[i]
            if c < count
                y = new(Ai)
                @inbounds res[i] = y
                c += (Ai !== y)
            else
                @inbounds res[i] = Ai
            end
        end
    end
    res
end
