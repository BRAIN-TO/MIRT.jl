# io/z-test.jl

using Test

@test caller_name(:test)
@test fld_read(:test)
@test fld_write(:test)
@test ir_dump(:test)
#@test loadpfile(:test)
@test prompt(:test)
