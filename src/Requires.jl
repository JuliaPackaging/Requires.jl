__precompile__()

module Requires

include("init.jl")
include("require.jl")

function __init__()
    push!(package_callbacks, loadpkg)
end

end # module
