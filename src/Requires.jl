module Requires

using UUIDs

function _include_path(relpath)
    # Reproduces include()'s runtime relative path logic
    # See Base._include_dependency()
    prev = Base.source_path(nothing)
    if prev === nothing
        path = abspath(relpath)
    else
        path = normpath(joinpath(dirname(prev), relpath))
    end
end

"""
    @include("somefile.jl")

Behaves like `include`, but caches the target file content at macro expansion
time, and uses this as a fallback when the file doesn't exist at runtime. This
is useful when compiling a sysimg. The argument `"somefile.jl"` must be a
string literal, not an expression.

`@require` blocks insert this automatically when you use `include`.
"""
macro include(relpath)
    compiletime_path = joinpath(dirname(String(__source__.file)), relpath)
    s = String(read(compiletime_path))
    quote
        # NB: Runtime include path may differ from the compile-time macro
        # expansion path if the source has been relocated.
        runtime_path = _include_path($relpath)
        if isfile(runtime_path)
            # NB: For Revise compatibility, include($relpath) needs to be
            # emitted where $relpath is a string *literal*.
            $(esc(:(include($relpath))))
        else
            include_string($__module__, $s, $relpath)
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
    @assert precompile(callbacks, (Base.PkgId,))
    @assert precompile(withnotifications, (Vararg{Any},))
    @assert precompile(withnotifications, (Any, Vararg{Any},))
    @assert precompile(replace_include, (Expr, LineNumberNode,))
end

end # module
