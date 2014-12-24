export @lazymod

function lazymod(mod)
  quote
    function $(symbol(lowercase(string(mod))))()
      require($(string(mod)))
      $mod
    end
  end |> esc
end

function lazymod (mod, path)
  quote
    function $(symbol(lowercase(string(mod))))()
      if !isdefined($(current_module()), $(Expr(:quote, mod)))
        includehere(path) = eval(Expr(:call, :include, path))
        includehere(joinpath(dirname(@__FILE__), $path))
        loadmod(string($mod))
      end
      $mod
    end
  end |> esc
end

macro lazymod (args...)
  lazymod(args...)
end
