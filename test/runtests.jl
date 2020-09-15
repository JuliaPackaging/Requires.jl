using Test

function writepkg(name, precomp::Bool, sub::Union{Symbol, Nothing})
    action = """
        global flag = true
    """

    if sub === :module
        sub_action = """
            export SubModule
            module SubModule
                using Colors
                flag = true
            end
        """
    elseif sub === :file
        sub_action = """
            global subflag = false
            @init begin
                global subflag = true
            end
        """
    end
    @assert sub === :module || sub === :file || sub === nothing

    if sub !== nothing
        open("$(name)_sub.jl", "w") do io
            println(io, sub_action)
        end

        action *= """
            include("$(name)_sub.jl")
        """
    end

    open("$name.jl", "w") do io
        println(io, """
__precompile__($precomp)

module $name

using Requires

flag = false

@init @require Colors="5ae59095-9a9b-59fe-a467-6f913c188581" begin
    $(action)
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
                writepkg("FooNPC", false, nothing)
            end
            npcdir = joinpath("FooPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooPC", true, nothing)
            end
            npcdir = joinpath("FooSubModNPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooSubModNPC", false, :module)
            end
            npcdir = joinpath("FooSubModPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooSubModPC", true, :module)
            end
            npcdir = joinpath("FooSubIncNPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooSubIncNPC", false, :file)
            end
            npcdir = joinpath("FooSubIncPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooSubIncPC", true, :file)
            end
        end
        push!(LOAD_PATH, pkgsdir)

        @eval using FooNPC
        @test !FooNPC.flag
        @eval using FooPC
        @test !FooPC.flag
        @eval using FooSubModNPC
        @test !(:SubModule in names(FooSubModNPC))
        @eval using FooSubModPC
        @test !(:SubModule in names(FooSubModPC))
        @eval using FooSubIncPC
        @test !isdefined(FooSubIncPC, :subflag)
        @eval using FooSubIncNPC
        @test !isdefined(FooSubIncNPC, :subflag)

        @eval using Colors

        @test FooNPC.flag
        @test FooPC.flag
        @test :SubModule in names(FooSubModNPC)
        @test FooSubModNPC.SubModule.flag
        @test :SubModule in names(FooSubModPC)
        @test FooSubModPC.SubModule.flag
        @test_broken FooSubIncPC.subflag
        @test_broken FooSubIncNPC.subflag

        cd(pkgsdir) do
            npcdir = joinpath("FooAfterNPC", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("FooAfterNPC", false, nothing)
            end
            pcidr = joinpath("FooAfterPC", "src")
            mkpath(pcidr)
            cd(pcidr) do
                writepkg("FooAfterPC", true, nothing)
            end
            sanpcdir = joinpath("FooSubModAfterNPC", "src")
            mkpath(sanpcdir)
            cd(sanpcdir) do
                writepkg("FooSubModAfterNPC", false, :module)
            end
            sapcdir = joinpath("FooSubModAfterPC", "src")
            mkpath(sapcdir)
            cd(sapcdir) do
                writepkg("FooSubModAfterPC", true, :module)
            end
            sanpcdir = joinpath("FooSubIncAfterNPC", "src")
            mkpath(sanpcdir)
            cd(sanpcdir) do
                writepkg("FooSubIncAfterNPC", false, :file)
            end
            sapcdir = joinpath("FooSubIncAfterPC", "src")
            mkpath(sapcdir)
            cd(sapcdir) do
                writepkg("FooSubIncAfterPC", true, :file)
            end
        end

        @eval using FooAfterNPC
        @eval using FooAfterPC
        @eval using FooSubModAfterNPC
        @eval using FooSubModAfterPC
        @eval using FooSubIncAfterNPC
        @eval using FooSubIncModAfterPC
        @test FooAfterNPC.flag
        @test FooAfterPC.flag
        @test :SubModule in names(FooSubModAfterNPC)
        @test FooSubModAfterNPC.SubModule.flag
        @test :SubModule in names(FooSubModAfterPC)
        @test FooSubModAfterPC.SubModule.flag
        @test FooSubIncAfterPC.subflag
        @test FooSubIncAfterNPC.subflag

    end
end
