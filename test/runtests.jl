using Test

function writepkg(name, precomp::Bool, submod::Bool)
    action = """
        global flag = true
    """

    if submod
        open("$(name)_submod.jl", "w") do io
            println(io, """
                export SubModule
                module SubModule
                    using Colors
                    flag = true
                end
            """)
        end

        action *= """
            include("$(name)_submod.jl")
        """
    end

    open("$name.jl", "w") do io
        println(io, """
__precompile__($precomp)

module $name

using Requires

flag = false

function __init__()
    @require Colors="5ae59095-9a9b-59fe-a467-6f913c188581" begin
        $(action)
    end
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
                writepkg("FooNPC", false, false)
            end
            npcdir = joinpath("FooPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooPC", true, false)
            end
            npcdir = joinpath("FooSubNPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooSubNPC", false, true)
            end
            npcdir = joinpath("FooSubPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooSubPC", true, true)
            end
        end
        push!(LOAD_PATH, pkgsdir)

        @eval using FooNPC
        @test !FooNPC.flag
        @eval using FooPC
        @test !FooPC.flag
        @eval using FooSubNPC
        @test !(:SubModule in names(FooSubNPC))
        @eval using FooSubPC
        @test !(:SubModule in names(FooSubPC))

        @eval using Colors

        @test FooNPC.flag
        @test FooPC.flag
        @test :SubModule in names(FooSubNPC)
        @test FooSubNPC.SubModule.flag
        @test :SubModule in names(FooSubPC)
        @test FooSubPC.SubModule.flag

        cd(pkgsdir) do
            npcdir = joinpath("FooAfterNPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooAfterNPC", false, false)
            end
            pcidr = joinpath("FooAfterPC", "src")
            mkpath(pcidr)
            cd(pcidr) do
                writepkg("FooAfterPC", true, false)
            end
            sanpcdir = joinpath("FooSubAfterNPC", "src")
            mkpath(sanpcdir)
            cd(sanpcdir) do
                writepkg("FooSubAfterNPC", false, true)
            end
            sapcdir = joinpath("FooSubAfterPC", "src")
            mkpath(sapcdir)
            cd(sapcdir) do
                writepkg("FooSubAfterPC", true, true)
            end
        end

        @eval using FooAfterNPC
        @eval using FooAfterPC
        @eval using FooSubAfterNPC
        @eval using FooSubAfterPC
        @test FooAfterNPC.flag
        @test FooAfterPC.flag
        @test :SubModule in names(FooSubAfterNPC)
        @test FooSubAfterNPC.SubModule.flag
        @test :SubModule in names(FooSubAfterPC)
        @test FooSubAfterPC.SubModule.flag
    end
end
