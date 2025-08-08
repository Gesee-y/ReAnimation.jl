#####################################################################################################################
################################################### ANIMATION FRAMES ################################################
#####################################################################################################################

export AbstractFrame
export KFAnimationFrame
export @animationframe
export at, get_animation_array, duration, animate, stop

######################################################### CORE ########################################################

abstract type AbstractFrame <: AbstractAnimation end

mutable struct KFAnimationFrame{T,TR,EA} <: AbstractFrame
	k1::Keyframe{T}
	k2::Keyframe{T}
	transition::TR
    ease::EA
	loop::Int

	## Constructors

	function KFAnimationFrame(k1::Keyframe{T}, k2::Keyframe{T}, tr::TR=LinearTransition(),
        ease::EA=NoEase(), loop=1) where {T,TR<:AbstractTransition,EA<:AbstractEase}
		
		keytime(k1) > keytime(k2) && error("Keyframe 1 must be earlier than keyframe 2")
		loop < 0 && error("Can't take less than zero loops.")

		return new{T,TR,EA}(k1,k2,tr,ease,loop)
	end
end

macro animationframe(args...)
    loop = 1
    idx  = 1
    if length(args) ≥ 1 && args[1] isa Expr && args[1].head == :(=) && args[1].args[1] == :loop
        loop = args[1].args[2]
        idx  = 2
    end

    length(args) ≥ idx+1 || error("@animationframe should have `[loop=n] t1=>v1 t2=>v2 [transition]`")
    
    k1, k2 = args[idx], args[idx+1]

    for pair in (k1, k2)
        pair isa Expr && pair.head == :call && pair.args[1] == :(=>) ||
            error("Keyframes should be `t => value`")
    end
    t1, v1 = k1.args[2], k1.args[3]
    t2, v2 = k2.args[2], k2.args[3]
    
    if length(args) < idx+2
        return :(KFAnimationFrame(
            Keyframe($(esc(t1)), $(esc(v1))),
            Keyframe($(esc(t2)), $(esc(v2)))
        ))
    elseif length(args) == idx+2
        trans = args[idx+2]
        return :(KFAnimationFrame(
            Keyframe($(esc(t1)), $(esc(v1))),
            Keyframe($(esc(t2)), $(esc(v2))),
            $(esc(trans))
        ))
    elseif length(args) == idx+3
        trans = args[idx+2]
        ease = args[idx+3]
        return :(KFAnimationFrame(
            Keyframe($(esc(t1)), $(esc(v1))),
            Keyframe($(esc(t2)), $(esc(v2))),
            $(esc(trans)),
            $(esc(ease))
        ))
    end
end

#################################################### FUNCTIONS #######################################################

duration(frame::KFAnimationFrame)::Float64 = (keytime(frame.k2) - keytime(frame.k1))
function at(frame::KFAnimationFrame{T}, t::Real) where T
    t_total = duration(frame)
    t_loop = t_total * frame.loop
    current_loop = t ÷ t_total
    t_clamped = clamp(t, zero(t), t_loop)
    t_local = (current_loop < frame.loop) ? mod(t_clamped, t_total) : t_total
    t_norm = t_local / t_total
    frame.transition(value(frame.k1), value(frame.k2), frame.ease(t_norm))
end

function get_animation_array(frame::KFAnimationFrame{T}, len::Integer,
                             start::Real = 0.0,
                             current_loop::Integer = 1) where T
    len ≤ 0 && return T[]

    remaining_loops = max(frame.loop - current_loop + 1, 0)
    frames = Vector{T}(undef, len * remaining_loops)

    idx = 1
    for _ in 1:remaining_loops
        for t in range(0.0, 1.0, length=len)
            frames[idx] = at(frame, start + t * duration(frame))
            idx += 1
        end
    end
    return frames
end

function sleep_ns(t::Real;sec=true)
    factor = sec ? 10 ^ 9 : 1
    t = UInt(floor(Float32(t)*10^9))

    t1 = time_ns()
    while true
        if time_ns() - t1 >= t
            break
        end
        yield()
    end
end

######## Borrowed from Animations.jl


"""
    animate_async(f::Function, anims::FiniteLengthAnimation...; duration::Real, fps::Int = 30)

Start an asynchronous animation where in each frame `f` is called with the current
animation time as well as the current value of each `Animation` in `anims`.

Returns an `AnimationTask` which can be stopped with `stop(animationtask)`.

Example:

    animate(anim1, anim2) do t, a1, a2
        # do something (e.g. with a plot or other visual object)
    end
"""
function animate(f::Function, anims::AbstractAnimation...;
        duration = maximum(duration, anims),
        fps::Int = 60)

    frameduration = 1 / fps

    t_start = time()
    t_target = t_start

    interrupt_switch = Ref(false)

    task = @async_showerr while !interrupt_switch[]

        t_current = time()
        t_relative = t_current - t_start

        f(t_relative, (at(a,t_relative) for a in anims)...)

        if t_relative >= duration
            break
        end

        # always try to hit the next target exactly one frame duration away from
        # the last to avoid drift
        t_target += frameduration
        sleeptime = t_target - time()
        sleep_ns(max(0.001, sleeptime))
    end

    AnimationTask(task, interrupt_switch)
end

"""
    stop(at::AnimationTask)

Stop a running `AnimationTask`. This only sets a flag for the animation loop to
exit, it won't kill a task that is stuck. You can manipulate the `Task` stored
in the `AnimationTask` directly if you need more control.
"""
stop(at::AnimationTask) = at.interrupt_switch[] = true

Base.wait(at::AnimationTask) = wait(at.task)
