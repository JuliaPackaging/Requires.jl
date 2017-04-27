function getthing(mod::Module, name::Vector{Symbol}, default = nothing)
  thing = mod
  for sym in name
    if Base.isbindingresolved(thing, sym)
      thing = getfield(thing, sym)
    else
      return default
    end
  end
  return thing
end

getthing(mod::Module, name::Symbol) = getthing(mod, string(name))
getthing(mod::Module, name::AbstractString, default = nothing) =
  name == "" ?
    default :
    getthing(mod, map(Symbol, split(name, ".", keep=false)), default)
