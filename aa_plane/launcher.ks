@LAZYGLOBAL OFF.

// Link to AA doc such as it is:
// https://discord.com/channels/210513998876114944/210513998876114944/705030913192493196

RunOncePath("0:/my_lib/basic_control_flow").
RunOncePath("0:/my_lib/acceleration").
RunOncePath("0:/my_lib/bisect").
RunOncePath("0:/my_lib/lib_smoothing").

Local function more_flaps {
  Toggle AG10.
}

Local function less_flaps {
  Toggle AG9.
}

Local neutral_angle to vang(ship:up:forevector, ship:facing:upvector).
Local runway_altitude to ship:altitude.
Local aa to addons:aa.

Local rate_limiter to lib_smoothing:rate_limited(heading(90, 5):vector).
Local exp_moving_avg to lib_smoothing:exponential_moving_avg(2.0).

Local function update_heading_toward {
  Parameter goal.
  Set goal to goal:normalized.
  {
    Local prev_goal to exp_moving_avg:get():normalized.
    Until vang(prev_goal, goal) < 15 {
      Local vert to ship:up:vector.
      Local vert_goal to vert * goal.
      Local prev_vert_goal to vert * prev_goal.
      Set vert_goal to (vert_goal + prev_vert_goal) / 2.
      Local horiz_goal to vxcl(vert, goal):normalized.
      Local prev_horiz_goal to vxcl(vert, prev_goal):normalized.
      Set horiz_goal to ((horiz_goal + prev_horiz_goal) / 2):normalized.
      Set goal to (horiz_goal + vert * vert_goal):normalized.
    }.
  }.
  Local time_secs to time:seconds.
  Local speed to ship:airspeed.
  Local rate_limit to 2 * constant:g0 / speed.
  Set goal to rate_limiter:update(time_secs, goal:normalized, rate_limit).
  Set goal to exp_moving_avg:update(time_secs, goal).
  Return goal:normalized.
}.

Local function interpolator {
  Parameter sorted_x.
  Parameter ylist.
  Return {
    Parameter xval.
    Return interpolate(xval, sorted_x, ylist).
  }.
}

Local function current_heading {
  Local direction to ship:srfprograde:vector.
  Return arctan2(direction * ship:north:starvector, direction * ship:north:vector).
}.

Local k2_geo to Waypoint("K2"):geoposition.
// Kerbin:geopositionLatLng(38.5184, -59.5459)

Local cf to control_flow:new().
Local vars to lex().

Cf:background:register_op("update_director", {
  If aa:director {
    If vars:hassuffix("goal") {
      Set aa:direction to update_heading_toward(vars:goal).
    } else {
      Set vars["goal"] to ship:srfprograde:vector.
      Rate_limiter:reset(vars:goal).
      Exp_moving_avg:reset(vars:goal).
      Set aa:direction to vars:goal.
    }.
  }.
  Return "update_director".
}).

Local VEER_UP_DISTANCE to 200000.

