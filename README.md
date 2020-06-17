### Note: this page is for Julia 0.7 and higher

For older versions of Julia, see https://github.com/MikeInnes/Requires.jl/blob/5683745f03cbea41f6f053182461173e236fdd94/README.md

# Requires.jl

[![Build Status](https://travis-ci.org/MikeInnes/Requires.jl.svg?branch=master)](https://travis-ci.org/MikeInnes/Requires.jl)

*Requires* is a Julia package that will magically make loading packages
faster, maybe. It supports specifying glue code in packages which will
load automatically when another package is loaded, so that explicit
dependencies (and long load times) can be avoided.

Suppose you've written a package called `MyPkg`. `MyPkg` has core functionality that it always provides;
but suppose you want to provide additional functionality if the `Gadfly` package is also loaded.
Requires.jl exports a macro, `@require`, that allows you to specify that some code is conditional on having both packages available.

`@require` must be within the [`__init__`](https://docs.julialang.org/en/v1/manual/modules/#Module-initialization-and-precompilation-1) method for your module.
Here's an example that will create a new method of a function called `myfunction` only when both packages are present:

```julia
module MyPkg

# lots of code

myfunction(::MyType) = Textual()

function __init__()
    @require Gadfly="c91e804a-d5a3-530f-b6f0-dfbca275c004" myfunction(::Gadfly.Plot) = Graphical()
end

end # module
```

The string is Gadfly's UUID; this information may be obtained
by finding the package in the registry ([JuliaRegistries](https://github.com/JuliaRegistries/General) for public packages).
Note that the `Gadfly.Plot` type may not be available when you load `MyPkg`, but `@require`
handles this situation without trouble.

For larger amounts of code you can use `include` as the argument to the `@require` statement:

```julia
function __init__()
    @require Gadfly="c91e804a-d5a3-530f-b6f0-dfbca275c004" include("glue.jl")
end
```

and this will trigger the loading and evaluation of `"glue.jl"` in `MyPkg` whenever Gadfly is loaded.
You can even use

```julia
function __init__()
    @require Gadfly="c91e804a-d5a3-530f-b6f0-dfbca275c004" @eval using MyGluePkg
end
```

if you wish to exploit precompilation for the new code.

In the `@require` block, or any included files, you can use or import the package, but note that you must use the syntax `using .Gadfly` or `import .Gadfly`, rather than the usual syntax. Otherwise you will get a warning about Gadfly not being in dependencies.

## Demo

For a complete demo, consider the following file named `"Reqs.jl"`:

```julia
module Reqs

using Requires

function __init__()
    @require JSON="682c06a0-de6a-54ab-a142-c8b1cf79cde6" @eval using Colors
end

end
```

Here's a session that shows how `Colors` is only loaded after you've imported `JSON`:

```julia
julia> include("Reqs.jl")
Main.Reqs

julia> using Main.Reqs

julia> Reqs.Colors
ERROR: UndefVarError: Colors not defined

julia> using JSON

julia> Reqs.Colors
Colors

julia> Reqs.Colors.RGB(1,0,0)
RGB{N0f8}(1.0,0.0,0.0)
```

Note that if `Reqs` were a registered package you could replace the first two commands with `using Reqs`.

## Multiple requirements

In the case that a feature depends on multiple packages, you can do the following trick:

```julia
module TestRequires

using Requires

function __init__()
    @require Images="916415d5-f1e6-5110-898d-aaa5f9f070e0" begin
        @require Revise="295af30f-e4ad-537b-8983-00126c2a3abe" println("Got both!")
    end
end

end # module
```

The code will only be loaded in the presence of both Images.jl and Revise.jl:

```julia
julia> using TestRequires
[ Info: Precompiling TestRequires [eb9e79a2-1324-11e9-3469-91075b92f61d]

julia> using Images

julia> using Revise
[ Info: Recompiling stale cache file /tmp/pkgs/compiled/v1.0/Revise/M1Qoh.ji for Revise [295af30f-e4ad-537b-8983-00126c2a3abe]
Got both!
```

## Receiving notifications in other packages

Other packages can be informed about Requires' actions. To implement this, add a function

```julia
add_require(sourcefile, modcaller, id, modname, expr)
```

to your package. The arguments will have the following types:

- `sourcefile`: a string, the full path to the file that contained the `@require` statement
- `modcaller`: the active module from which the `@require` was issued
- `id`: a string representing the UUID of the package that triggered this `@require` block (e.g.,
  the uuid string from `@require Gadfly="c91e804a-d5a3-530f-b6f0-dfbca275c004"`)
- `modname`: a string representing the name of the package that triggered this `@require` block
  (e.g., `"Gadfly"` in the example above)
- `expr`: the expression in the `@require` block

Once you've added this, append the `PkgId` of your package to `Requires.notified_pkgs`
in a pull request to Requires.
