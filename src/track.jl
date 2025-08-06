

export TrackManager, play!, pause!, seek!, update!, bind_track!

mutable struct TrackManager
    tracks::Dict{Symbol,Tuple{Player,AbstractBinding}}
    master_time::Float64
    speed::Float64
    state::PlayState
end

TrackManager(;speed=1.0) = TrackManager(Dict{Symbol,Tuple{Player,AbstractBinding}}(), 0.0, speed, Pause)

function bind_track!(tm::TrackManager, name::Symbol,
                     anim::RAnimation, obj, property; kw...)
    player = Player(anim, obj, property; kw...)
    tm.tracks[name] = (player, player.binding)
    return player
end

remove_track!(tm::TrackManager, name::Symbol) = delete!(tm.tracks, name)
play!(tm::TrackManager)    = (tm.state = Play)
pause!(tm::TrackManager)   = (tm.state = Pause)
seek!(tm::TrackManager, t) = (tm.master_time = t; update!(tm, 0.0))
speed!(tm::TrackManager, s) = (tm.speed = s)

function update!(tm::TrackManager, dt::Real=0.0)
    dt_total = tm.state == Play ? dt * tm.speed : 0.0
    tm.master_time += dt_total
    for (_, (player, _)) in tm.tracks
        update!(player, dt_total)
    end
    return tm.master_time
end
track(tm::TrackManager, name::Symbol) = tm.tracks[name][1]