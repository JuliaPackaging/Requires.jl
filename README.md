# Requires.jl

[![Build Status](https://travis-ci.org/one-more-minute/Requires.jl.svg?branch=master)](https://travis-ci.org/one-more-minute/Requires.jl)

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

-------------------------------------------------------------------------------

This package also provides the `@lazymod` macro, which provides a way to load
modules the first time they are used.

```julia
julia> using Requires

julia> @lazymod DataFrames
dataframes (generic function with 1 method)

julia> dataframes().DataFrame # This will take a few seconds
DataFrame (constructor with 22 methods)

julia> dataframes().DataFrame # This will be instant
DataFrame (constructor with 22 methods)
```

If the module you want to load lazily lives in its own file within your package,
you can also use

```julia
@lazymod MyMod "src/mymod.jl"
```

The source file will then be `include`ed when the module is first used.
See [here](https://github.com/one-more-minute/Jewel.jl/blob/139990c60467fc90c923d85903400f3e82678537/src/Jewel.jl#L13) for an example.
