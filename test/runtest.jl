include(joinpath("..","src","ReAnimation.jl"))

using .ReAnimation
using BenchmarkTools
using Test

mutable struct Position
	x::Float64
	y::Float64
end

@testset "Creation" begin
	k1 = @keyframe 0.25 => 50
	anim = @animationframe 0 => 10 0.5 => 15 LinearTransition() NoEase()

	@test keytime(k1) == 0.25
	@test value(k1) == 50
	@test at(anim, 0.25) == 12.5
end

@testset "Binding" begin
	pos = Position(5.0, 1.0)
	anim = @animationframe 0 => 10 0.5 => 15
	anim2 = @animationframe 0 => 10 0.5 => 15 BackTransition()
	binding = AbstractBinding(anim, pos, :x)
	binding2 = AbstractBinding(anim2, pos, :y)
    
    set!(binding, 10.0)

    @test pos.x == 10

    at!(binding, 0.1)
    at!(binding2, 0.1)
    @test pos.x == 11
    @test pos.y < 10
end

@testset "RAnimation" begin

	pos = Position(5.0,1.0)
	animation = RAnimation((@animationframe 0 => 10 0.5 => 15 LinearTransition() NoEase()),
	    @animationframe 0.5 => 15 1.75 => 105 BounceTransition(5) EaseIn{2}())

	binding = AbstractBinding(animation, pos, :x)

	@test at!(binding, 1) > 15
	
	task = animate!(binding; duration=0.25, fps=30)
	sleep(0.25) # Asynchrounous task aren't launched directly so we wait some time
	@test task isa AnimationTask
	@test istaskstarted(task.task)
    
	sleep(0.1)
    @test pos.x >= 12.5
    
    stop(task)
    sleep(0.1)
    @test istaskdone(task.task)
end

@testset "RPlayer" begin
    pos = Position(5.0,1.0)
	animation = RAnimation((@animationframe 0 => 10 0.5 => 15 LinearTransition() NoEase()),
	    @animationframe 0.5 => 15 1.75 => 105 BounceTransition(5) EaseIn{2}())

	player = RPlayer(animation, pos, :x)

	seek!(player, 0)

	@test pos.x == 10
    
    resume!(player)
	update!(player, 0.25)
	@test pos.x == 12.5

	task = runasync!(player; fps = 30)
	sleep(0.2)

	@test task isa AnimationTask
	@test istaskstarted(task.task)
    
	pause!(player)
    v1 = pos.x
	sleep(0.1)

	v2 = pos.x
	@test v1 == v2 != 10

	seek!(player, 0)
	@test pos.x == 10

	stop(task)
end
