@LAZYGLOBAL OFF.

Local bounds to ship:bounds.
On round(time:seconds) {
  Set bounds to ship:bounds.
  Return true.
}
Local TARGET to 0.
Function throttle_func {
  Parameter speed.
  Parameter altitude.
  If ship:verticalspeed > 0 {
    Return 0.
  }
  Set altitude to altitude - TARGET.

  Local sp_kinetic_energy to 0.5 * speed^2.

  Local body to ship:body.
  Local body_g to body:mu / body:radius^2.
  Local sp_potential_energy to body_g * altitude.

  Local specific_energy to sp_kinetic_energy + sp_potential_energy.

  Local available_acceleration to (ship:availablethrust / ship:mass).
  Local sp_work to available_acceleration * altitude.

  Return 0.1 * (specific_energy - sp_work) + 0.9 * (body_g / available_acceleration).
}

Local auto_thrust to true.
Local thrust_loop_exited to false.
Local landed_for to 0.0.
Local prev_time_secs to time:seconds.
On time:seconds {
  If ship:velocity:surface:mag > 50 {
    Set ship:control:pilotmainthrottle to throttle_func(ship:velocity:surface:mag, 0.9 * alt:radar).
  } else {
    Set ship:control:pilotmainthrottle to throttle_func(ship:velocity:surface:mag, 0.9 * bounds:bottomaltradar).
  }
  If not auto_thrust {
    Set thrust_loop_exited to true.
    Return false.
  }
  If ship:status = "LANDED" {
    Set landed_for to landed_for + (time:seconds - prev_time_secs).
  } else {
    Set landed_for to 0.0.
  }
  Set prev_time_secs to time:seconds.
  Return true.
}

Wait until bounds:bottomaltradar < 200.
Gear on.
Local prev_ag3 to AG3.
Wait until AG3 <> prev_ag3 or landed_for > 2.0.
Set auto_thrust to false.
Wait until thrust_loop_exited.
Set ship:control:pilotmainthrottle to 0.0.

HUDText("Script finished. Reverting to manual control.", 10, 2, 15, red, true).
