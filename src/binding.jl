#####################################################################################################################
####################################################### BINDINGS ####################################################
#####################################################################################################################

export AbstractBinding, ObjectBinding, ArrayBinding, DictBinding, set!
export bind, at!

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

set!(b::AbstractBinding, ::Any) = error("set! isn't defined for binding of type $(typeof(b))")
set!(b::ObjectBinding{S}, v) where S = setproperty!(b.obj, S, v)
set!(b::ArrayBinding, v) = (b.array[b.pos] = v)
set!(b::DictBinding, v) = (b.dict[b.key] = v)

at!(a::AbstractBinding, t::Real) = set!(a, at(a.anim, t))
function animate!(binding::AbstractBinding; start=0.0, speed=1/60, delay=speed, loop=1)
    d = duration(binding.anim)
    return @async begin
        for _ in 1:(loop == 0 ? typemax(Int) : loop)
            for t in range(start, start+d, step=speed)
                set!(binding, at(stack, t, value_at_start))
                sleep(delay)
            end
        end
    end
end

Base.bind(anim, obj, property) = (b=AbstractBinding(obj,property); bind!(anim,b); return b)
bind!(anim::AbstractAnimation, b::AbstractBinding) = setfield!(b, :anim, anim)