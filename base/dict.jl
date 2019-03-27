# This file is a part of Julia. License is MIT: https://julialang.org/license

function _truncate_at_width_or_chars(str, width, chars="", truncmark="…")
    truncwidth = textwidth(truncmark)
    (width <= 0 || width < truncwidth) && return ""

    wid = truncidx = lastidx = 0
    for (idx, c) in pairs(str)
        lastidx = idx
        wid += textwidth(c)
        wid >= width - truncwidth && truncidx == 0 && (truncidx = lastidx)
        (wid >= width || c in chars) && break
    end

    lastidx != 0 && str[lastidx] in chars && (lastidx = prevind(str, lastidx))
    truncidx == 0 && (truncidx = lastidx)
    if lastidx < lastindex(str)
        return String(SubString(str, 1, truncidx) * truncmark)
    else
        return String(str)
    end
end

function show(io::IO, t::AbstractDict{K,V}) where V where K
    recur_io = IOContext(io, :SHOWN_SET => t,
                             :typeinfo => eltype(t))

    limit::Bool = get(io, :limit, false)
    # show in a Julia-syntax-like form: Dict(k=>v, ...)
    print(io, typeinfo_prefix(io, t))
    print(io, '(')
    if !isempty(t) && !show_circular(io, t)
        first = true
        n = 0
        for pair in t
            first || print(io, ',')
            first = false
            show(recur_io, pair)
            n+=1
            limit && n >= 10 && (print(io, "…"); break)
        end
    end
    print(io, ')')
end

# Dict


"""
    Dict([itr])

`Dict{K,V}()` constructs a hash table with keys of type `K` and values of type `V`.
Keys are compared with [`isequal`](@ref) and hashed with [`hash`](@ref).

Given a single iterable argument, constructs a [`Dict`](@ref) whose key-value pairs
are taken from 2-tuples `(key,value)` generated by the argument.

# Examples
```jldoctest
julia> Dict([("A", 1), ("B", 2)])
Dict{String,Int64} with 2 entries:
  "B" => 2
  "A" => 1
```

Alternatively, a sequence of pair arguments may be passed.

```jldoctest
julia> Dict("A"=>1, "B"=>2)
Dict{String,Int64} with 2 entries:
  "B" => 2
  "A" => 1
```
"""
mutable struct Dict{K,V} <: AbstractDict{K,V}
    slots::Array{UInt8,1}
    keys::Array{K,1}
    vals::Array{V,1}
    ndel::Int
    count::Int
    age::UInt
    idxfloor::Int  # an index <= the indices of all used slots
    maxprobe::Int

    function Dict{K,V}() where V where K
        n = 8 #count = 0, 1, 2 most common for small long-term storage dicts
        new(zeros(UInt8,n), Vector{K}(undef, n), Vector{V}(undef, n), 0, 0, 0, 1, 0)
    end
    function Dict{K,V}(d::Dict{K,V}) where V where K
        new(copy(d.slots), copy(d.keys), copy(d.vals), d.ndel, d.count, d.age,
            d.idxfloor, d.maxprobe)
    end
    function Dict{K, V}(slots, keys, vals, ndel, count, age, idxfloor, maxprobe) where {K, V}
        new(slots, keys, vals, ndel, count, age, idxfloor, maxprobe)
    end
end
function Dict{K,V}(kv) where V where K
    h = Dict{K,V}()
    for (k,v) in kv
        h[k] = v
    end
    return h
end
Dict{K,V}(p::Pair) where {K,V} = setindex!(Dict{K,V}(), p.second, p.first)
function Dict{K,V}(ps::Pair...) where V where K
    h = Dict{K,V}()
    sizehint!(h, length(ps))
    for p in ps
        h[p.first] = p.second
    end
    return h
end
# Note the constructors of WeakKeyDict mirror these here, keep in sync.
Dict() = Dict{Any,Any}()
Dict(kv::Tuple{}) = Dict()
copy(d::Dict) = Dict(d)

const AnyDict = Dict{Any,Any}

Dict(ps::Pair{K,V}...) where {K,V} = Dict{K,V}(ps)
Dict(ps::Pair...)                  = Dict(ps)

