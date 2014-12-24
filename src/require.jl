export @require

if VERSION < v"0.4-dev"
  Base.split(xs, x; keep=false) = split(xs, x, false)
end

function Base.require(s::ASCIIString)
  invoke(require, (String,), s)
  loadmod(s)
end

loaded(mod) = getthing(Main, mod) != nothing

const modlisteners = Dict{String,Vector{Function}}()

listenmod(f, mod) =
  loaded(mod) ? f() :
    modlisteners[mod] = push!(get(modlisteners, mod, Function[]), f)

loadmod(mod) =
  map(f->f(), get(modlisteners, mod, []))

importexpr(mod::Symbol) = Expr(:import, mod)
importexpr(mod::Expr) = Expr(:import, map(symbol, split(string(mod), "."))...)

macro require (mod, expr)
  quote
    listenmod($(string(mod))) do
      $(esc(Expr(:call, :eval, Expr(:quote, Expr(:block,
                                                 importexpr(mod),
                                                 expr)))))
    end
    nothing
  end
end
