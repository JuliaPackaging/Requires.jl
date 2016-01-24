using MacroTools

macro hook(ex)
  @capture(shortdef(ex), f_(args__) = body_) || error("Invalid hook $ex")
  sig = map(args) do arg
    @match arg begin
      _::T_... => :(Vararg{$(esc(T))})
      _... => :(Vararg{Any})
      _::T_ => esc(T)
      _     => :Any
    end
  end
  sig = :($(sig...),)
  quote
    let $(esc(:super)) = which($(esc(f)), $sig).func
      $(esc(:(function $f($(args...))
        $body
      end)))
    end
  end
end
