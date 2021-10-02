# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
Utilities for monitoring files and file descriptors for events.
"""
module FileWatching

export
    # one-shot API (returns results):
    watch_file, # efficient for small numbers of files
    watch_folder, # efficient for large numbers of files
    unwatch_folder,
    poll_file, # very inefficient alternative to above
    poll_fd, # very efficient, unrelated to above
    # Pidfile-based File Locking
    mkpidlock,
    tryopen_exclusive,
    open_exclusive,
    # continuous API (returns objects):
    FileMonitor,
    FolderMonitor,
    PollingFileWatcher,
    FDWatcher

import Base: @handle_as, wait, close, eventloop, notify_error, IOError,
    _sizeof_uv_poll, _sizeof_uv_fs_poll, _sizeof_uv_fs_event, _uv_hook_close, uv_error, _UVError,
    iolock_begin, iolock_end, associate_julia_struct, disassociate_julia_struct,
    preserve_handle, unpreserve_handle, isreadable, iswritable, |,
    UV_EEXIST, UV_ESRCH, Process
import Base.Filesystem: StatStruct, File, open, JL_O_CREAT, JL_O_RDWR, JL_O_RDONLY, JL_O_EXCL, samefile
if Sys.iswindows()
    import Base.WindowsRawSocket
end

# libuv file watching event flags
const UV_RENAME = 1
const UV_CHANGE = 2
struct FileEvent
    renamed::Bool
    changed::Bool
    timedout::Bool
    FileEvent(r::Bool, c::Bool, t::Bool) = new(r, c, t)
end
FileEvent() = FileEvent(false, false, true)
FileEvent(flags::Integer) = FileEvent((flags & UV_RENAME) != 0,
                                      (flags & UV_CHANGE) != 0,
                                      false)
|(a::FileEvent, b::FileEvent) =
    FileEvent(a.renamed | b.renamed,
              a.changed | b.changed,
              a.timedout | b.timedout)

struct FDEvent
    readable::Bool
    writable::Bool
    disconnect::Bool
    timedout::Bool
    FDEvent(r::Bool, w::Bool, d::Bool, t::Bool) = new(r, w, d, t)
end
# libuv file descriptor event flags
const UV_READABLE = 1
const UV_WRITABLE = 2
const UV_DISCONNECT = 4

isreadable(f::FDEvent) = f.readable
iswritable(f::FDEvent) = f.writable
FDEvent() = FDEvent(false, false, false, true)
FDEvent(flags::Integer) = FDEvent((flags & UV_READABLE) != 0,
                                  (flags & UV_WRITABLE) != 0,
                                  (flags & UV_DISCONNECT) != 0,
                                  false)
|(a::FDEvent, b::FDEvent) =
    FDEvent(a.readable | b.readable,
            a.writable | b.writable,
            a.disconnect | b.disconnect,
            a.timedout | b.timedout)

mutable struct FileMonitor
    handle::Ptr{Cvoid}
    file::String
    notify::Base.ThreadSynchronizer
    events::Int32
    active::Bool
    FileMonitor(file::AbstractString) = FileMonitor(String(file))
    function FileMonitor(file::String)
        handle = Libc.malloc(_sizeof_uv_fs_event)
        this = new(handle, file, Base.ThreadSynchronizer(), 0, false)
        associate_julia_struct(handle, this)
        iolock_begin()
        err = ccall(:uv_fs_event_init, Cint, (Ptr{Cvoid}, Ptr{Cvoid}), eventloop(), handle)
        if err != 0
            Libc.free(handle)
            throw(_UVError("FileMonitor", err))
        end
        iolock_end()
        finalizer(uvfinalize, this)
        return this
    end
end


mutable struct FolderMonitor
    handle::Ptr{Cvoid}
    notify::Channel{Any} # eltype = Union{Pair{String, FileEvent}, IOError}
    open::Bool
    FolderMonitor(folder::AbstractString) = FolderMonitor(String(folder))
    function FolderMonitor(folder::String)
        handle = Libc.malloc(_sizeof_uv_fs_event)
        this = new(handle, Channel(Inf), false)
        associate_julia_struct(handle, this)
        iolock_begin()
        err = ccall(:uv_fs_event_init, Cint, (Ptr{Cvoid}, Ptr{Cvoid}), eventloop(), handle)
        if err != 0
            Libc.free(handle)
            throw(_UVError("FolderMonitor", err))
        end
        this.open = true
        finalizer(uvfinalize, this)
        uv_error("FolderMonitor (start)",
                 ccall(:uv_fs_event_start, Int32, (Ptr{Cvoid}, Ptr{Cvoid}, Cstring, Int32),
                       handle, uv_jl_fseventscb_folder::Ptr{Cvoid}, folder, 0))
        iolock_end()
        return this
    end
end

mutable struct PollingFileWatcher
    handle::Ptr{Cvoid}
    file::String
    interval::UInt32
    notify::Base.ThreadSynchronizer
    active::Bool
    curr_error::Int32
    curr_stat::StatStruct
    PollingFileWatcher(file::AbstractString, interval::Float64=5.007) = PollingFileWatcher(String(file), interval)
    function PollingFileWatcher(file::String, interval::Float64=5.007) # same default as nodejs
        handle = Libc.malloc(_sizeof_uv_fs_poll)
        this = new(handle, file, round(UInt32, interval * 1000), Base.ThreadSynchronizer(), false, 0, StatStruct())
        associate_julia_struct(handle, this)
        iolock_begin()
        err = ccall(:uv_fs_poll_init, Int32, (Ptr{Cvoid}, Ptr{Cvoid}), eventloop(), handle)
        if err != 0
            Libc.free(handle)
            throw(_UVError("PollingFileWatcher", err))
        end
        finalizer(uvfinalize, this)
        iolock_end()
        return this
    end
end

mutable struct _FDWatcher
    handle::Ptr{Cvoid}
    fdnum::Int # this is NOT the file descriptor
    refcount::Tuple{Int, Int}
    notify::Base.ThreadSynchronizer
    events::Int32
    active::Tuple{Bool, Bool}

    let FDWatchers = Vector{Any}()
        global _FDWatcher, uvfinalize
        @static if Sys.isunix()
            function _FDWatcher(fd::RawFD, readable::Bool, writable::Bool)
                if !readable && !writable
                    throw(ArgumentError("must specify at least one of readable or writable to create a FDWatcher"))
                end
                fdnum = Core.Intrinsics.bitcast(Int32, fd) + 1
                iolock_begin()
                if fdnum > length(FDWatchers)
                    old_len = length(FDWatchers)
                    resize!(FDWatchers, fdnum)
                    FDWatchers[(old_len + 1):fdnum] .= nothing
                elseif FDWatchers[fdnum] !== nothing
                    this = FDWatchers[fdnum]::_FDWatcher
                    this.refcount = (this.refcount[1] + Int(readable), this.refcount[2] + Int(writable))
                    iolock_end()
                    return this
                end
                if ccall(:jl_uv_unix_fd_is_watched, Int32, (RawFD, Ptr{Cvoid}, Ptr{Cvoid}), fd, C_NULL, eventloop()) == 1
                    throw(ArgumentError("$(fd) is already being watched by libuv"))
                end

                handle = Libc.malloc(_sizeof_uv_poll)
                this = new(
                    handle,
                    fdnum,
                    (Int(readable), Int(writable)),
                    Base.ThreadSynchronizer(),
                    0,
                    (false, false))
                associate_julia_struct(handle, this)
                err = ccall(:uv_poll_init, Int32, (Ptr{Cvoid}, Ptr{Cvoid}, RawFD), eventloop(), handle, fd)
                if err != 0
                    Libc.free(handle)
                    throw(_UVError("FDWatcher", err))
                end
                finalizer(uvfinalize, this)
                FDWatchers[fdnum] = this
                iolock_end()
                return this
            end
        end

        function uvfinalize(t::_FDWatcher)
            iolock_begin()
            lock(t.notify)
            try
                if t.handle != C_NULL
                    disassociate_julia_struct(t)
                    ccall(:jl_close_uv, Cvoid, (Ptr{Cvoid},), t.handle)
                    t.handle = C_NULL
                end
                t.refcount = (0, 0)
                t.active = (false, false)
                @static if Sys.isunix()
                    if FDWatchers[t.fdnum] == t
                        FDWatchers[t.fdnum] = nothing
                    end
                end
                notify(t.notify, FDEvent())
            finally
                unlock(t.notify)
            end
            iolock_end()
            nothing
        end
    end

    @static if Sys.iswindows()
        function _FDWatcher(fd::RawFD, readable::Bool, writable::Bool)
            handle = Libc._get_osfhandle(fd)
            return _FDWatcher(handle, readable, writable)
        end
        function _FDWatcher(fd::WindowsRawSocket, readable::Bool, writable::Bool)
            if !readable && !writable
                throw(ArgumentError("must specify at least one of readable or writable to create a FDWatcher"))
            end

            handle = Libc.malloc(_sizeof_uv_poll)
            this = new(
                handle,
                0,
                (Int(readable), Int(writable)),
                Base.ThreadSynchronizer(),
                0,
                (false, false))
            associate_julia_struct(handle, this)
            iolock_begin()
            err = ccall(:uv_poll_init, Int32, (Ptr{Cvoid},  Ptr{Cvoid}, WindowsRawSocket),
                                               eventloop(), handle,     fd)
            iolock_end()
            if err != 0
                Libc.free(handle)
                throw(_UVError("FDWatcher", err))
            end
            finalizer(uvfinalize, this)
            return this
        end
    end
end

function iswaiting(fwd::_FDWatcher, t::Task)
    return fwd.notify.waitq === t.queue
end

mutable struct FDWatcher
    watcher::_FDWatcher
    readable::Bool
    writable::Bool
    # WARNING: make sure `close` has been manually called on this watcher before closing / destroying `fd`
    function FDWatcher(fd::RawFD, readable::Bool, writable::Bool)
        this = new(_FDWatcher(fd, readable, writable), readable, writable)
        finalizer(close, this)
        return this
    end
    @static if Sys.iswindows()
        function FDWatcher(fd::WindowsRawSocket, readable::Bool, writable::Bool)
            this = new(_FDWatcher(fd, readable, writable), readable, writable)
            finalizer(close, this)
            return this
        end
    end
end


function close(t::_FDWatcher, readable::Bool, writable::Bool)
    iolock_begin()
    if t.refcount != (0, 0)
        t.refcount = (t.refcount[1] - Int(readable), t.refcount[2] - Int(writable))
    end
    if t.refcount == (0, 0)
        uvfinalize(t)
    end
    iolock_end()
    nothing
end

function close(t::FDWatcher)
    r, w = t.readable, t.writable
    t.readable = t.writable = false
    close(t.watcher, r, w)
end

function uvfinalize(uv::Union{FileMonitor, FolderMonitor, PollingFileWatcher})
    disassociate_julia_struct(uv)
    close(uv)
end

function close(t::Union{FileMonitor, FolderMonitor, PollingFileWatcher})
    if t.handle != C_NULL
        ccall(:jl_close_uv, Cvoid, (Ptr{Cvoid},), t.handle)
    end
end

function _uv_hook_close(uv::_FDWatcher)
    # fyi: jl_atexit_hook can cause this to get called too
    uv.handle = C_NULL
    uvfinalize(uv)
    nothing
end

function _uv_hook_close(uv::PollingFileWatcher)
    lock(uv.notify)
    try
        uv.handle = C_NULL
        uv.active = false
        notify(uv.notify, StatStruct())
    finally
        unlock(uv.notify)
    end
    nothing
end

function _uv_hook_close(uv::FileMonitor)
    lock(uv.notify)
    try
        uv.handle = C_NULL
        uv.active = false
        notify(uv.notify, FileEvent())
    finally
        unlock(uv.notify)
    end
    nothing
end

function _uv_hook_close(uv::FolderMonitor)
    uv.open = false
    uv.handle = C_NULL
    close(uv.notify)
    nothing
end

function uv_fseventscb_file(handle::Ptr{Cvoid}, filename::Ptr, events::Int32, status::Int32)
    t = @handle_as handle FileMonitor
    lock(t.notify)
    try
        if status != 0
            notify_error(t.notify, _UVError("FileMonitor", status))
        else
            t.events |= events
            notify(t.notify, FileEvent(events))
        end
    finally
        unlock(t.notify)
    end
    nothing
end

function uv_fseventscb_folder(handle::Ptr{Cvoid}, filename::Ptr, events::Int32, status::Int32)
    t = @handle_as handle FolderMonitor
    if status != 0
        put!(t.notify, _UVError("FolderMonitor", status))
    else
        fname = (filename == C_NULL) ? "" : unsafe_string(convert(Cstring, filename))
        put!(t.notify, fname => FileEvent(events))
    end
    nothing
end

function uv_pollcb(handle::Ptr{Cvoid}, status::Int32, events::Int32)
    t = @handle_as handle _FDWatcher
    lock(t.notify)
    try
        if status != 0
            notify_error(t.notify, _UVError("FDWatcher", status))
        else
            t.events |= events
            if t.active[1] || t.active[2]
                if isempty(t.notify)
                    # if we keep hearing about events when nobody appears to be listening,
                    # stop the poll to save cycles
                    t.active = (false, false)
                    ccall(:uv_poll_stop, Int32, (Ptr{Cvoid},), t.handle)
                end
            end
            notify(t.notify, FDEvent(events))
        end
    finally
        unlock(t.notify)
    end
    nothing
end

function uv_fspollcb(handle::Ptr{Cvoid}, status::Int32, prev::Ptr, curr::Ptr)
    t = @handle_as handle PollingFileWatcher
    old_status = t.curr_error
    t.curr_error = status
    if status == 0
        t.curr_stat = StatStruct(convert(Ptr{UInt8}, curr))
    end
    if status == 0 || status != old_status
        prev_stat = StatStruct(convert(Ptr{UInt8}, prev))
        lock(t.notify)
        try
            notify(t.notify, prev_stat)
        finally
            unlock(t.notify)
        end
    end
    nothing
end

function __init__()
    global uv_jl_pollcb = @cfunction(uv_pollcb, Cvoid, (Ptr{Cvoid}, Cint, Cint))
    global uv_jl_fspollcb = @cfunction(uv_fspollcb, Cvoid, (Ptr{Cvoid}, Cint, Ptr{Cvoid}, Ptr{Cvoid}))
    global uv_jl_fseventscb_file = @cfunction(uv_fseventscb_file, Cvoid, (Ptr{Cvoid}, Ptr{Int8}, Int32, Int32))
    global uv_jl_fseventscb_folder = @cfunction(uv_fseventscb_folder, Cvoid, (Ptr{Cvoid}, Ptr{Int8}, Int32, Int32))
    nothing
end

function start_watching(t::_FDWatcher)
    iolock_begin()
    t.handle == C_NULL && return throw(ArgumentError("FDWatcher is closed"))
    readable = t.refcount[1] > 0
    writable = t.refcount[2] > 0
    if t.active[1] != readable || t.active[2] != writable
        # make sure the READABLE / WRITEABLE state is updated
        uv_error("FDWatcher (start)",
                 ccall(:uv_poll_start, Int32, (Ptr{Cvoid}, Int32, Ptr{Cvoid}),
                       t.handle,
                       (readable ? UV_READABLE : 0) | (writable ? UV_WRITABLE : 0),
                       uv_jl_pollcb::Ptr{Cvoid}))
        t.active = (readable, writable)
    end
    iolock_end()
    nothing
end

function start_watching(t::PollingFileWatcher)
    iolock_begin()
    t.handle == C_NULL && return throw(ArgumentError("PollingFileWatcher is closed"))
    if !t.active
        uv_error("PollingFileWatcher (start)",
                 ccall(:uv_fs_poll_start, Int32, (Ptr{Cvoid}, Ptr{Cvoid}, Cstring, UInt32),
                       t.handle, uv_jl_fspollcb::Ptr{Cvoid}, t.file, t.interval))
        t.active = true
    end
    iolock_end()
    nothing
end

function stop_watching(t::PollingFileWatcher)
    iolock_begin()
    lock(t.notify)
    try
        if t.active && isempty(t.notify)
            t.active = false
            uv_error("PollingFileWatcher (stop)",
                     ccall(:uv_fs_poll_stop, Int32, (Ptr{Cvoid},), t.handle))
        end
    finally
        unlock(t.notify)
    end
    iolock_end()
    nothing
end

function start_watching(t::FileMonitor)
    iolock_begin()
    t.handle == C_NULL && return throw(ArgumentError("FileMonitor is closed"))
    if !t.active
        uv_error("FileMonitor (start)",
                 ccall(:uv_fs_event_start, Int32, (Ptr{Cvoid}, Ptr{Cvoid}, Cstring, Int32),
                       t.handle, uv_jl_fseventscb_file::Ptr{Cvoid}, t.file, 0))
        t.active = true
    end
    iolock_end()
    nothing
end

function stop_watching(t::FileMonitor)
    iolock_begin()
    lock(t.notify)
    try
        if t.active && isempty(t.notify)
            t.active = false
            uv_error("FileMonitor (stop)",
                     ccall(:uv_fs_event_stop, Int32, (Ptr{Cvoid},), t.handle))
        end
    finally
        unlock(t.notify)
    end
    iolock_end()
    nothing
end

function wait(fdw::FDWatcher)
    GC.@preserve fdw begin
        return wait(fdw.watcher, readable = fdw.readable, writable = fdw.writable)
    end
end

function wait(fdw::_FDWatcher; readable=true, writable=true)
    events = FDEvent(Int32(0))
    iolock_begin()
    preserve_handle(fdw)
    lock(fdw.notify)
    try
        while true
            haveevent = false
            events |= FDEvent(fdw.events)
            if readable && isreadable(events)
                fdw.events &= ~UV_READABLE
                haveevent = true
            end
            if writable && iswritable(events)
                fdw.events &= ~UV_WRITABLE
                haveevent = true
            end
            if haveevent
                break
            end
            if fdw.refcount == (0, 0) # !open
                throw(EOFError())
            else
                start_watching(fdw) # make sure the poll is active
                iolock_end()
                events = wait(fdw.notify)::FDEvent
                unlock(fdw.notify)
                iolock_begin()
                lock(fdw.notify)
            end
        end
    finally
        unlock(fdw.notify)
        unpreserve_handle(fdw)
    end
    iolock_end()
    return events
end

function wait(fd::RawFD; readable=false, writable=false)
    fdw = _FDWatcher(fd, readable, writable)
    try
        return wait(fdw, readable=readable, writable=writable)
    finally
        close(fdw, readable, writable)
    end
end

if Sys.iswindows()
    function wait(socket::WindowsRawSocket; readable=false, writable=false)
        fdw = _FDWatcher(socket, readable, writable)
        try
            return wait(fdw, readable=readable, writable=writable)
        finally
            close(fdw, readable, writable)
        end
    end
end

function wait(pfw::PollingFileWatcher)
    iolock_begin()
    preserve_handle(pfw)
    lock(pfw.notify)
    local prevstat
    try
        start_watching(pfw)
        iolock_end()
        prevstat = wait(pfw.notify)::StatStruct
        unlock(pfw.notify)
        iolock_begin()
        lock(pfw.notify)
    finally
        unlock(pfw.notify)
        unpreserve_handle(pfw)
    end
    stop_watching(pfw)
    iolock_end()
    if pfw.handle == C_NULL
        return prevstat, EOFError()
    elseif pfw.curr_error != 0
        return prevstat, _UVError("PollingFileWatcher", pfw.curr_error)
    else
        return prevstat, pfw.curr_stat
    end
end

function wait(m::FileMonitor)
    iolock_begin()
    preserve_handle(m)
    lock(m.notify)
    local events
    try
        start_watching(m)
        iolock_end()
        events = wait(m.notify)::FileEvent
        events |= FileEvent(m.events)
        m.events = 0
        unlock(m.notify)
        iolock_begin()
        lock(m.notify)
    finally
        unlock(m.notify)
        unpreserve_handle(m)
    end
    stop_watching(m)
    iolock_end()
    return events
end

function wait(m::FolderMonitor)
    m.handle == C_NULL && return throw(ArgumentError("FolderMonitor is closed"))
    if isready(m.notify)
        evt = take!(m.notify) # non-blocking fast-path
    else
        preserve_handle(m)
        evt = try
                take!(m.notify)
            catch ex
                unpreserve_handle(m)
                if ex isa InvalidStateException && ex.state === :closed
                    rethrow(EOFError()) # `wait(::Channel)` throws the wrong exception
                end
                rethrow()
            end
    end
    if evt isa Pair{String, FileEvent}
        return evt
    else
        throw(evt)
    end
end


"""
    poll_fd(fd, timeout_s::Real=-1; readable=false, writable=false)

