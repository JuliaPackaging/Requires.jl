module Foo

using Requires
using Base.Test

beforeflag = false
afterflag = false

@require JSON global beforeflag = true

@test !beforeflag

##
# loading a module is no longer blocking on listeners
# so to get the same control flow as on v0.5 we need
# to explicitly wait onf finishloading
##
cond = finishloading(:JSON)
using JSON
wait(cond)

@test beforeflag

@require JSON global afterflag = true

@test afterflag

end
