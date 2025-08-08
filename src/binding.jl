#####################################################################################################################
####################################################### BINDINGS ####################################################
#####################################################################################################################

export AbstractBinding, ObjectBinding, ArrayBinding, DictBinding, set!
export bind!, at!, animate!, animation

######################################################### CORE ######################################################

abstract type AbstractBinding end

struct ObjectBinding{S,A,T} <: AbstractBinding
	anim::A
	obj::T

	## Constructor

	function ObjectBinding(anim::A,obj::T, p::Symbol) where {A <: AbstractAnimation, T}
		isimmutable(obj) && error("Can't bind properties of immutable objects.")
		return new{p,A,T}(anim,obj)
	end
end

struct ArrayBinding{A,T} <: AbstractBinding
	anim::A
	array::AbstractArray{T}
	pos::Int
end

struct DictBinding{A,K,V} <: AbstractBinding
	anim::A
	dict::AbstractDict{K,V}
	key::K
end

####################################################### FUNCTIONS ###################################################

AbstractBinding(anim,obj, p::Symbol) = ObjectBinding(anim,obj, p)
AbstractBinding(anim::A,obj::AbstractArray{T}, i::Int) where {A,T} = ArrayBinding{A,T}(anim,obj, i)
AbstractBinding(anim::A,obj::AbstractDict{K,V}, key::K) where {A,K,V} = DictBinding{A,K,V}(anim,obj, key)

duration(b::AbstractBinding) = duration(animation(b))

set!(b::AbstractBinding, ::Any) = error("set! isn't defined for binding of type $(typeof(b))")
set!(b::ObjectBinding{S}, v) where S = setproperty!(b.obj, S, v)
set!(b::ArrayBinding, v) = (b.array[b.pos] = v)
set!(b::DictBinding, v) = (b.dict[b.key] = v)

at!(a::AbstractBinding, t::Real) = set!(a, at(a.anim, t))
animation(b::AbstractBinding) = b.anim

function animate!(bindings::AbstractBinding...;
        duration = maximum(duration, bindings),
        fps::Int = 60)

    frameduration = 1 / fps

    t_start = time()
    t_target = t_start

    interrupt_switch = Ref(false)

    task = @async_showerr while !interrupt_switch[]

        t_current = time()
        t_relative = t_current - t_start

        for binding in bindings
            at!(binding,t_relative)
        end

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

bind!(anim::AbstractAnimation, b::AbstractBinding) = setfield!(b, :anim, anim)