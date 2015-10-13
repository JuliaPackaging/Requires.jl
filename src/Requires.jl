VERSION >= v"0.4-" && __precompile__()

module Requires
using Compat
include("init.jl")
include("getthing.jl")
include("require.jl")

end # module
