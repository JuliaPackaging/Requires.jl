module NotifyMe

using Requires, UUIDs

const notified_args = []
add_require(args...) = push!(notified_args, args)

function __init__()
    push!(Requires.notified_pkgs, Base.PkgId(UUID(0x545cf9b9f5754090a54a9a5287d37f74), "NotifyMe"))
end

end # module