function Dict(kv)
    try
        dict_with_eltype((K, V) -> Dict{K, V}, kv, eltype(kv))
    catch
        if !isiterable(typeof(kv)) || !all(x->isa(x,Union{Tuple,Pair}),kv)
            throw(ArgumentError("Dict(kv): kv needs to be an iterator of tuples or pairs"))
        else
            rethrow()
        end
    end
end

function grow_to!(dest::AbstractDict{K, V}, itr) where V where K
    y = iterate(itr)
    y === nothing && return dest
    ((k,v), st) = y
    dest2 = empty(dest, typeof(k), typeof(v))
    dest2[k] = v
    grow_to!(dest2, itr, st)
end

# this is a special case due to (1) allowing both Pairs and Tuples as elements,
# and (2) Pair being invariant. a bit annoying.
function grow_to!(dest::AbstractDict{K,V}, itr, st) where V where K
    y = iterate(itr, st)
    while y !== nothing
        (k,v), st = y
        if isa(k,K) && isa(v,V)
            dest[k] = v
        else
            new = empty(dest, promote_typejoin(K,typeof(k)), promote_typejoin(V,typeof(v)))
            merge!(new, dest)
            new[k] = v
            return grow_to!(new, itr, st)
        end
        y = iterate(itr, st)
    end
    return dest
end

empty(a::AbstractDict, ::Type{K}, ::Type{V}) where {K, V} = Dict{K, V}()

hashindex(key, sz) = (((hash(key)%Int) & (sz-1)) + 1)::Int

@propagate_inbounds isslotempty(h::Dict, i::Int) = h.slots[i] == 0x00
@propagate_inbounds isslotfilled(h::Dict, i::Int) = h.slots[i] == 0x01
@propagate_inbounds isslotmissing(h::Dict, i::Int) = h.slots[i] == 0x02

#todo: new functions for size computations. Split off logic from rehash!.

function rehash!(h::Dict{K,V}, newsz = length(h.keys)) where V where K
    olds = h.slots
    oldk = h.keys
    oldv = h.vals
    sz = length(olds)
    newsz = _tablesz(newsz)
    h.age += 1 + (1<<32)
    h.idxfloor = 1
    if h.count == 0
        resize!(h.slots, newsz)
        fill!(h.slots, 0)
        resize!(h.keys, newsz)
        resize!(h.vals, newsz)
        h.ndel = 0
        return h
        #todo: sizehint?
    end

    slots = zeros(UInt8,newsz)
    keys = Vector{K}(undef, newsz)
    vals = Vector{V}(undef, newsz)
    age0 = h.age
    count = 0
    maxprobe = 0

    for i = 1:sz
        @inbounds if olds[i] == 0x1
            k = oldk[i]
            v = oldv[i]
            index0 = index = hashindex(k, newsz)
            while slots[index] != 0
                index = (index & (newsz-1)) + 1
            end
            probe = (index - index0) & (newsz-1)
            probe > maxprobe && (maxprobe = probe)
            slots[index] = 0x01
            keys[index] = k
            vals[index] = v
            count += 1

            if h.age != age0
                # if `h` is changed by a finalizer, retry
                return rehash!(h, newsz)
            end
        end
    end

    h.slots = slots
    h.keys = keys
    h.vals = vals
    h.count = count
    h.ndel = 0
    h.maxprobe = maxprobe
    @assert h.age == age0

    return h
end

function sizehint!(d::Dict{T}, newsz) where T
    #todo: proper growth and regenerate logic
    #we can shrink without problems, below comments outdated
    oldsz = length(d.slots)
    if newsz <= oldsz
        # todo: shrink
        # be careful: rehash!() assumes everything fits. it was only designed
        # for growing.
        return d
    end
    # grow at least 25%
    newsz = min(max(newsz, (oldsz*5)>>2),
                max_values(T))
    rehash!(d, newsz)
end

"""
    empty!(collection) -> collection

Remove all elements from a `collection`.

# Examples
```jldoctest
julia> A = Dict("a" => 1, "b" => 2)
Dict{String,Int64} with 2 entries:
  "b" => 2
  "a" => 1

julia> empty!(A);

julia> A
Dict{String,Int64} with 0 entries
```
"""
function empty!(h::Dict{K,V}) where V where K
    fill!(h.slots, 0x0)
    sz = length(h.slots)
    empty!(h.keys)
    empty!(h.vals)
    resize!(h.keys, sz)
    resize!(h.vals, sz)
    h.ndel = 0
    h.count = 0
    h.age += 1
    h.idxfloor = 1
    return h
    #todo: This should shrink the dict? Also sizehint the buffers?
