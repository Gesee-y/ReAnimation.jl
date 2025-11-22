######################################################################################################################
##################################################### ANIMATION PLAYER ###############################################
######################################################################################################################

export RPlayer
export LoopMode, PlayState, on_finish!, on_loop!, loop_mode
export seek!, seek_relative!, pause!, resume!, reverse!, speed!, loop_mode!, update!, runasync!, reset!

########################################################### CORE #####################################################

@enum LoopMode begin
    Once 
    Loop 
    PingPong
end

@enum PlayState begin
    Play
    Pause
end

mutable struct RPlayer
    anim::RAnimation
    binding::AbstractBinding

    time::Float64          # current position (in seconds)
    speed::Float64         # speed multiplicator
    state::PlayState       # Play / Pause
    loop::LoopMode         # Once / Loop / PingPong
    direction::Int         # +1 forward, -1 backward

    # callbacks
    on_finish::Vector{Function}
    on_loop::Vector{Function}

    duration::Float64
end

function RPlayer(anim::RAnimation, obj, property;
                speed=1.0, loop::LoopMode=Once)
    binding = AbstractBinding(anim, obj, property)
    RPlayer(binding;
           speed=speed, loop=loop,
           on_finish=Function[], on_loop=Function[],
          )
end
function RPlayer(binding::AbstractBinding;
                speed=1.0, loop::LoopMode=Once)
    RPlayer(animation(binding), binding,
           0.0, speed, Pause,
           loop, +1,
           Function[], Function[],
           duration(animation(binding)))
end

###################################################### FUNCTIONS ######################################################

seek!(p::RPlayer, t::Real)      = (p.time = clamp(t, 0.0, p.duration); at!(p.binding, 0.0))
seek_relative!(p, Δ::Real)      = seek!(p, p.time + Δ)

pause!(p::RPlayer)              = (p.state = Pause)
resume!(p::RPlayer)             = (p.state = Play)
reverse!(p::RPlayer)            = (p.direction = -p.direction)
speed!(p::RPlayer, s::Real)     = (p.speed = s)
reset!(p::RPlayer)              = seek!(p, 0.0)

loop_mode!(p::RPlayer, m::LoopMode) = (p.loop = m)
loop_mode(p::RPlayer) = p.loop
isfinish(p::RPlayer) = p.time >= p.duration

on_finish!(f, p::RPlayer) = push!(p.on_finish, f)
on_loop!(f, p::RPlayer) = push!(p.on_loop, f)

function update!(p::RPlayer, dt::Real=0.0)
    (dt == 0.0 || p.state == Pause || (isfinish(p) && loop_mode(p) == Once)) && return p.time

    Δ = p.speed * p.direction * dt
    p.time += Δ

    if p.time < 0.0 || p.time > p.duration
        if p.loop == Once
            p.time = clamp(p.time, 0.0, p.duration)
            p.state = Pause
            _exec_listener(p.on_finish)
            return p.time
        elseif p.loop == Loop
            p.time = mod(p.time, p.duration)
            _exec_listener(p.on_loop)
        else # PingPong
            overshoot = p.time > p.duration ? p.time - p.duration : -p.time
            p.direction = -p.direction
            p.time = clamp(overshoot, 0.0, p.duration)
            _exec_listener(p.on_loop)
        end
    end

    at!(p.binding, p.time)
    return p.time
end

function runasync!(player::RPlayer; fps::Int = 60)

    frameduration = 1 / fps
    frameduration <= 0 && error("Can't have negative frame rate.")

    t_start = time()
    t_target = t_start
    resume!(player)

    interrupt_switch = Ref(false)

    task = @async_showerr while !interrupt_switch[]

        t_current = time()
        t_relative = t_current - t_start

        update!(player, frameduration)

        if isfinish(player)
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

function _exec_listener(v::Vector{Function}, args...)
    for f in v
        f(args...)
    end
end