Cf:enqueue_op("launch").
Cf:register_sequence("launch",list(
  { 
    Brakes off.
    Lock steering to heading(90, neutral_angle).
    Lock throttle to 1.0.
    Stage.
  }, {
    Return ship:velocity:surface:mag < 60.
  }, {
    More_flaps().
    Toggle AG1.  // start fuel cell
    Set vars["next_flap_time"] to time:seconds + 1.
  }, {
    Return time:seconds < vars:next_flap_time.
  }, {
    More_flaps().
    Vars:remove("next_flap_time").
    Set vars["bounds"] to ship:bounds.
  }, {
    Return ship:airspeed < 140.
  }, {
    Lock steering to heading(90, 15).
  }, {
    Return vars:bounds:bottomaltradar < 5.
  }, {
    Gear off.
    Unlock steering.
    Aa:director on.
    Set aa:direction to ship:srfprograde:vector.
    Cf:background:enqueue_op("update_director").
    Unlock throttle.
    Set aa:speed to 250.
    Aa:speedcontrol on.
  }, {
    Set vars["goal"] to heading(90, 5):vector.
  }, {
    Return ship:altitude < 200.
  }, {
    Less_flaps().
  }, {
    Return ship:altitude < 500.
  }, {
    Less_flaps().
  }, {
    Set vars["goal"] to heading(k2_geo:heading(), 5):vector.
    Return vang(aa:direction, vars:goal) > 0.1.
  }, control_flow:fork("adjust_intended_speed", list(
      { Return ship:altitude < 10000. },
      { Set aa:speed to 1000. }
    )
  ), {
    Set vars["goal"] to heading(k2_geo:heading(), 10):vector.
    Return ship:altitude < 16000.
  }, {
    Set vars["goal"] to heading(k2_geo:heading(), 0):vector.
    Return ship:verticalspeed > 20 and k2_geo:altitudePosition(80000):mag > VEER_UP_DISTANCE.
  }, {
    Aa:director off.
    Set aa:vertspeed to 0.
    Set aa:heading to k2_geo:heading().
    Aa:cruise on.
  }, {
    Set aa:heading to k2_geo:heading().
    Return ship:verticalspeed > 1.
  }, {
    Set aa:altitude to ship:altitude.
  }, {
    Set aa:heading to k2_geo:heading().
    Return k2_geo:altitudePosition(80000):mag > VEER_UP_DISTANCE.
  }, {
    Aa:speedcontrol off.
    Aa:cruise off.
    Lock throttle to 1.0.
    Vars:remove("goal").  // Reset the smoothers.
    Aa:director on.
  }, {
    Set vars["goal"] to heading(k2_geo:heading(), 30):vector.
    Return ship:orbit:apoapsis < 78000.
  }, {
    Lock throttle to 0.0.
    Aa:director off.
    Lock steering to lookdirup(ship:srfprograde:forevector, -ship:srfprograde:starvector).
  }, {
    Return ship:verticalspeed > 0 or ship:altitude > 60000.
  }, {
    Toggle AG2.  // Switch engine mode back to airbreathing.
    Unlock steering.
    Unlock throttle.
    Set aa:speed to 600.
    Set aa:heading to current_heading().
    Set aa:vertspeed to 0.
    Aa:cruise on.
  }, control_flow:fork("set_speed_when_ready", list(
      { Return ship:airspeed > 650. },
      { Aa:speedcontrol on. }
    )
  ), control_flow:fork("deactivate_reaction_wheels", list(
      { Return ship:altitude > 45000. },
      {
        For module in ship:modulesNamed("ModuleReactionWheel") {
          Module:doAction("deactivate wheel", true).
        }.
      })
  ), {
    Set aa:heading to current_heading().
    Return ship:verticalspeed < -100.
  }, {
    Aa:cruise off.
    Aa:fbw on.
    Set vars["pid_fbw_pitch"] to pidloop(0.001, 0, 0.01, -0.2, 0.2).
  }, {
    Set ship:control:pitch to vars:pid_fbw_pitch:update(time:seconds, ship:verticalspeed).
    Return ship:verticalspeed < -10.
  }, {
    Aa:fbw off.
    Ship:control:neutralize on.
    Set vars["runway_west"] to vessel("Runway West").
    Set vars["near_runway"] to Kerbin:geopositionOf(vars:runway_west:position + 50000 * -vars:runway_west:north:starvector).
    Vars:remove("goal").  // Reset the smoothers.
    Set aa:direction to ship:srfprograde:vector.
    Aa:director on.
  }, {
    Set vars["goal"] to (vxcl(ship:up:forevector, vars:near_runway:position):normalized - 0.1 * ship:up:vector):normalized.
    Return vang(aa:direction, vars:goal) > 1.0.
  }, {
    Set aa:altitude to ship:altitude.
    Set aa:heading to vars:near_runway:heading.
    Aa:director off.
    Aa:cruise on.
  }, {
    Set aa:heading to vars:near_runway:heading.
    Return vang(ship:up:vector, vars:near_runway:altitudePosition(40000)) > 45.
  }, {
    Aa:cruise off.
    Aa:director on.
    Set aa:direction to ship:srfprograde:vector.
    Vars:remove("goal").  // Reset the smoothers to prograde.
    Set vars["near_runway"] to vars:runway_west:geoposition.
    Set vars["near_runway_alt"] to 200.
    Set vars["approach_speed"] to 100.
  }, control_flow:fork("landing_speed_adjustment", list(
      {
        Set vars["incoming_speed_interp"] to interpolator(list(vars:near_runway_alt, ship:altitude),
                                                          list(vars:approach_speed, ship:airspeed)).
      }, {
        Set aa:speed to vars:incoming_speed_interp(ship:altitude).
        Return ship:altitude > vars:near_runway_alt.
      }, {
        Return vars:bounds:bottomAltRadar > 2.
      }, {
        Aa:speedcontrol off.
        Lock throttle to 0.
        Brakes on.
      })
  ), control_flow:fork("landing_flaps", list(
    { Return ship:altitude > vars:near_runway_alt + 900. },
    { More_flaps(). },
    { Return ship:altitude > vars:near_runway_alt + 600. },
    { More_flaps(). },
    { Return ship:altitude > vars:near_runway_alt + 300. },
    { More_flaps(). }
  )), {
    Local intended_heading to 270.  // west
    Set intended_heading to intended_heading + 3 * (vars:near_runway:heading - intended_heading).
    Local intended_angle_down to vang(vars:near_runway:altitudePosition(vars:near_runway_alt), -ship:up:vector) - 90.
    Set vars["goal"] to heading(intended_heading, intended_angle_down):vector.
    Return ship:altitude > vars:near_runway_alt + 50.
  }, {
    Kuniverse:timeWarp:cancelWarp().
    Gear on.
    Set aa:heading to 270.
    Set aa:altitude to -100.  // Disable altitude-based cruise so it uses vertspeed instead.
    Set aa:vertspeed to ship:verticalspeed.
    Aa:director off.
    Aa:cruise on.
    // Numbers: 100 is horizontal speed, 3000 is approx horizontal distance to desired landing spot.
    Set vars["leveling_coeff"] to (2 * 100 * sqrt(ship:altitude - runway_altitude) / 3000).
  }, {
    Local y to ship:altitude - runway_altitude + ship:verticalspeed.  // Estimate what altitude will be in one second.
    If y < 0 { Set aa:vertspeed to 2. }
    Else { Set aa:vertspeed to -vars:leveling_coeff * sqrt(y). }.
    Return y > 0.
  }, {
    Aa:cruise off.
    Lock steering to heading(270, neutral_angle).
  }, {
    Return ship:airspeed > 0.1.
  }
)).

Until not cf:active() {
  Cf:run_pass().
  Wait 0.
}
Print "script finished".