end

# get the index where a key is stored, or -1 if not present
@inline function ht_keyindex(h::Dict{K,V}, key) where V where K
    sz = length(h.keys)
    iter = 0
    maxprobe = h.maxprobe
    index = hashindex(key, sz)
    keys = h.keys

    @inbounds while true
        if isslotempty(h,index)
            break
        end
        if !isslotmissing(h,index) && (key === keys[index] || isequal(key,keys[index]))
            return index
        end

        index = (index & (sz-1)) + 1
        iter += 1
        iter > maxprobe && break
    end
    return -1
end

# get the index where a key is stored, or -pos if not present
#adjusts maxprobe
@inline function ht_keyindex2!(h::Dict{K,V}, key) where V where K
    age0 = h.age
    sz = length(h.keys)
    iter = 0
    maxprobe = h.maxprobe
    index = hashindex(key, sz)
    avail = 0
    keys = h.keys

    @inbounds while true
        if isslotempty(h,index)
            if avail < 0
                return avail
            end
            return -index
        end

        if isslotmissing(h,index)
            if avail == 0
                # found an available slot, but need to keep scanning
                # in case "key" already exists in a later collided slot.
                avail = -index
            end
        elseif key === keys[index] || isequal(key, keys[index])
            return index
        end

        index = (index & (sz-1)) + 1
        iter += 1
        iter > maxprobe && break
    end

    avail < 0 && return avail

    # Check if key is not present, may need to keep searching to find slot
    @inbounds while true
        if !isslotfilled(h,index)
            h.maxprobe = iter
            return -index
        end
        index = (index & (sz-1)) + 1
        iter += 1
    end
end

@propagate_inbounds function _setindex!(h::Dict, v, key, index)
    h.ndel -= (h.slots[index]==0x02)
    h.slots[index] = 0x2
    h.keys[index] = key
    h.vals[index] = v
    h.count += 1
    h.age += 1
    if index < h.idxfloor
        h.idxfloor = index
    end

    sz = length(h.keys)
    # Rehash now if necessary
    if h.ndel >= ((3*sz)>>2) || h.count*3 > sz*2
        # > 3/4 deleted or > 2/3 full
        rehash!(h, h.count > 64000 ? h.count*2 : h.count*4)
    end
    #todo: proper growth and regenerate logic (regenerate: too many deleted slots)
end

function setindex!(h::Dict{K,V}, v0, key0) where V where K
    key = convert(K, key0)
    if !isequal(key, key0)
        throw(ArgumentError("$(limitrepr(key0)) is not a valid key for type $K"))
    end
    setindex!(h, v0, key)
end

function setindex!(h::Dict{K,V}, v0, key::K) where V where K
    v = convert(V, v0)
    index = ht_keyindex2!(h, key)

    if index > 0
        h.age += 1
        @inbounds h.keys[index] = key
        @inbounds h.vals[index] = v
    else
        @inbounds _setindex!(h, v, key, -index)
    end

    return h
end

"""
    get!(collection, key, default)

Return the value stored for the given key, or if no mapping for the key is present, store
`key => default`, and return `default`.

# Examples
```jldoctest
julia> d = Dict("a"=>1, "b"=>2, "c"=>3);

julia> get!(d, "a", 5)
1

julia> get!(d, "d", 4)
4

julia> d
Dict{String,Int64} with 4 entries:
  "c" => 3
  "b" => 2
  "a" => 1
  "d" => 4
```
"""
get!(collection, key, default)

get!(h::Dict{K,V}, key0, default) where {K,V} = get!(()->default, h, key0)

"""
    get!(f::Function, collection, key)

Return the value stored for the given key, or if no mapping for the key is present, store
`key => f()`, and return `f()`.

This is intended to be called using `do` block syntax:
```julia
get!(dict, key) do
    # default value calculated here
    time()
end
```
"""
get!(f::Function, collection, key)

function get!(default::Callable, h::Dict{K,V}, key0) where V where K
    key = convert(K, key0)
    if !isequal(key, key0)
        throw(ArgumentError("$(limitrepr(key0)) is not a valid key for type $K"))
    end
    return get!(default, h, key)
end

