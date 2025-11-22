######################################################################################################################
###################################################### TRACK MANAGER #################################################
######################################################################################################################

export TrackManager, play!, pause!, seek!, update!, bind_track!

########################################################### CORE #####################################################

mutable struct TrackManager
    tracks::Dict{Symbol,RPlayer}
    master_time::Float64
    speed::Float64
    state::PlayState
end

TrackManager(;speed=1.0) = TrackManager(Dict{Symbol,Tuple{RPlayer,AbstractBinding}}(), 0.0, speed, Pause)

function bind_track!(tm::TrackManager, name::Symbol,
                     anim::RAnimation, obj, property; kw...)
    bind_track!(tm,name,RPlayer(anim, obj, property; kw...))
end
function bind_track!(tm::TrackManager, name::Symbol,
                     player::RPlayer)
    tm.tracks[name] = player
    return player
end

remove_track!(tm::TrackManager, name::Symbol) = delete!(tm.tracks, name)
play!(tm::TrackManager)    = (tm.state = Play; foreach(player -> play!(player), values(tm.tracks)))
pause!(tm::TrackManager)   = (tm.state = Pause)
seek!(tm::TrackManager, t) = (tm.master_time = t; update!(tm, 0.0))
seek_relative!(tm::TrackManager, Δ::Real) = seek!(tm, tm.master_time + Δ)
speed!(tm::TrackManager, s) = (tm.speed = s)
reset!(tm::TrackManager) = reset!.(values(tm.tracks))
track(tm::TrackManager, name::Symbol) = tm.tracks[name]

function update!(tm::TrackManager, dt::Real=0.0)
    dt_total = tm.state == Play ? dt * tm.speed : 0.0
    tm.master_time += dt_total
    for (name, player) in tm.tracks
        update!(player, dt_total)
        println(dt_total)
        isfinish(player) && delete!(tm.tracks, name)
    end
    return tm.master_time
end

function runasync!(player::TrackManager; fps::Int = 60)

    frameduration = 1 / fps

    t_start = time()
    t_target = t_start

    interrupt_switch = Ref(false)

    task = @async_showerr while !interrupt_switch[]

        t_current = time()
        t_relative = t_current - t_start

        update!(player, frameduration)

        if isfinish(player)
            break
        end

        t_elapsed = time() - t.t_current

        # always try to hit the next target exactly one frame duration away from
        # the last to avoid drift
        t_target += frameduration
        sleeptime = t_target - time()
        sleep_ns(frameduration)
    end

    AnimationTask(task, interrupt_switch)
end