Monitor a file descriptor `fd` for changes in the read or write availability, and with a
timeout given by `timeout_s` seconds.

The keyword arguments determine which of read and/or write status should be monitored; at
least one of them must be set to `true`.

The returned value is an object with boolean fields `readable`, `writable`, and `timedout`,
giving the result of the polling.
"""
function poll_fd(s::Union{RawFD, Sys.iswindows() ? WindowsRawSocket : Union{}}, timeout_s::Real=-1; readable=false, writable=false)
    wt = Condition()
    fdw = _FDWatcher(s, readable, writable)
    local timer
    try
        if timeout_s >= 0
            result::FDEvent = FDEvent()
            t = @async begin
                timer = Timer(timeout_s) do t
                    notify(wt)
                end
                try
                    result = wait(fdw, readable=readable, writable=writable)
                catch e
                    notify_error(wt, e)
                    return
                end
                notify(wt)
            end
            wait(wt)
            # It's possible that both the timer and the poll fired on the same
            # libuv loop. In that case, which event we see here first depends
            # on task schedule order. If we can see that the task isn't waiting
            # on the file watcher anymore, just let it finish so we can see
            # the modification to `result`
            iswaiting(fdw, t) || wait(t)
            return result
        else
            return wait(fdw, readable=readable, writable=writable)
        end
    finally
        close(fdw, readable, writable)
        @isdefined(timer) && close(timer)
    end
end

"""
    watch_file(path::AbstractString, timeout_s::Real=-1)

