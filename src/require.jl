using Base: PkgId, loaded_modules, package_callbacks, @get!
using Base.Meta: isexpr

export @require

isprecompiling() = ccall(:jl_generating_output, Cint, ()) == 1

loaded(pkg) = haskey(Base.loaded_modules, pkg)

const notified_pkgs = [Base.PkgId(UUID(0x295af30fe4ad537b898300126c2a3abe), "Revise")]

const _callbacks = Dict{PkgId, Vector{Function}}()
callbacks(pkg) = @get!(_callbacks, pkg, [])

listenpkg(@nospecialize(f), pkg) =
  loaded(pkg) ? f() : push!(callbacks(pkg), f)

function loadpkg(pkg)
  if haskey(_callbacks, pkg)
    fs = _callbacks[pkg]
    delete!(_callbacks, pkg)
    foreach(Base.invokelatest, fs)
  end
end

function withpath(@nospecialize(f), path)
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

function err(@nospecialize(f), listener, mod)
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

function withnotifications(args...)
  for id in notified_pkgs
    if loaded(id)
      mod = Base.root_module(id)
      if isdefined(mod, :add_require)
        add_require = getfield(mod, :add_require)
        add_require(args...)
      end
    end
  end
  return nothing
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
        $withnotifications($(string(__source__.file)), $__module__, $id, $modname, $(esc(Expr(:quote, expr))))
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