function get!(default::Callable, h::Dict{K,V}, key::K) where V where K
    index = ht_keyindex2!(h, key)

    index > 0 && return h.vals[index]

    age0 = h.age
    v = convert(V, default())
    if h.age != age0
        index = ht_keyindex2!(h, key)
    end
    if index > 0
        h.age += 1
        @inbounds h.keys[index] = key
        @inbounds h.vals[index] = v
    else
        @inbounds _setindex!(h, v, key, -index)
    end
    return v
end

# NOTE: this macro is trivial, and should
#       therefore not be exported as-is: it's for internal use only.
macro get!(h, key0, default)
    return quote
        get!(()->$(esc(default)), $(esc(h)), $(esc(key0)))
    end
end


function getindex(h::Dict{K,V}, key) where V where K
    index = ht_keyindex(h, key)
    @inbounds return (index < 0) ? throw(KeyError(key)) : h.vals[index]::V
end

"""
    get(collection, key, default)

Return the value stored for the given key, or the given default value if no mapping for the
key is present.

# Examples
```jldoctest
julia> d = Dict("a"=>1, "b"=>2);

julia> get(d, "a", 3)
1

julia> get(d, "c", 3)
3
```
"""
get(collection, key, default)

function get(h::Dict{K,V}, key, default) where V where K
    index = ht_keyindex(h, key)
    @inbounds return (index < 0) ? default : h.vals[index]::V
end

"""
    get(f::Function, collection, key)

Return the value stored for the given key, or if no mapping for the key is present, return
`f()`.  Use [`get!`](@ref) to also store the default value in the dictionary.

This is intended to be called using `do` block syntax

```julia
get(dict, key) do
    # default value calculated here
    time()
end
```
"""
get(::Function, collection, key)

function get(default::Callable, h::Dict{K,V}, key) where V where K
    index = ht_keyindex(h, key)
    @inbounds return (index < 0) ? default() : h.vals[index]::V
end

"""
    haskey(collection, key) -> Bool

Determine whether a collection has a mapping for a given `key`.

# Examples
```jldoctest
julia> D = Dict('a'=>2, 'b'=>3)
Dict{Char,Int64} with 2 entries:
  'a' => 2
  'b' => 3

julia> haskey(D, 'a')
true

julia> haskey(D, 'c')
false
```
"""
haskey(h::Dict, key) = (ht_keyindex(h, key) >= 0)
in(key, v::KeySet{<:Any, <:Dict}) = (ht_keyindex(v.dict, key) >= 0)

"""
    getkey(collection, key, default)

Return the key matching argument `key` if one exists in `collection`, otherwise return `default`.

# Examples
```jldoctest
julia> D = Dict('a'=>2, 'b'=>3)
Dict{Char,Int64} with 2 entries:
  'a' => 2
  'b' => 3

julia> getkey(D, 'a', 1)
'a': ASCII/Unicode U+0061 (category Ll: Letter, lowercase)

julia> getkey(D, 'd', 'a')
'a': ASCII/Unicode U+0061 (category Ll: Letter, lowercase)
```
"""
function getkey(h::Dict{K,V}, key, default) where V where K
    index = ht_keyindex(h, key)
    @inbounds return (index<0) ? default : h.keys[index]::K
end

function _pop!(h::Dict, index)
    @inbounds val = h.vals[index]
    _delete_clean!(h, index)
    return val
end

function pop!(h::Dict, key)
    index = ht_keyindex(h, key)
    return index > 0 ? _pop!(h, index) : throw(KeyError(key))
    #todo: proper shrink logic
end

"""
    pop!(collection, key[, default])

Delete and return the mapping for `key` if it exists in `collection`, otherwise return
`default`, or throw an error if `default` is not specified.

# Examples
```jldoctest
julia> d = Dict("a"=>1, "b"=>2, "c"=>3);

julia> pop!(d, "a")
1

julia> pop!(d, "d")
ERROR: KeyError: key "d" not found
Stacktrace:
[...]

julia> pop!(d, "e", 4)
4
```
"""
pop!(collection, key, default)

function pop!(h::Dict, key, default)
    index = ht_keyindex(h, key)
    return index > 0 ? _pop!(h, index) : default
end

function pop!(h::Dict)
    isempty(h) && throw(ArgumentError("dict must be non-empty"))
    idx = skip_deleted_floor!(h)
    @inbounds key = h.keys[idx]
    @inbounds val = h.vals[idx]
    _delete!(h, idx)
    key => val