Watch file or directory `path` for changes until a change occurs or `timeout_s` seconds have
elapsed.

The returned value is an object with boolean fields `changed`, `renamed`, and `timedout`,
giving the result of watching the file.

This behavior of this function varies slightly across platforms. See
<https://nodejs.org/api/fs.html#fs_caveats> for more detailed information.
"""
function watch_file(s::String, timeout_s::Float64=-1.0)
    fm = FileMonitor(s)
    local timer
    try
        if timeout_s >= 0
            timer = Timer(timeout_s) do t
                close(fm)
            end
        end
        return wait(fm)
    finally
        close(fm)
        @isdefined(timer) && close(timer)
    end
end
watch_file(s::AbstractString, timeout_s::Real=-1) = watch_file(String(s), Float64(timeout_s))

"""
    watch_folder(path::AbstractString, timeout_s::Real=-1)

Watches a file or directory `path` for changes until a change has occurred or `timeout_s`
seconds have elapsed.

This will continuing tracking changes for `path` in the background until
`unwatch_folder` is called on the same `path`.

The returned value is an pair where the first field is the name of the changed file (if available)
and the second field is an object with boolean fields `changed`, `renamed`, and `timedout`,
giving the event.

This behavior of this function varies slightly across platforms. See
<https://nodejs.org/api/fs.html#fs_caveats> for more detailed information.
"""
watch_folder(s::AbstractString, timeout_s::Real=-1) = watch_folder(String(s), timeout_s)
function watch_folder(s::String, timeout_s::Real=-1)
    fm = get!(watched_folders, s) do
        return FolderMonitor(s)
    end
    if timeout_s >= 0 && !isready(fm.notify)
        if timeout_s <= 0.010
            # for very small timeouts, we can just sleep for the whole timeout-interval
            (timeout_s == 0) ? yield() : sleep(timeout_s)
            if !isready(fm.notify)
                return "" => FileEvent() # timeout
            end
            # fall-through to a guaranteed non-blocking fast-path call to wait
        else
            # If we may need to be able to cancel via a timeout,
            # create a second monitor object just for that purpose.
            # We still take the events from the primary stream.
            fm2 = FileMonitor(s)
            timer = Timer(timeout_s) do t
                close(fm2)
            end
            try
                while isopen(fm.notify) && !isready(fm.notify)
                    fm2.handle == C_NULL && return "" => FileEvent() # timeout
                    wait(fm2)
                end
            finally
                close(fm2)
                close(timer)
            end
            # guaranteed that next call to `wait(fm)` is non-blocking
            # since we haven't entered the libuv event loop yet
            # or the Base scheduler workqueue since last testing `isready`
        end
    end
    return wait(fm)
end

"""
    unwatch_folder(path::AbstractString)

