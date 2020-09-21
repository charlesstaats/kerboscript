@LAZYGLOBAL OFF.
RunOncePath("0:/my_lib/lib_smoothing").
RunOncePath("0:/my_lib/clip").

Parameter USE_GEAR to true.

Function available_thrust_facing {
  Local facing_dir to ship:facing:vector.
  Local thrust to 0.0.
  Local ship_engines to list().
  List engines in ship_engines.
  For eng in ship_engines {
    Set thrust to thrust + eng:availableThrust * (facing_dir * eng:facing:vector).
  }.
  Return thrust.
}.

Local bounds to ship:bounds.
On round(time:seconds) {
  Set bounds to ship:bounds.
  Return true.
}
Local TARGET_ALTITUDE to 0.
Local throttle_smoother to lib_smoothing:exponential_moving_avg(2.0).

Local prev_rounded to round(time:seconds).
Function throttle_func {
  Parameter speed.
  Parameter altitude_param.
  If ship:verticalspeed > 0 {
    Return 0.
  }
  Set altitude_param to altitude_param - TARGET_ALTITUDE.

  Local sp_kinetic_energy to 0.5 * speed^2.

  Local body to ship:body.
  Local body_g to body:mu / body:radius^2.
  Local sp_potential_energy to body_g * altitude_param.

  Local specific_energy to sp_kinetic_energy + sp_potential_energy.

  Local available_acceleration to (available_thrust_facing() / ship:mass).
  Local sp_work to available_acceleration * altitude_param.
  
  Return throttle_smoother:update(time:seconds,
      clip(0.4 * (specific_energy - sp_work) + 0.9 * (body_g / available_acceleration) / (ship:up:vector * ship:facing:vector), 0, 1)).
}

On round(0.1 * time:seconds) {
  Print "".
  Print "alt:radar = " + alt:radar.
  Print "bounds:bottomaltradar = " + bounds:bottomaltradar.
  Print "altitude = " + ship:altitude.
  Return true.
}.

Local auto_thrust to true.
Local thrust_loop_exited to false.
Local landed_for to 0.0.
Local prev_time_secs to time:seconds.
On time:seconds {
  Set ship:control:pilotmainthrottle to throttle_func(ship:velocity:surface:mag, 0.9 * min(alt:radar, bounds:bottomaltradar)).
//  If ship:velocity:surface:mag > 50 {
//    Set ship:control:pilotmainthrottle to throttle_func(ship:velocity:surface:mag, 0.9 * alt:radar).
//  } else {
//    Set ship:control:pilotmainthrottle to throttle_func(ship:velocity:surface:mag, 0.9 * bounds:bottomaltradar).
//  }
  If not auto_thrust {
    Set thrust_loop_exited to true.
    Return false.
  }
  Local speed to ship:velocity:surface:mag.
  If speed < 0.01 or (ship:status = "LANDED" and speed < 0.2) {
    Set landed_for to landed_for + (time:seconds - prev_time_secs).
  } else {
    Set landed_for to 0.0.
  }
  Set prev_time_secs to time:seconds.
  Return true.
}

Wait until bounds:bottomaltradar < 200.
If USE_GEAR { Gear on. }.
Wait until bounds:bottomaltradar < 50.// and vxcl(ship:up:vector, ship:velocity:surface):mag < 5.
SAS off.
RCS on.
Function steering_direction {
  Local simple to 5 * ship:up:vector - ship:velocity:surface.
  If vang(simple, ship:up:vector) > 45 {
    Local axis to vcrs(ship:up:vector, simple).
    Return angleaxis(45, axis) * ship:up:vector.
  }.
  Return simple.
}.
Lock steering to lookDirUp(steering_direction(), ship:facing:upvector).
Local prev_ag3 to AG3.
Wait until AG3 <> prev_ag3 or landed_for > 2.0.
Set auto_thrust to false.
Wait until thrust_loop_exited.
Set ship:control:pilotmainthrottle to 0.0.

Lock steering to (choose ship:facing if ship:angularvel:mag < constant:DegToRad * 0.3 else lookDirUp(ship:up:vector, ship:facing:upvector)).
Set prev_time_secs to time:seconds.
Set landed_for to 0.0.
On time:seconds {
  If ship:status = "LANDED" and ship:velocity:surface:mag < 0.2 and ship:angularvel:mag < constant:DegToRad * 0.1 {
    Set landed_for to landed_for + (time:seconds - prev_time_secs).
  } else {
    Set landed_for to 0.0.
  }.
  Set prev_time_secs to time:seconds.
  Return landed_for <= 2.0.
}

Wait until landed_for > 2.0.

Unlock steering.
HUDText("Script finished. Reverting to manual control.", 10, 2, 15, red, true).
