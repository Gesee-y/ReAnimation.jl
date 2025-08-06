#####################################################################################################################
################################################### ANIMATION FRAMES ################################################
#####################################################################################################################

export AbstractFrame
export KFAnimationFrame
export @animationframe
export at, get_animation_array, duration

######################################################### CORE ########################################################

abstract type AbstractFrame <: AbstractAnimation end

mutable struct KFAnimationFrame{T,TR} <: AbstractFrame
	k1::Keyframe{T}
	k2::Keyframe{T}
	transition::TR
	loop::Int

	## Constructors

	function KFAnimationFrame(k1::Keyframe{T}, k2::Keyframe{T}, tr::TR=LinearTransition(), loop=1) where {T,TR<:AbstractTransition}
		
		keytime(k1) > keytime(k2) && error("Keyframe 1 must be earlier than keyframe 2")
		loop < 0 && error("Can't take less than zero loops.")

		return new{T,TR}(k1,k2,tr,loop)
	end
end

macro animationframe(args...)
    loop = 1
    idx  = 1
    if length(args) ≥ 1 && args[1] isa Expr && args[1].head == :(=) && args[1].args[1] == :loop
        loop = args[1].args[2]
        idx  = 2
    end

    length(args) ≥ idx+2 || error("@animationframe should have `[loop=n] t1=>v1 t2=>v2 transition`")
    k1, k2, trans = args[idx], args[idx+1], args[idx+2]

    for pair in (k1, k2)
        pair isa Expr && pair.head == :call && pair.args[1] == :(=>) ||
            error("Keyframes should be `t => value`")
    end
    t1, v1 = k1.args[2], k1.args[3]
    t2, v2 = k2.args[2], k2.args[3]

    :(KFAnimationFrame(
        Keyframe($(esc(t1)), $(esc(v1))),
        Keyframe($(esc(t2)), $(esc(v2))),
        $(esc(trans)),
        $(esc(loop))
    ))
end

#################################################### FUNCTIONS #######################################################

duration(frame::KFAnimationFrame)::Float64 = (keytime(frame.k2) - keytime(frame.k1))
function at(frame::KFAnimationFrame{T}, t::Real) where T
    t_total = duration(frame)
    t_loop = t_total * frame.loop
    t_clamped = clamp(t, zero(t), t_loop)
    t_local = t < t_loop ? mod(t_clamped, t_total) : t_total
    t_norm = t_local / t_total
    frame.transition(value(frame.k1), value(frame.k2), t_norm)
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

bind!(anim::KFAnimationFrame, obj, property) = setfield!(anim, binding, AbstractBinding(obj, property))
