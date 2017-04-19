export @require, finishloading

isprecompiling() = ccall(:jl_generating_output, Cint, ()) == 1

@init begin
  ch = Channel{Symbol}(0)
  push!(Base.package_callbacks, (mod)-> push!(ch, Symbol(mod)))

  @schedule begin
    for mod in ch
      loadmod(string(mod))
    end
  end
end

"""
    finishloading(mod::Symbol) --> Channel

Returns a channel that can be waited upon to
check that a module has been successfully loaded.
"""
function finishloading(mod)
  # We have to use a channel to be stateful
  c = Channel(1)
  listenmod(String(mod)) do
    # be nice to people who use only wait
    push!(c, nothing)
    close(c)
  end
  return c
end

loaded(mod) = getthing(Main, mod) != nothing

const modlisteners = Dict{AbstractString,Vector{Function}}()

listenmod(f, mod) =
  loaded(mod) ? f() :
    modlisteners[mod] = push!(get(modlisteners, mod, Function[]), f)

function loadmod(mod)
  fs = get(modlisteners, mod, Function[])
  delete!(modlisteners, mod)
  map(f->eval(:($f())), fs)
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
