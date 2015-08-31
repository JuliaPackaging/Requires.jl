export @require

isprecompiling() = VERSION > v"v0.4-" && ccall(:jl_generating_output, Cint, ()) == 1

if VERSION < v"0.4-"
  Base.split(xs, x; keep=false) = split(xs, x, false)
end

@init if VERSION < v"0.4-"

  function Base.require(s::ASCIIString)
    invoke(require, (String,), s)
    loadmod(s)
  end

else
  eval(Base, quote
    import MacroTools, Requires
  end)
  eval(Base, quote

  MacroTools.@hook function require(s::Symbol)
    super(s)
    Requires.loadmod(string(s))
  end

  end)
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

function withpath(f, path)
  tls = task_local_storage()
  hassource = haskey(tls, :SOURCE_PATH)
  hassource && (path′ = tls[:SOURCE_PATH])
  tls[:SOURCE_PATH] = path
  try
    return f()
  finally
    hassource ?
      (tls[:SOURCE_PATH] = path′) :
      delete!(tls, :SOURCE_PATH)
  end
end

macro require(mod, expr)
  ex = quote
    listenmod($(string(mod))) do
      withpath(@__FILE__) do
        $(esc(Expr(:call, :eval, Expr(:quote, Expr(:block,
        importexpr(mod),
        expr)))))
      end
    end
  end
  quote
    if isprecompiling()
      @init $(ex)
    else
      $(ex)
    end
  end
end
