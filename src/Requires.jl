module Requires

using UUIDs

"""
    @include("file.jl")

Behaves like `include`, but loads the target file contents at load-time before
evaluating its contents at runtime. This is useful when the target file may not
be available at runtime (for example, because of compiling a sysimg).

`@require` blocks insert this automatically when you use `include`.
"""
macro include(file)
    file = joinpath(dirname(String(__source__.file)), file)
    s = String(read(file))
    :(include_string($__module__, $s, $file))
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
