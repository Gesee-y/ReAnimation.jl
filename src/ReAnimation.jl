###########################################################################################################################################
############################################################## ANIMATION SYSTEM ###########################################################
###########################################################################################################################################

"""
    module ReAnimation

A complete animation system.
Provide keyframing, curves, animations graph and per-pixel animations
"""
module ReAnimation

abstract type AbstractAnimation end

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