Stop background tracking of changes for `path`.
It is not recommended to do this while another task is waiting for
`watch_folder` to return on the same path, as the result may be unpredictable.
"""
unwatch_folder(s::AbstractString) = unwatch_folder(String(s))
function unwatch_folder(s::String)
    fm = pop!(watched_folders, s, nothing)
    fm === nothing || close(fm)
    nothing
end

const watched_folders = Dict{String, FolderMonitor}()

"""
    poll_file(path::AbstractString, interval_s::Real=5.007, timeout_s::Real=-1) -> (previous::StatStruct, current)

Monitor a file for changes by polling every `interval_s` seconds until a change occurs or
`timeout_s` seconds have elapsed. The `interval_s` should be a long period; the default is
5.007 seconds.

Returns a pair of status objects `(previous, current)` when a change is detected.
The `previous` status is always a `StatStruct`, but it may have all of the fields zeroed
(indicating the file didn't previously exist, or wasn't previously accessible).

The `current` status object may be a `StatStruct`, an `EOFError` (indicating the timeout elapsed),
or some other `Exception` subtype (if the `stat` operation failed - for example, if the path does not exist).

To determine when a file was modified, compare `current isa StatStruct && mtime(prev) != mtime(current)` to detect
notification of changes. However, using [`watch_file`](@ref) for this operation is preferred, since
it is more reliable and efficient, although in some situations it may not be available.
"""
function poll_file(s::AbstractString, interval_seconds::Real=5.007, timeout_s::Real=-1)
    pfw = PollingFileWatcher(s, Float64(interval_seconds))
    local timer
    try
        if timeout_s >= 0
            timer = Timer(timeout_s) do t
                close(pfw)
            end
        end
        statdiff = wait(pfw)
        if isa(statdiff[2], IOError)
            # file didn't initially exist, continue watching for it to be created (or the error to change)
            statdiff = wait(pfw)
        end
        return statdiff
    finally
        close(pfw)
        @isdefined(timer) && close(timer)
    end
end


## Pidfile: This code originated in https://github.com/vtjnash/Pidfile.jl
"""
    mkpidlock([f::Function], at::String, [pid::Cint, proc::Process]; kwopts...)

