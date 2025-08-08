# ReAnimation.jl

ReAnimation provides all the necessary features for your animations.
Here we will walk you through all the features provided in this package.

## Keyframing

Keyframes are the main instants of your animation. It's the value it should have at a given time no matter how we are animating.
To define a keyframe, you can use the macro syntax `@keyframe t => v` or you can do it manually with `Keyframe(t, v)`.
Note that keyframes are immutable structs so once created, you can't modify them. You can specify the type of a keyframe with `Keyframe{T}(t,v)`. This is useful when you are animating to cover a broader range of types.

```julia
using ReAnimation

# Keyframes' types will be inferred from the values unless explicitly specified
k1 = @keyframe 0 => 5
k2 = Keyframe(0, 5)
k3 = Keyframe{Float32}(0, 5) # 5 will automatically be converted
```

## Animation frames

Keyframes alone are kinda useless; their purpose is to be given to a frame, represented as a `KFAnimationFrame`.
An animation frame is just one transition from a keyframe A to a keyframe B with the given transition and easing.

### Transitions

*In this section, we refer to A as the starting keyframe and to B as the ending keyframe*
A transition is how your animation should move from keyframe A to keyframe B. Multiple transitions are defined by default in ReAnimation, such as:

* `LinearTransition()`:
  Linear interpolation from A to B

* `StepTransition(t)`:
  Returns A’s value until the animation time exceeds `t`, then instantly switches to B’s value

* `Smoothstep(t, transition)`:
  Returns A’s value until time `t`, then applies the given `transition` from A to B

* `ElasticTransition(amp, period)`:
  This transition simulates an elastic oscillation effect where the animation overshoots the target value and then bounces back several times before settling.

  * `amp` controls the amplitude (strength) of the oscillations
  * `period` determines the frequency (speed) of the bounces

* `BounceTransition(n)`:
  This transition mimics a physical bounce: the animation approaches the target value, then rebounds multiple times with decreasing amplitude before coming to rest.

  * `n` is the number of bounces during the animation

* `BackTransition(s)`:
  This transition starts by moving slightly backward (opposite to the direction of the animation) before accelerating forward to the target value.

  * `s` controls the intensity of this initial backward movement (higher values create a stronger pullback)

* `SpringTransition(damping, freq)`:
  This transition simulates a damped spring motion, oscillating around the target value with gradually decreasing amplitude.

  * `damping` controls how quickly the oscillations fade out (higher values damp faster)
  * `freq` sets the frequency of the spring oscillations

* `SmoothTransition()`:
  A smooth interpolation that applies gentle acceleration and deceleration, producing a fluid transition between values without abrupt changes.

* `SmootherTransition()`:
  Similar to `SmoothTransition`, but with an even more gradual and refined curve that further minimizes abrupt changes in acceleration.

* `QuinticTransition()`:
  Uses a fifth-degree polynomial interpolation to produce an extremely smooth transition, ensuring zero derivatives at the endpoints for natural acceleration and deceleration.

Transitions are functors (callable objects), so to use them, you use `transition(a,b,t)` where `transition` is a Transition you created, `a` is the starting point, `b` is the endpoint and `t` is the time in the range \[0,1].

Note that for a transition to work for a given type, it should support the following operations: `+`, `-`, `*`, `^`.

### Easing

Easing is how the time of your animation should behave. Following the easing, your animation may go slower, faster, smoother or weirder. So you should choose the effect you want.

* `NoEase()`:
  No easing is applied; time progresses linearly. The animation speed is constant throughout.

* `EaseIn{N}()`:
  The animation starts slowly and accelerates towards the end.

  * `N` represents the degree of the polynomial used to shape the easing curve, controlling how pronounced the acceleration is.

* `EaseOut{N}()`:
  The animation starts quickly and decelerates towards the end.

  * `N` controls the degree of the polynomial, affecting the sharpness of the slowdown.

