using Base.Meta: isexpr

export @require

isprecompiling() = ccall(:jl_generating_output, Cint, ()) == 1

@init begin
  push!(Base.package_callbacks, loadmod)
end

loaded(mod::Symbol) = getthing(Main, mod) != nothing

const modlisteners = Dict{Symbol, Vector{Function}}()

listenmod(f, mod::Symbol) =
  loaded(mod) ? f() :
    modlisteners[mod] = push!(get(modlisteners, mod, Function[]), f)

function loadmod(mod)
  fs = get(modlisteners, mod, Function[])
  delete!(modlisteners, mod)
  map(f->Base.invokelatest(f), fs)
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
  isexpr(mod, :(=)) && (mod = mod.args[1])
  ex = quote
    listenmod($(QuoteNode(mod))) do
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
