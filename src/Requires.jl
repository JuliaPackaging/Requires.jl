__precompile__()

module Requires

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
