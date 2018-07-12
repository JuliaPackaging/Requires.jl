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

function err(f, listener, mod)
  try
    f()
  catch e
    @warn """
      Error requiring $mod from $listener:
      $(sprint(showerror, e, catch_backtrace()))
      """
  end
end

function parsepkg(ex)
  isexpr(ex, :(=)) || @goto fail
  mod, id = ex.args
  (mod isa Symbol && id isa String) || @goto fail
  return id, String(mod)
  @label fail
  error("Requires syntax is: `@require Pkg=\"uuid\"`")
end

macro require(pkg, expr)
  pkg isa Symbol &&
    return Expr(:macrocall, Symbol("@warn"), __source__,
                "Requires now needs a UUID; please see the readme for changes in 0.7.")
  id, modname = parsepkg(pkg)
  pkg = :(Base.PkgId(Base.UUID($id), $modname))
  quote
    if !isprecompiling()
      listenpkg($pkg) do
        withpath($(string(__source__.file))) do
          err($__module__, $modname) do
            $(esc(:(eval($(Expr(:quote, Expr(:block,
                                            :(const $(Symbol(modname)) = Base.require($pkg)),
                                            expr)))))))
          end
        end
      end
    end
  end
end
