# ReAnimation.jl: Fully fledged animation system

Reanimation.jl is an animation system in julia. It offer all the features you need in order to create animations 
for your programs.

## Installation

```julia
julia> ]add ReAnimation
```

For the development version

```julia
julia> ]add https://github.com/Gesee-y/ReAnimation.jl
```

## Features

* **Keyframing**
* Large set of **interpolations** and **easing** (Linear, Quadratic, Elastic, Back, and more!)
* **Bindings**: Directly bind an animation to a field of a mutable struct, array or dict for direct modification.
* **Animation frame**: For quick animations.
* **Animation sequence**: A set of animation frame, each with his own transition and data.
* **Animation player**: It wrap an animation and give you full control over over it (play/paus, seek, etc)
* **Tracks**: Let you play animations relying on multiple other player with full control

## Example

```julia
using Reanimation

mutable struct Position
	x::Float64
end

pos = Position(5.0)

k1 = @keyframe 0.25 => 50
anim = @animationframe 0 => 10 0.5 => 15 LinearTransition()

binding = AbstractBinding(anim, pos, :x)

at!(binding, 0.25)
println(pos) # Position(12.5)
```

## License

This project is given under the MIT License.

## Bug Report

Don't hesitate to leave an issue if you encounter some bug.