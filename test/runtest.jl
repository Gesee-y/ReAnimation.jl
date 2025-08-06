include(joinpath("..","src","Reanimation.jl"))

using .Reanimation
using BenchmarkTools

mutable struct Position
	x::Float64
end

pos = Position(5.0)

k1 = @keyframe 0.25 => 50
anim = @animationframe 0 => 10 0.5 => 15 LinearTransition()

binding = AbstractBinding(anim, pos, :x)

println(pos)
at!(binding, 0.25)
@btime at!($binding, 0.25)
@btime at!($binding, 0.75)
@btime at($anim, 0.25)
println(pos)
println(k1)
println(anim)

