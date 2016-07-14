# From Lazy.jl

isexpr(x::Expr) = true
isexpr(x) = false
isexpr(x::Expr, ts...) = x.head in ts
isexpr(x, ts...) = any(T->isa(T, Type) && isa(x, T), ts)

macro as(as, exs...)
  thread(x) = isexpr(x, :block) ? thread(subexprs(x)...) : x

  thread(x, ex) =
    isexpr(ex, Symbol, :->) ? Expr(:call, ex, x) :
    isexpr(ex, :block)      ? thread(x, subexprs(ex)...) :
    :(let $as = $x
        $ex
      end)

  thread(x, exs...) = reduce((x, ex) -> thread(x, ex), x, exs)

  esc(thread(exs...))
end

macro _(args...)
  :(@as $(esc(:_)) $(map(esc, args)...))
end

# From Jewel.jl

function getthing(mod::Module, name::Vector{Symbol}, default = nothing)
  thing = mod
  for sym in name
    if isdefined(thing, sym)
      thing = getfield(thing, sym)
    else
      return default
    end
  end
  return thing
end

getthing(name::Vector{Symbol}, default = nothing) =
  getthing(Main, name, default)

getthing(mod::Module, name::AbstractString, default = nothing) =
  name == "" ?
    default :
    @_ name split(_, ".", keep=false) map(Symbol, _) getthing(mod, _, default)

getthing(name::AbstractString, default = nothing) =
  getthing(Main, name, default)

getthing(::Void, default) = default
getthing(mod, ::Void, default) = default
