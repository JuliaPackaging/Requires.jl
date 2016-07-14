module Foo

using Requires
using Base.Test

beforeflag = false
afterflag = false

@require JSON global beforeflag = true

@test !beforeflag

using JSON

@test beforeflag

@require JSON global afterflag = true

@test afterflag

end
