module Foo

using Requires, Test

beforeflag = false
afterflag = false

@require JSON="682c06a0-de6a-54ab-a142-c8b1cf79cde6" global beforeflag = true

@test !beforeflag
using JSON
@test beforeflag

@require JSON="682c06a0-de6a-54ab-a142-c8b1cf79cde6" global afterflag = true

@test afterflag

end
