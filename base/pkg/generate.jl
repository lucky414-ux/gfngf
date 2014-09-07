module Generate

import ..Git, ..Read
using ..Licenses

const LICENSES = ["MIT" => Licenses.mit,
                  "BSD" => Licenses.bsd,
                  "ASL" => Licenses.asl ]

copyright_year() = readchomp(`date +%Y`)
copyright_name(dir::String) = readchomp(Git.cmd(`config --get user.name`, dir=dir))
github_user() = readchomp(ignorestatus(`git config --global --get github.user`))

function git_contributors(dir::String, n::Int=typemax(Int))
    contrib = Dict()
    tty = @windows? "CON:" : "/dev/tty"
    for line in eachline(tty |> Git.cmd(`shortlog -nes`, dir=dir))
        m = match(r"\s*(\d+)\s+(.+?)\s+\<(.+?)\>\s*$", line)
        m == nothing && continue
        commits, name, email = m.captures
        if haskey(contrib,email)
            contrib[email][1] += int(commits)
        else
            contrib[email] = [int(commits),name]
        end
    end
    names = Dict()
    for (commits,name) in values(contrib)
        names[name] = get(names,name,0) + commits
    end
    names = sort!(collect(keys(names)),by=name->names[name],rev=true)
    length(names) <= n ? names : [names[1:n], "et al."]
end

function package(
    pkg::String,
    license::String;
    force::Bool = false,
    authors::Union(String,Array) = "",
    years::Union(Int,String) = copyright_year(),
    user::String = github_user(),
    config::Dict = {},
)
    isnew = !ispath(pkg)
    try
        if isnew
            url = isempty(user) ? "" : "git://github.com/$user/$pkg.jl.git"
            Generate.init(pkg,url,config=config)
        else
            Git.dirty(dir=pkg) && error("$pkg is dirty – commit or stash your changes")
        end

        Git.transact(dir=pkg) do
            if isempty(authors)
                authors = isnew ? copyright_name(pkg) : git_contributors(pkg,5)
            end
            if !haskey(LICENSES,license)
                licenses = join(sort!([keys(LICENSES)...], by=lowercase), ", ")
                error("$license is not a known license choice, choose one of: $licenses.")
            end
            license = LICENSES[license](pkg,copyright(years,authors))
            Generate.license(pkg, license,force=force)
            Generate.readme(pkg,license,user,force=force)
            Generate.entrypoint(pkg,force=force)
            Generate.tests(pkg,force=force)
            Generate.travis(pkg,force=force)

            msg = """
            $pkg.jl $(isnew ? "generated" : "regenerated") files.

                license:  $license
                authors:  $(join([authors],", "))
                years:    $years
                user:     $user

            Julia Version $VERSION [$(Base.GIT_VERSION_INFO.commit_short)]
            """

            if isnew
                info("Committing $pkg generated files")
                Git.run(`commit -q -m $msg`, dir=pkg)
            elseif Git.dirty(dir=pkg)
                Git.run(`reset -q --`, dir=pkg)
                info("Regenerated files left unstaged, use `git add -p` to select")
                open(io->print(io,msg), joinpath(Git.dir(pkg),"MERGE_MSG"), "w")
            else
                info("Regenerated files are unchanged")
            end
        end
    catch
        isnew && rm(pkg, recursive=true)
        rethrow()
    end
end

function init(pkg::String, url::String=""; config::Dict=Dict())
    if !ispath(pkg)
        info("Initializing $pkg repo: $(abspath(pkg))")
        Git.run(`init -q $pkg`)

        for (key,val) in config
            Git.run(`config $key $val`, dir=pkg)
        end
        Git.run(`commit -q --allow-empty -m "initial empty commit"`, dir=pkg)
    end
    isempty(url) && return
    info("Origin: $url")
    Git.run(`remote add origin $url`,dir=pkg)
    Git.set_remote_url(url,dir=pkg)
end

function license(pkg::String, license::Licenses.License; force::Bool=false)
    genfile(pkg,"LICENSE.md",force) do io
        print(io, license.terms)
    end || info("License file exists, leaving unmodified; use `force=true` to overwrite")
end

function readme(pkg::String, license::Licenses.License, user::String=""; force::Bool=false)
    genfile(pkg,"README.md",force) do io
        println(io, "# $pkg")
        isempty(user) && return
        url = "https://travis-ci.org/$user/$pkg.jl"
        println(io, "\n[![Build Status]($url.svg?branch=master)]($url)")
        println(io, """
        \n## License
        Available under the $(license.name). See: [LICENSE.md](./LICENSE.md).
        """)
    end
end

function tests(pkg::String; force::Bool=false)
    genfile(pkg,"test/runtests.jl",force) do io
        print(io, """
        using $pkg
        using Base.Test

        # write your own tests here
        @test 1 == 1
        """)
    end
end

function travis(pkg::String; force::Bool=false)
    genfile(pkg,".travis.yml",force) do io
        print(io, """
        language: cpp
        compiler:
          - clang
        notifications:
          email: false
        env:
          matrix:
            - JULIAVERSION="juliareleases"
            - JULIAVERSION="julianightlies"
        before_install:
          - sudo add-apt-repository ppa:staticfloat/julia-deps -y
          - sudo add-apt-repository ppa:staticfloat/\${JULIAVERSION} -y
          - sudo apt-get update -qq -y
          - sudo apt-get install libpcre3-dev julia -y
          - if [[ -a .git/shallow ]]; then git fetch --unshallow; fi
        script:
          - julia -e 'Pkg.init(); Pkg.clone(pwd()); Pkg.test("$pkg")'
        """)
    end
end

function entrypoint(pkg::String; force::Bool=false)
    genfile(pkg,"src/$pkg.jl",force) do io
        print(io, """
        module $pkg

        # package code goes here

        end # module
        """)
    end
end

function genfile(f::Function, pkg::String, file::String, force::Bool=false)
    path = joinpath(pkg,file)
    if force || !ispath(path)
        info("Generating $file")
        mkpath(dirname(path))
        open(f, path, "w")
        Git.run(`add $file`, dir=pkg)
        return true
    end
    return false
end

copyright(years::String, authors::String) = "Copyright (c) $years: $authors."

function copyright(years::String, authors::Array)
    text = "Copyright (c) $years:"
    for author in authors
        text *= "\n>  * $author"
    end
    return text
end

end # module
