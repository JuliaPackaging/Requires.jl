using Base: PkgId, loaded_modules, package_callbacks
using Base.Meta: isexpr

export @require

isprecompiling() = ccall(:jl_generating_output, Cint, ()) == 1

loaded(pkg) = haskey(Base.loaded_modules, pkg)

const notified_pkgs = [Base.PkgId(UUID(0x295af30fe4ad537b898300126c2a3abe), "Revise")]

const _callbacks = Dict{PkgId, Vector{Function}}()
callbacks(pkg) = get!(Vector{Function}, _callbacks, pkg)

listenpkg(@nospecialize(f), pkg) =
  loaded(pkg) ? f() : push!(callbacks(pkg), f)

function loadpkg(pkg::Base.PkgId)
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
  catch exc
    @warn "Error requiring `$mod` from `$listener`" exception=(exc,catch_backtrace())
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

function withnotifications(@nospecialize(args...))
  for id in notified_pkgs
    if loaded(id)
      mod = Base.root_module(id)
      if isdefined(mod, :add_require)
        add_require = getfield(mod, :add_require)::Function
        add_require(args...)
      end
    end
  end
  return nothing
end

function replace_include(ex, source::LineNumberNode)
  if isexpr(ex, :call) && ex.args[1] == :include && ex.args[2] isa String
    return Expr(:macrocall, :($Requires.$(Symbol("@include"))), source, ex.args[2])
  elseif ex isa Expr
      v = Vector{Any}(undef, length(ex.args))
      for i in 1:length(ex.args)
          v[i] = replace_include(ex.args[i], source)
      end
      ex = Expr(ex.head)
      ex.args = v
      ex
  else
    return ex
  end
end

macro require(pkg, expr)
  pkg isa Symbol &&
    return Expr(:macrocall, Symbol("@warn"), __source__,
                "Requires now needs a UUID; please see the readme for changes in 0.7.")
  id, modname = parsepkg(pkg)
  pkg = :(Base.PkgId(Base.UUID($id), $modname))
  expr = replace_include(expr, __source__)
  expr = macroexpand(__module__, expr)
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