* `EaseInOut{N}()`:
  The animation starts slowly, accelerates in the middle, and then slows down again towards the end.

  * `N` defines the polynomial degree, influencing the smoothness of both acceleration and deceleration phases.

* `ElasticEase(amp, period)`:
  Creates an elastic easing effect where the animation overshoots its target multiple times before settling.

  * `amp` controls the amplitude of the overshoot
  * `period` sets the frequency of the oscillations

* `BounceEase()`:
  Simulates a bouncing effect where the animation rapidly approaches the target, bounces back several times, and finally settles.

* `BackEase(s)`:
  The animation initially reverses direction slightly before moving forward, creating a “pullback” effect.

  * `s` controls the magnitude of this initial backward movement.

* `SineEase()`:
  Uses a sine wave to create a smooth, natural easing with gentle acceleration and deceleration.

* `CircEase()`:
  Employs a circular function to produce easing with a smooth curve that accelerates and decelerates in a more pronounced way than sine easing.

* `ExponentialEase(base::Int)`:
  The animation accelerates or decelerates exponentially, providing a dramatic speed change.

  * `base` is the exponent base controlling the steepness of the curve.

* `QuinticEase()`:
  Uses a fifth-degree polynomial for an extremely smooth easing curve with gentle start and end transitions.

Eases are functors (callable objects), so to use them, you use `ease(t)` where `ease` is an Ease you created and `t` is the time on which it should apply.

### Back to our frame

Now in order to create an animation frame, you just use the macro `@animationframe t1 => v1 t2 => v2 [transition] [ease]` or you can use the manual `KFAnimationFrame(k1::Keyframe{T}, k2::Keyframe{T}, transition=LinearTransition(), ease=NoEase())`.
Once you have created a frame you are finally able to animate. You can get the value of the frame at a given time with `at(frame, t)`. You can also use broadcasting to get it as an array.
You can also get the duration of the animation with `duration(anim)`.

You can also run a frame asynchronously and use a function to react to each modification with `animate(f::Function, frames...; duration, fps=60)`

```julia
frame = @animationframe 0 => 10 0.5 => 15 LinearTransition() NoEase()
p = at(frame, 0.1) # 11.0
animate(frame; duration=0.25) do t, v
    println("At time $t, the frame value is $v.")
end
```

## Bindings

You can bind an animation to a field of a mutable struct, so when updating the animation, the field is automatically set.
To create a new binding use `AbstractBinding(frame, obj, field)`. This also works for arrays (you will pass an index instead of a field) and dictionaries (you will pass a key of that dictionary).
You can then use `at!` on that binding to automatically set the property to the one of the frame at the given time.
You can also use `animate!` to asynchronously set the value of the object according to the frame.

```julia
mutable struct Position
    x::Float64
end

pos = Position(5.0)
frame = @animationframe 0 => 10 0.5 => 15 LinearTransition() NoEase()

binding = AbstractBinding(frame, pos, :x)

at!(binding, 0.1) # Now pos.x is 11.0

animate!(binding; duration=0.25, fps=30) # pos.x will be updated 30 times per second until we reach the given duration
```

## Animations

Until now, we have just played around with animation frames but real animations often require more than just going from point A to point B; we want to go through multiple points. For that we use `RAnimation` which contains a sequence of frames to form an animation.

To create a new animation, you use `RAnimation(frames...; loop=1)`. You can also pass a vector of frames as the first argument.

Once you create an animation, you can use `at` to get the value at a given time and `animate` the same way we saw with frames.

You can also use bindings with animations in the same manner as we did with frames.

```julia
mutable struct Position
    x::Float64
end

pos = Position(5.0)
animation = RAnimation((@animationframe 0 => 10 0.5 => 15 LinearTransition() NoEase()), # We wrap in parentheses to explicitly show to the Julia compiler that macro stops there
    @animationframe 0.5 => 15 1.75 => 105 BounceTransition(5) EaseIn{2}())

binding = AbstractBinding(animation, pos, :x)

at!(binding, 0.1) # Now pos.x is 11.0

animate!(binding; duration=0.25, fps=30) # pos.x will be updated 30 times per second until we reach the given duration
```