end

@inline function _delete_clean!(h::Dict{K,V}, index) where {K,V}
    isbitstype(K) || isbitsunion(K) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), h.keys, index-1)
    isbitstype(V) || isbitsunion(V) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), h.vals, index-1)
    off = 3
    if (index-off -1)%UInt <= length(h.slots)-8
        p = convert(Ptr{UInt64}, pointer(h.slots, index-off))
        c = xor(ltoh(unsafe_load(p)), 0x0000000000000003<<(off*8))
        del =  c & 0x0202020202020202
        nonempty = del | ( (c & 0x0101010101010101)<<1 )
        remdel = del & ( (~nonempty) >>8 )
        remdel |= del & (remdel>>8)
        remdel |= del & (remdel>>8)
        remdel |= del & (remdel>>8)
        unsafe_store!(p, htol(xor(c, remdel)))
        h.count -= 1
        h.age += 1
        h.ndel += 1 - count_ones(remdel)
    else
        @inbounds h.slots[index] = 0x02
        idx = (index<=off? 1: length(h.slots)-7)
        p = convert(Ptr{UInt64}, pointer(h.slots, idx))
        c = ltoh(unsafe_load(p))
        del =  c & 0x0202020202020202
        nonempty = del | ( (c & 0x0101010101010101)<<1 )
        remdel = del & ( (~nonempty) >>8 )
        remdel |= del & (remdel>>8)
        remdel |= del & (remdel>>8)
        remdel |= del & (remdel>>8)
        unsafe_store!(p, htol(xor(c, remdel)))
        h.count -= 1
        h.age += 1
        h.ndel += 1 - count_ones(remdel)
    end
    return h
end

function _delete!(h::Dict{K,V}, index) where {K,V}
    @inbounds h.slots[index] = 0x2
    isbitstype(K) || isbitsunion(K) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), h.keys, index-1)
    isbitstype(V) || isbitsunion(V) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), h.vals, index-1)
    h.ndel += 1
    h.count -= 1
    h.age += 1
    return h
end

"""
    delete!(collection, key)

Delete the mapping for the given key in a collection, and return the collection.

# Examples
```jldoctest
julia> d = Dict("a"=>1, "b"=>2)
Dict{String,Int64} with 2 entries:
  "b" => 2
  "a" => 1

julia> delete!(d, "b")
Dict{String,Int64} with 1 entry:
  "a" => 1
```
"""
delete!(collection, key)

function delete!(h::Dict, key)
    index = ht_keyindex(h, key)
    if index > 0
        _delete_clean!(h, index)
    end
    return h
    #todo: proper shrink logic    
end

function skip_deleted(h::Dict, i)
    L = length(h.slots)
    @inbounds while i<=L && !isslotfilled(h,i)
        i += 1
    end
    return i
end
function skip_deleted_floor!(h::Dict)
    idx = skip_deleted(h, h.idxfloor)
    h.idxfloor = idx
    idx
end

@inline function _iterate(h::Dict)
    isempty(h) && return nothing #always length(h.slots) >= 16
    return _iterate(h, (1, ltoh(unsafe_load(convert(Ptr{UInt64}, pointer(h.slots)),1)) & 0x0101010101010101))
end

@inline function _iterate(h::Dict, s)
    i,c = s
    while c == 0
        i % UInt >= (length(h.slots)>>3) && return nothing
        i += 1
        c = ltoh(unsafe_load(convert(Ptr{UInt64}, pointer(h.slots)),i)) & 0x0101010101010101
    end
    idx = 1 + (i-1)<<3 + trailing_zeros(c)>>3

    return  idx, (i, _blsr(c))
end

function iterate(h::Dict{K,V}) where {K,V}
    isempty(h) && return nothing
    s = _iterate(h)
    s === nothing && return nothing
    i, state = s
    @inbounds return Pair{K,V}(h.keys[i], h.vals[i]), state
end

function iterate(h::Dict{K,V}, state) where {K,V}
    s = _iterate(h, state)
    s === nothing && return nothing
    i, state = s
    @inbounds return Pair{K,V}(h.keys[i], h.vals[i]), state
end

isempty(t::Dict) = (t.count == 0)
length(t::Dict) = t.count

