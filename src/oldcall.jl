###
# Tasks are frozen at their worldage and we can use them
# to call previous versions of functions. The code below
# is taken from test/worlds.jl in JuliaLang/julia
###

# The maximum number of tasks that can be used for recursive
# loading, if Julia freezes it might be because this number
# is to low.
const MAX_TASKS = 16

function wfunc(channel)
  for (f, args, c) in channel
    try
      yield()
      f(args...)
      notify(c)
    catch err
      notify(c, val=err, error=true)
    end
  end
end

@init let (chnls, tasks) = Base.channeled_tasks(1, ntuple(i->wfunc, MAX_TASKS)...)
global oldcall
function oldcall(f, args...)
  c = Condition()
  put!(chnls[1], (f, args, c))
  wait(c)
end
end
