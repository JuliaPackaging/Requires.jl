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
        local rm_CachedIncludeTest_submod_file
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
            npcdir = joinpath("CachedIncludeTest", "src")
            mkpath(npcdir)
            cd(npcdir) do
                writepkg("CachedIncludeTest", true, true)
                submod_file = abspath("CachedIncludeTest_submod.jl")
                @test isfile(submod_file)
                rm_CachedIncludeTest_submod_file = ()->rm(submod_file)
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
        @eval using CachedIncludeTest
        # Test that the content of the file which defines
        # CachedIncludeTest.SubModule is cached by `@require` so it can be used
        # even when the file itself is removed.
        rm_CachedIncludeTest_submod_file()
        @test !(:SubModule in names(CachedIncludeTest))

        @eval using Colors

        @test FooNPC.flag
        @test FooPC.flag
        @test :SubModule in names(FooSubNPC)
        @test FooSubNPC.SubModule.flag
        @test :SubModule in names(FooSubPC)
        @test FooSubPC.SubModule.flag
        @test :SubModule in names(CachedIncludeTest)

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

        pop!(LOAD_PATH)

        @test FooAfterNPC.flag
        @test FooAfterPC.flag
        @test :SubModule in names(FooSubAfterNPC)
        @test FooSubAfterNPC.SubModule.flag
        @test :SubModule in names(FooSubAfterPC)
        @test FooSubAfterPC.SubModule.flag
    end
end

module EvalModule end

@testset "Notifications" begin
    push!(LOAD_PATH, joinpath(@__DIR__, "pkgs"))
    @eval using NotifyMe

    mktempdir() do pkgsdir
        ndir = joinpath("NotifyTarget", "src")
        cd(pkgsdir) do
            mkpath(ndir)
            cd(ndir) do
                open("NotifyTarget.jl", "w") do io
                    println(io, """
                    module NotifyTarget
                        using Requires
                        function __init__()
                            @require Example="7876af07-990d-54b4-ab0e-23690620f79a" begin
                                f(x) = 2x
                            end
                        end
                    end
                    """)
                end
            end
        end
        push!(LOAD_PATH, pkgsdir)
        @test isempty(NotifyMe.notified_args)
        @eval using NotifyTarget
        @test isempty(NotifyMe.notified_args)
        @eval using Example
        @test length(NotifyMe.notified_args) == 1
        nargs = NotifyMe.notified_args[1]
        @test nargs[1] == joinpath(pkgsdir, ndir, "NotifyTarget.jl")
        @test nargs[2] == NotifyTarget
        @test nargs[3] == "7876af07-990d-54b4-ab0e-23690620f79a"
        @test nargs[4] == "Example"
        Core.eval(EvalModule, nargs[5])
        @test Base.invokelatest(EvalModule.f, 3) == 6
    end

    pop!(LOAD_PATH)
end