Create a pidfile lock for the path "at" for the current process
or the process identified by pid or proc. Can take a function to execute once locked,
for usage in `do` blocks, after which the lock will be automatically closed.
Optional keyword arguments:
 - `mode`: file access mode (modified by the process umask). Defaults to world-readable.
 - `poll_interval`: Specify the maximum time to between attempts (if `watch_file` doesn't work)
 - `stale_age`: Delete an existing pidfile (ignoring the lock) if its mtime is older than this.
     The file won't be deleted until 25x longer than this if the pid in the file appears that it may be valid.
     By default this is disabled (`stale_age` = 0), but a typical recommended value would be about 3-5x an
     estimated normal completion time.

For instance multiple julia processes could use the following to simultaneously append to the same file safely:

```julia
file = "/path/to/file"
mkpidlock(file) do
    open(file, write = true, append = true) do io
        write(io, "new text")
    end
end
```
"""
function mkpidlock end

mutable struct LockMonitor
    path::String
    fd::File

    global function mkpidlock(at::String, pid::Cint; kwopts...)
        local lock
        at = abspath(at)
        fd = open_exclusive(at; kwopts...)
        try
            write_pidfile(fd, pid)
            lock = new(at, fd)
            finalizer(close, lock)
        catch ex
            close(fd)
            rm(at)
            rethrow(ex)
        end
        return lock
    end
end

mkpidlock(at::String; kwopts...) = mkpidlock(at, getpid(); kwopts...)
mkpidlock(f::Function, at::String; kwopts...) = mkpidlock(f, at, getpid(); kwopts...)

function mkpidlock(f::Function, at::String, pid::Cint; kwopts...)
    lock = mkpidlock(at, pid; kwopts...)
    try
        return f()
    finally
        close(lock)
    end
end

# TODO: enable this when we update libuv
#Base.getpid(proc::Process) = ccall(:uv_process_get_pid, Cint, (Ptr{Void},), proc.handle)
#function mkpidlock(at::String, proc::Process; kwopts...)
#    lock = mkpidlock(at, getpid(proc))
#    @schedule begin
#        wait(proc)
#        close(lock)
#    end
#    return lock
#end

"""
    write_pidfile(io, pid)

Write our pidfile format to an open IO descriptor.
"""
function write_pidfile(io::IO, pid::Cint)
    print(io, "$pid $(gethostname())")
end

"""
    parse_pidfile(file::Union{IO, String}) => (pid, hostname, age)

Attempt to parse our pidfile format,
replaced an element with (0, "", 0.0), respectively, for any read that failed.
"""
function parse_pidfile(io::IO)
    fields = split(read(io, String), ' ', limit = 2)
    pid = tryparse(Cuint, fields[1])
    pid === nothing && (pid = Cuint(0))
    hostname = (length(fields) == 2) ? fields[2] : ""
    when = mtime(io)
    age = time() - when
    return (pid, hostname, age)
end

function parse_pidfile(path::String)
    try
        existing = open(path, JL_O_RDONLY)
        try
            return parse_pidfile(existing)
        finally
            close(existing)
        end
    catch ex
        isa(ex, EOFError) || isa(ex, IOError) || rethrow(ex)
        return (Cuint(0), "", 0.0)
    end
end

"""
    isvalidpid(hostname::String, pid::Cuint) :: Bool

Attempt to conservatively estimate whether pid is a valid process id.
"""
function isvalidpid(hostname::AbstractString, pid::Cuint)
    # can't inspect remote hosts
    (hostname == "" || hostname == gethostname()) || return true
    # pid < 0 is never valid (must be a parser error or different OS),
    # and would have a completely different meaning when passed to kill
    !Sys.iswindows() && pid > typemax(Cint) && return false
    # (similarly for pid 0)
    pid == 0 && return false
    # see if the process id exists by querying kill without sending a signal
    # and checking if it returned ESRCH (no such process)
    return ccall(:uv_kill, Cint, (Cuint, Cint), pid, 0) != UV_ESRCH
end

"""
    stale_pidfile(path::String, stale_age::Real) :: Bool

Helper function for `open_exclusive` for deciding if a pidfile is stale.
"""
function stale_pidfile(path::String, stale_age::Real)
    pid, hostname, age = parse_pidfile(path)
    if age < -stale_age
        @warn "filesystem time skew detected" path=path
    elseif age > stale_age
        if (age > stale_age * 25) || !isvalidpid(hostname, pid)
            return true
        end
    end
    return false
end

"""
    tryopen_exclusive(path::String, mode::Integer = 0o444) :: Union{Void, File}

Try to create a new file for read-write advisory-exclusive access,
return nothing if it already exists.
"""
function tryopen_exclusive(path::String, mode::Integer = 0o444)
    try
        return open(path, JL_O_RDWR | JL_O_CREAT | JL_O_EXCL, mode)
    catch ex
        (isa(ex, IOError) && ex.code == UV_EEXIST) || rethrow(ex)
    end
    return nothing
end

"""
    open_exclusive(path::String; mode, poll_interval, stale_age) :: File

Create a new a file for read-write advisory-exclusive access,
blocking until it can succeed.
For a description of the keyword arguments, see [`mkpidlock`](@ref).
"""
function open_exclusive(path::String;
        mode::Integer = 0o444 #= read-only =#,
        poll_interval::Real = 10 #= seconds =#,
        stale_age::Real = 0 #= disabled =#)
    # fast-path: just try to open it
    file = tryopen_exclusive(path, mode)
    file === nothing || return file
    @info "waiting for lock on pidfile" path=path
    # fall-back: wait for the lock
    while true
        # start the file-watcher prior to checking for the pidfile existence
        t = @async try
            watch_file(path, poll_interval)
        catch ex
            isa(ex, IOError) || rethrow(ex)
            sleep(poll_interval) # if the watch failed, convert to just doing a sleep
        end
        # now try again to create it
        file = tryopen_exclusive(path, mode)
        file === nothing || return file
        wait(t) # sleep for a bit before trying again
        if stale_age > 0 && stale_pidfile(path, stale_age)
            # if the file seems stale, try to remove it before attempting again
            # set stale_age to zero so we won't attempt again, even if the attempt fails
            stale_age -= stale_age
            @warn "attempting to remove probably stale pidfile" path=path
            try
                rm(path)
            catch ex
                isa(ex, IOError) || rethrow(ex)
            end
        end
    end
end

"""
    close(lock::LockMonitor)

Release a pidfile lock.
"""
function Base.close(lock::LockMonitor)
    isopen(lock.fd) || return false
    havelock = samefile(stat(lock.fd), stat(lock.path))
    close(lock.fd)
    if havelock # try not to delete someone else's lock
        rm(lock.path)
    end
    return havelock
end

end
