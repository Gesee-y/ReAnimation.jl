###########################################################################################################################################
############################################################## ANIMATION SYSTEM ###########################################################
###########################################################################################################################################

"""
    module ReAnimation

A complete animation system.
Provide keyframing, curves, animations graph and per-pixel animations
"""
module ReAnimation

export AbstractAnimation
export AnimationTask

abstract type AbstractAnimation end

############# Borrowed Animations.jl

"""
    AnimationTask

A thin wrapper around a `Task` together with an interrupt_switch that signals
the animation loop to exit.
"""
struct AnimationTask
    task::Task
    interrupt_switch::Ref{Bool}
end

macro async_showerr(ex)
    quote
        animationtask = @async try
            eval($(esc(ex)))
        catch err
            bt = catch_backtrace()
            println("Asynchronous animation errored:")
            showerror(stderr, err, bt)
        end
    end
end

include("keyframe.jl")
include("transition.jl")
include("binding.jl")
include("frame.jl")
include("animation.jl")
include("layer.jl")
include("player.jl")
include("track.jl")
include("interpolation.jl")

end # module