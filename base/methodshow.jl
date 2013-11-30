# Method and method-table pretty-printing

function argtype_decl(n, t) # -> (argname, argtype)
    if isa(n,Expr)
        n = n.args[1]  # handle n::T in arg list
    end
    s = string(n)
    i = search(s,'#')
    if i > 0
        s = s[1:i-1]
    end
    if t === Any && !isempty(s)
        return s, ""
    end
    if t <: Vararg && t !== None && t.parameters[1] === Any
        return string(s, "..."), ""
    end
    return s, string(t)
end

function arg_decl_parts(m::Method)
    tv = m.tvars
    if !isa(tv,Tuple)
        tv = (tv,)
    end
    li = m.func.code
    e = uncompressed_ast(li)
    argnames = e.args[1]
    s = symbol("?")
    decls = [argtype_decl(get(argnames,i,s), m.sig[i]) for i=1:length(m.sig)]
    return tv, decls, li.file, li.line
end

function show(io::IO, m::Method)
    tv, decls, file, line = arg_decl_parts(m)
    if !isempty(tv)
        show_delim_array(io, tv, '{', ',', '}', false)
    end
    print(io, "(")
    print_joined(io, [isempty(d[2]) ? d[1] : d[1]*"::"*d[2] for d in decls],
                 ",", ",")
    print(io, ")")
    if line > 0
        print(io, " at ", file, ":", line)
    end
end

function show_method_table(io::IO, mt::MethodTable, max::Int=-1, header::Bool=true)
    name = mt.name
    n = length(mt)
    if header
        m = n==1 ? "method" : "methods"
        print(io, "# $n $m for generic function \"$name\":")
    end
    d = mt.defs
    n = rest = 0
    while !is(d,())
        if max==-1 || n<max || (rest==0 && n==max && d.next === ())
            println(io)
            print(io, name)
            show(io, d)
            n += 1
        else
            rest += 1
        end
        d = d.next
    end
    if rest > 0
        println(io)
        print(io,"... $rest methods not shown (use methods($name) to see them all)")
    end
end

show(io::IO, mt::MethodTable) = show_method_table(io, mt)

inbase(m::Module) = m == Base ? true : m == Main ? false : inbase(module_parent(m))
function url(m::Method)
    M = m.func.code.module
    file = string(m.func.code.file)
    line = m.func.code.line
    line <= 0 || ismatch(r"In\[[0-9]+\]", file) && return ""
    if inbase(M)
        return "https://github.com/JuliaLang/julia/tree/$(Base.BUILD_INFO.commit)/base/$file#L$line"
    else 
        try
            pkg = Pkg.dir(string(M))
            if file[1:length(pkg)] != pkg
                return "file://"*find_source_file(file)
            end
            u = Git.readchomp(`config remote.origin.url`, dir=pkg)
            u = match(Git.GITHUB_REGEX,u).captures[1]
            commit = Git.readchomp(`rev-parse HEAD`, dir=pkg)
            return "https://github.com/$u/tree/$commit/"*file[length(pkg)+2:end]*"#L$line"
        catch
            return "file://"*find_source_file(file)
        end
    end
end

function writemime(io::IO, ::MIME"text/html", m::Method)
    tv, decls, file, line = arg_decl_parts(m)
    if !isempty(tv)
        print(io,"<i>")
        show_delim_array(io, tv, '{', ',', '}', false)
        print(io,"</i>")
    end
    print(io, "(")
    print_joined(io, [isempty(d[2]) ? d[1] : d[1]*"::<b>"*d[2]*"</b>" 
                      for d in decls], ",", ",")
    print(io, ")")
    if line > 0
        u = url(m)
        if isempty(u)
            print(io, " at ", file, ":", line)
        else
            print(io, """ at <a href="$u" target="_blank">""", 
                  file, ":", line, "</a>")
        end
    end
end

function writemime(io::IO, mime::MIME"text/html", mt::MethodTable)
    name = mt.name
    n = length(mt)
    meths = n==1 ? "method" : "methods"
    print(io, "$n $meths for generic function <b>$name</b>:<ul>")
    d = mt.defs
    while !is(d,())
        print(io, "<li> ", name)
        writemime(io, mime, d)
        d = d.next
    end
    print(io, "</ul>")
end
