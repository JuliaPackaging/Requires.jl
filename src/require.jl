import Base: require

export @require

isprecompiling() = ccall(:jl_generating_output, Cint, ()) == 1

# We are overwriting `Base.require` here, which is a pretty
# horrible hack. Furthermore we need to not overwrite
# `Base.require` while precompiling (thus @guard) and we need
# to overwrite it in a world newer than the tasks in `oldcall.jl`
# Since `Base.require` uses `eval` it switches automatically into
# a newer world and call this `Base.require` from there.
# We need to repeatedly switch back into the old world.
@init @guard begin
  function Base.require(mod::Symbol)
    Main.Requires.oldcall(Base.require, mod)
    Main.Requires.loadmod(string(mod))
  end
end

loaded(mod) = getthing(Main, mod) != nothing

const modlisteners = Dict{AbstractString,Vector{Function}}()

listenmod(f, mod) =
  loaded(mod) ? f() :
    modlisteners[mod] = push!(get(modlisteners, mod, Function[]), f)

function loadmod(mod)
  fs = get(modlisteners, mod, Function[])
  delete!(modlisteners, mod)
  map(f->f(), fs)
end

importexpr(mod::Symbol) = Expr(:import, mod)
importexpr(mod::Expr) = Expr(:import, map(Symbol, split(string(mod), "."))...)

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

function err(f, listener, mod)
  try
    f()
  catch e
    warn("Error requiring $mod from $listener:")
    showerror(STDERR, e, catch_backtrace())
    println(STDERR)
  end
end

macro require(mod, expr)
  ex = quote
    listenmod($(string(mod))) do
      withpath(@__FILE__) do
        err($(current_module()), $(string(mod))) do
          $(esc(:(eval($(Expr(:quote, Expr(:block,
                                           importexpr(mod),
                                           expr)))))))
        end
      end
    end
  end
  quote
    if isprecompiling()
      @init @guard $(ex)
    else
      $(ex)
    end
  end
end
