### Note: this page is for Julia 0.7 and higher

For older versions of Julia, see https://github.com/MikeInnes/Requires.jl/blob/5683745f03cbea41f6f053182461173e236fdd94/README.md



Requires now needs a UUID, and must be called from within your packages `__init__` function. For example:

```julia
function __init__()
    @require JSON="682c06a0-de6a-54ab-a142-c8b1cf79cde6" do_stuff()
end
```

# Requires.jl

[![Build Status](https://travis-ci.org/MikeInnes/Requires.jl.svg?branch=master)](https://travis-ci.org/MikeInnes/Requires.jl)

*Requires* is a Julia package that will magically make loading packages
faster, maybe. It supports specifying glue code in packages which will
load automatically when a another package is loaded, so that explicit
dependencies (and long load times) can be avoided.

Suppose you've written a package called `MyPkg`. `MyPkg` has core functionality that it always provides;
but suppose you want to provide additional functionality if the `Gadfly` package is also loaded.
Requires.jl exports a macro, `@require`, that allows you to specify that some code is conditional on having both packages available.

`@require` must be within the [`__init__`](https://docs.julialang.org/en/v1/manual/modules/#Module-initialization-and-precompilation-1) method for your module.
Here's an example that will create a new method of a function called `media` only when both packages are present:

```julia
module MyPkg

# lots of code

myfunction(::MyType) = Textual()

function __init__()
    @require Gadfly="c91e804a-d5a3-530f-b6f0-dfbca275c004" myfunction(::Gadfly.Plot) = Graphical()
end

end # module
```

`Gadfly` is the name of the package, and the value in the string is the UUID which may be obtained
by finding the package in the registry ([JuliaRegistries](https://github.com/JuliaRegistries/General) for public packages).
Note that the `Gadfly.Plot` type may not be available when you load `MyPkg`, but `@require`
handles this situation without trouble.

For larger amounts of code you can use `include` inside the `@require` statement:

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

For a complete demo, consider the following file named `"Reqs.jl"`:

```julia
module Reqs

using Requires

function __init__()
    @require JSON="682c06a0-de6a-54ab-a142-c8b1cf79cde6" @eval using Colors
end

end
```

Here's a complete demo using this file (note that if this were a registered package you could
replace the first two commands with `using Reqs`):

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
