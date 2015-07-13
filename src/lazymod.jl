export @lazymod

function lazymod(mod)
  quote
    function $(symbol(lowercase(string(mod))))()
      require($(string(mod)))
      Main.$mod
    end
  end |> esc
end

function lazymod(mod, path)
  quote
    function $(mod |> symbol |> string |> lowercase |> symbol |> esc)()
      if !isdefined($(current_module()), $(Expr(:quote, mod)))
        includehere(path) = eval($(current_module()), Expr(:call, :include, path))
        includehere(joinpath(dirname(@__FILE__), $(esc(path))))
        loadmod(string($(esc(mod))))
      end
      $(esc(mod))
    end
  end
end

macro lazymod(args...)
  lazymod(args...)
end
