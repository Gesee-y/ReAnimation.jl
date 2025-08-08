######################################################################################################################
##################################################### ANIMATION PLAYER ###############################################
######################################################################################################################

export RPlayer
export LoopMode, PlayState
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
    on_finish::Union{Nothing,Function}
    on_loop::Union{Nothing,Function}

    duration::Float64
end

function RPlayer(anim::RAnimation, obj, property;
                speed=1.0, loop::LoopMode=Once,
                on_finish=nothing, on_loop=nothing)
    binding = AbstractBinding(anim, obj, property)
    RPlayer(binding;
           speed=speed, loop=loop,
           on_finish=on_finish, on_loop=on_loop,
          )
end
function RPlayer(binding::AbstractBinding;
                speed=1.0, loop::LoopMode=Once,
                on_finish=nothing, on_loop=nothing)
    RPlayer(animation(binding), binding,
           0.0, speed, Pause,
           loop, +1,
           on_finish, on_loop,
           duration(animation(binding)))
end

###################################################### FUNCTIONS ######################################################

seek!(p::RPlayer, t::Real)      = (p.time = clamp(t, 0.0, p.duration); at!(p.binding, 0.0))
seek_relative!(p, Δ::Real)      = seek!(p, p.time + Δ)

pause!(p::RPlayer)              = (p.state = Pause)
resume!(p::RPlayer)             = (p.state = Play)
reverse!(p::RPlayer)            = (p.direction = -p.direction)
speed!(p::RPlayer, s::Real)     = (p.speed = s * p.direction)
reset!(p::RPlayer)              = seek!(p, 0.0)

loop_mode!(p::RPlayer, m::LoopMode) = (p.loop = m)
isfinish(p::RPlayer) = p.time >= p.duration

function update!(p::RPlayer, dt::Real=0.0)
    (dt == 0.0 || p.state == Pause) && return p.time

    Δ = p.speed * p.direction * dt
    p.time += Δ

    if p.time < 0.0 || p.time > p.duration
        if p.loop == Once
            p.time = clamp(p.time, 0.0, p.duration)
            p.state = Pause
            isnothing(p.on_finish) || p.on_finish(p)
            return p.time
        elseif p.loop == Loop
            p.time = mod(p.time, p.duration)
            isnothing(p.on_loop) || p.on_loop(p)
        else # PingPong
            overshoot = p.time > p.duration ? p.time - p.duration : -p.time
            p.direction = -p.direction
            p.time = clamp(overshoot, 0.0, p.duration)
            isnothing(p.on_loop) || p.on_loop(p)
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