using Test

function writepkg(name, precomp::Bool)
    open("$name.jl", "w") do io
        println(io, """
__precompile__($precomp)

module $name

using Requires

flag = false

function __init__()
    @require JSON="682c06a0-de6a-54ab-a142-c8b1cf79cde6" global flag = true
end

end
""")
    end
end

@testset "Requires" begin
    mktempdir() do pkgsdir
        cd(pkgsdir) do
            npcdir = joinpath("FooNPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooNPC", false)
            end
            npcdir = joinpath("FooPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooPC", true)
            end
        end
        push!(LOAD_PATH, pkgsdir)

        @eval using FooNPC
        @test !FooNPC.flag
        @eval using FooPC
        @test !FooPC.flag

        @eval using JSON

        @test FooNPC.flag
        @test FooPC.flag

        cd(pkgsdir) do
            npcdir = joinpath("FooAfterNPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooAfterNPC", false)
            end
            pcidr = joinpath("FooAfterPC", "src")
            mkpath(pcidr)
            cd(pcidr) do
                writepkg("FooAfterPC", true)
            end
        end

        @eval using FooAfterNPC
        @eval using FooAfterPC
        @test FooAfterNPC.flag
        @test FooAfterPC.flag
    end
end