## Players

Sometimes, you want to have more control on animations: speed them up, slow them down, jump to a given position, etc. For that you use an `RPlayer` which will give you full control on your animation.
Note that a player uses a binding to work since that's what will get updated at each step.

To create a new one, use `RPlayer(anim::RAnimation, obj, field; speed=1.0, loop=Once, on_finish=nothing, on_loop=nothing)`.

Let me explain everything:

* `anim` is the animation on which you want full control
* `obj` and `field` will be used to construct the binding to `anim`
* `speed=1.0` is the multiplier of the animation; the greater it is, the faster the animation will seem
* `loop=Once` indicates if the animation should loop once done. It accepts one of the `LoopMode` enum: `Loop`, `Once`, `PingPong`
* `on_finish=nothing` is the function to call once we reached the end of the animation. `nothing` means we will not call anything
* `on_loop=nothing` is the function to call each time a new loop is started

You can also directly pass a binding to the player instead of an animation, an object and a field.

You can move the player forward with `update!(player, dt)` where `dt` is how much you want the animation to move forward.
If you want the animation to update asynchronously, you can use `runasync!(player; fps=60)`, it's similar to `animate!`.

You can use all the following functions on `RPlayer`:

* `seek!(p::RPlayer, t::Real)`
* `seek_relative!(p::RPlayer, Δ::Real)`
* `pause!(p::RPlayer)`
* `reset!(p::RPlayer)`
* `resume!(p::RPlayer)`
* `reverse!(p::RPlayer)`
* `speed!(p::RPlayer, s::Real)`
* `loop_mode!(p::RPlayer, m::LoopMode)`
* `isfinish(p::RPlayer)`

```julia
# We will assume you have already created an animation named `anim`

mutable struct Position
    x::Float64
end

pos = Position(5.0)

player = RPlayer(anim, pos, :x) # By default, new RPlayers are paused, you have to call `resume!` on them
runasync!(player; fps = 20)
sleep(0.1)

pause!(player)
sleep(0.1)

seek!(player, 0)
resume!(player)
```

## Tracks

*In the next part, we use 'track' to refer to one `RPlayer` contained in a `TrackManager`*
Sometimes, even players aren't enough; you want multiple players to evolve at the same pace, and doing so asynchronously is a real pain.


So this package provides you a `TrackManager` which allows you to play multiple `RPlayer`s at the same pace to form one big animation. To use it, it's pretty simple: you create a new manager with `TrackManager(;speed=1.0)` where speed is the global speed multiplier of the animation.

Once it's done, you use `bind_track!(tm::TrackManager, player::RPlayer)` to add a new track. It's recommended to bind tracks at load time to avoid inconsistencies or to reset the track manager with `reset!` after you have added a track.

After that, you can use the following functions on a track manager:

* `seek!(p::TrackManager, t::Real)`
* `seek_relative!(p::TrackManager, Δ::Real)`
* `pause!(p::TrackManager)`
* `reset!(p::TrackManager)`
* `resume!(p::TrackManager)`
* `speed!(p::TrackManager, s::Real)`

You can then update all the tracks with `update!(tm::TrackManager, dt)` where `dt` is how much the animation should move forward.
You can run the animations asynchronously with `runasync!(tm::TrackManager; fps=60)`.

```julia
# We suppose you have created 2 players named 'player1' and 'player2'

tm = TrackManager()

bind_track!(tm, :positionX, player1)
bind_track!(tm, :positionY, player2)

resume!(tm) # By default, track managers are paused when created

update!(tm, 0.25)
runasync!(tm; fps=30)
```

## What's next

You now know everything about this package. There are some experimental features such as `AnimationLayer` but they are not ready yet.
In the next update, we will introduce `AnimationGraph`, `BlendTree` and more.
