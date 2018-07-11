### Note: changes in v0.7

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

Usage is as simple as

```julia
media(::MyType) = Textual()

@require Gadfly begin
  media(::Gadfly.Plot) = Graphical()
end
```

For larger amounts of code you can also use `@require Package include("glue.jl")`.
The code wrapped by `@require` will execute as soon as the given package is loaded
(which may be immediately).

```julia
julia> using Requires

julia> @require DataFrames println("foo")

julia> using DataFrames
foo

julia> @require DataFrames println("bar")
bar
```

Note that the package is not imported by default – you need an explicit `using`
statement if you want to use the packages names without qualifying them.

See [here](https://github.com/one-more-minute/Jewel.jl/blob/b0e8c184f57e8e60c83e1b9ef49511b08c88f16f/src/LightTable/display/objects.jl#L168-L170)
for some more detailed examples.
