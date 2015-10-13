export @init

macro definit()
  quote
    if !isdefined(:__inits__)
      const $(esc(:__inits__)) = Function[]
    end
    if !isdefined(:__init__)
      $(esc(:__init__))() = @init
    end
  end
end

function initm(ex)
  quote
    @definit
    push!($(esc(:__inits__)), () -> $(esc(ex)))
    nothing
  end
end

function initm()
  :(for f in __inits__
      f()
    end) |> esc
end

macro init(args...)
  initm(args...)
end

"Prevent init fns being called multiple times during precompilation."
macro guard(ex)
  :(!isprecompiling() && $(esc(ex)))
end
