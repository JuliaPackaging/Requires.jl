module Requires

using UUIDs

"""
    @include("somefile.jl")

Behaves like `include`, but caches the target file content at macro expansion
time, and uses this as a fallback when the file doesn't exist at runtime. This
is useful when compiling a sysimg. The argument `"somefile.jl"` must be a
string literal, not an expression.

`@require` blocks insert this automatically when you use `include`.
"""
macro include(file)
    file = joinpath(dirname(String(__source__.file)), file)
    s = String(read(file))
    quote
        file = $file
        mod = $__module__
        if isfile(file)
            Base.include(mod, file)
        else
            include_string(mod, $s, file)
        end
    end
end

include("init.jl")
include("require.jl")

function __init__()
    push!(package_callbacks, loadpkg)
end

if isprecompiling()
    @assert precompile(loadpkg, (Base.PkgId,))
    @assert precompile(withpath, (Any, String))
    @assert precompile(err, (Any, Module, String))
    @assert precompile(parsepkg, (Expr,))
    @assert precompile(listenpkg, (Any, Base.PkgId))
end

end # module
