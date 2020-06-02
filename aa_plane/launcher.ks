@LAZYGLOBAL OFF.

// Link to AA doc such as it is:
// https://discord.com/channels/210513998876114944/210513998876114944/705030913192493196

RunOncePath("0:/my_lib/basic_control_flow").
RunOncePath("0:/my_lib/acceleration").
RunOncePath("0:/my_lib/lib_smoothing").

Local starting_ag3 to AG3.

Local function more_flaps {
  Toggle AG10.
}

Local function less_flaps {
  Toggle AG9.
}

Local accel_object to lib_acceleration:new().
Local function update_pitch_gforce {
  Accel_object:update().
  Return vdot(-ship:facing:upvector, accel_object:get_experienced()) / constant:g0.
}

Local neutral_angle to vang(ship:up:forevector, ship:facing:upvector).
Local aa to addons:aa.

Local rate_limiter to lib_smoothing:rate_limited(heading(90, 5):vector).
Local exp_moving_avg to lib_smoothing:exponential_moving_avg(2.0).

Local function update_heading_toward {
  Parameter goal.

  Local time_secs to time:seconds.
  Local speed to ship:airspeed.
  Local rate_limit to 2 * constant:g0 / speed.
  Set goal to rate_limiter:update(time_secs, goal, rate_limit).
  Set goal to exp_moving_avg:update(time_secs, goal).
  Return goal.
}.

Local cf to control_flow:new().

Cf:enqueue_op("launch").
Local vars to lex().
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
    Set vars["next_flap_time"] to time:seconds + 1.
    Return false.
  }, {
    Return time:seconds < vars:next_flap_time.
  }, {
    More_flaps().
    Vars:remove("next_flap_time").
    Set vars["bounds"] to ship:bounds.
    Lock steering to heading(90, 15).
  }, {
    Return vars:bounds:bottomaltradar < 5.
  }, {
    Gear off.
    Vars:remove("bounds").
    Set aa:direction to heading(90, 5):vector.
    Unlock steering.
    Aa:director on.
  }, {
    Return ship:airspeed < 150.
  }, {
    Less_flaps().
  }, {
    Return ship:airspeed < 300.
  }, {
    Less_flaps().
    Set aa:speed to 400.
    Unlock throttle.
    Aa:speedcontrol on.
  }, {
    Local goal to heading(0, 5):vector.
    Set aa:direction to update_heading_toward(goal).
    Return vang(aa:direction, goal) > 0.1.
  }, {
    Set aa:direction to heading(0, 10):vector.
    Aa:speedcontrol off.
    Lock throttle to 1.0.
  }, {
    Return AG3 = starting_ag3.
  }
)).

Until not cf:active() {
  Cf:run_pass().
  Wait 0.
}
