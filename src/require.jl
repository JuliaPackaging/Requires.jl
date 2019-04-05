using Base: PkgId, loaded_modules, package_callbacks, @get!
using Base.Meta: isexpr

export @require

isprecompiling() = ccall(:jl_generating_output, Cint, ()) == 1

loaded(pkg) = haskey(Base.loaded_modules, pkg)

const _callbacks = Dict{PkgId, Vector{Function}}()
callbacks(pkg) = @get!(_callbacks, pkg, [])

listenpkg(f, pkg) =
  loaded(pkg) ? f() : push!(callbacks(pkg), f)

function loadpkg(pkg)
  fs = callbacks(pkg)
  delete!(_callbacks, pkg)
  map(f->Base.invokelatest(f), fs)
end

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

function err(f, listener, mod, rethrowerror)
  try
    f()
  catch e
    @warn """
      Error requiring $mod from $listener:
      $(sprint(showerror, e, catch_backtrace()))
      """
    rethrowerror && rethrow(e)
  end
end

function parsepkg(ex)
  isexpr(ex, :(=)) || @goto fail
  mod, id = ex.args
  (mod isa Symbol && id isa String) || @goto fail
  return id, String(mod)
  @label fail
  error("Requires syntax is: `@require Pkg=\"uuid\" [rethrowerror=false]`")
end

function parserethrow(ex)
  isexpr(ex, :(=)) || @goto fail
  kw, flg = ex.args
  (kw == :rethrow && flg isa Bool) || @goto fail
  return flg
  @label fail
  error("Requires syntax is: `@require Pkg=\"uuid\" [rethrowerror=false]`")
end

macro require(pkg, args...)
  rethrowerror = false
  if length(args) == 2
    rethrowerror = parserethrow(args[1])
    expr = args[2]
  else
    expr = args[1]
  end

  pkg isa Symbol &&
    return Expr(:macrocall, Symbol("@warn"), __source__,
                "Requires now needs a UUID; please see the readme for changes in 0.7.")
  id, modname = parsepkg(pkg)
  pkg = :(Base.PkgId(Base.UUID($id), $modname))
  quote
    if !isprecompiling()
      listenpkg($pkg) do
        withpath($(string(__source__.file))) do
          err($__module__, $modname, $rethrowerror) do
            $(esc(:(eval($(Expr(:quote, Expr(:block,
                                            :(const $(Symbol(modname)) = Base.require($pkg)),
                                            expr)))))))
          end
        end
      end
    end
  end
end