@propagate_inbounds function iterate(v::Union{KeySet{<:Any, <:Dict}, ValueIterator{<:Dict}})
    isempty(v.dict) && return nothing
    is = _iterate(v.dict)
    is === nothing && return nothing
    i,s = is
    (v isa KeySet ? v.dict.keys[i] : v.dict.vals[i], s)
end

@propagate_inbounds function iterate(v::Union{KeySet{<:Any, <:Dict}, ValueIterator{<:Dict}}, s)
    is = _iterate(v.dict, s)
    is === nothing && return nothing
    i,s = is
    (v isa KeySet ? v.dict.keys[i] : v.dict.vals[i], s)
end

function filter!(pred, h::Dict{K,V}) where {K,V}
    isempty(h) && return h
    is = _iterate(h)
    @inbounds while is !== nothing
        i, state = is
        if !pred(Pair{K,V}(h.keys[i], h.vals[i]))
            _delete!(h, i)
        end
        is = _iterate(h, state)
    end
    #todo: clean up deleted slots, maybe shrink
    return h
end

function map!(f, iter::ValueIterator{<:Dict})
    dict = iter.dict
    vals = dict.vals
    # @inbounds is here so the it gets propigated to isslotfiled
    @inbounds for i = dict.idxfloor:lastindex(vals)
        if isslotfilled(dict, i)
            vals[i] = f(vals[i])
        end
    end
    return iter
end

struct ImmutableDict{K,V} <: AbstractDict{K,V}
    parent::ImmutableDict{K,V}
    key::K
    value::V
    ImmutableDict{K,V}() where {K,V} = new() # represents an empty dictionary
    ImmutableDict{K,V}(key, value) where {K,V} = (empty = new(); new(empty, key, value))
    ImmutableDict{K,V}(parent::ImmutableDict, key, value) where {K,V} = new(parent, key, value)
end

"""
    ImmutableDict

ImmutableDict is a Dictionary implemented as an immutable linked list,
which is optimal for small dictionaries that are constructed over many individual insertions
Note that it is not possible to remove a value, although it can be partially overridden and hidden
by inserting a new value with the same key

    ImmutableDict(KV::Pair)

Create a new entry in the Immutable Dictionary for the key => value pair

 - use `(key => value) in dict` to see if this particular combination is in the properties set
 - use `get(dict, key, default)` to retrieve the most recent value for a particular key

"""
ImmutableDict
ImmutableDict(KV::Pair{K,V}) where {K,V} = ImmutableDict{K,V}(KV[1], KV[2])
ImmutableDict(t::ImmutableDict{K,V}, KV::Pair) where {K,V} = ImmutableDict{K,V}(t, KV[1], KV[2])

function in(key_value::Pair, dict::ImmutableDict, valcmp=(==))
    key, value = key_value
    while isdefined(dict, :parent)
        if dict.key == key
            valcmp(value, dict.value) && return true
        end
        dict = dict.parent
    end
    return false
end

function haskey(dict::ImmutableDict, key)
    while isdefined(dict, :parent)
        dict.key == key && return true
        dict = dict.parent
    end
    return false
end

function getindex(dict::ImmutableDict, key)
    while isdefined(dict, :parent)
        dict.key == key && return dict.value
        dict = dict.parent
    end
    throw(KeyError(key))
end
function get(dict::ImmutableDict, key, default)
    while isdefined(dict, :parent)
        dict.key == key && return dict.value
        dict = dict.parent
    end
    return default
end

# this actually defines reverse iteration (e.g. it should not be used for merge/copy/filter type operations)
function iterate(d::ImmutableDict{K,V}, t=d) where {K, V}
    !isdefined(t, :parent) && return nothing
    (Pair{K,V}(t.key, t.value), t.parent)
end
length(t::ImmutableDict) = count(x->true, t)
isempty(t::ImmutableDict) = !isdefined(t, :parent)
empty(::ImmutableDict, ::Type{K}, ::Type{V}) where {K, V} = ImmutableDict{K,V}()

_similar_for(c::Dict, ::Type{Pair{K,V}}, itr, isz) where {K, V} = empty(c, K, V)
_similar_for(c::AbstractDict, ::Type{T}, itr, isz) where {T} =
    throw(ArgumentError("for AbstractDicts, similar requires an element type of Pair;\n  if calling map, consider a comprehension instead"))
