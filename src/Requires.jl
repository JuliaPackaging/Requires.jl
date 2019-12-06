module Requires

using UUIDs

include("init.jl")
include("require.jl")

function __init__()
    push!(package_callbacks, loadpkg)
end

end # module
