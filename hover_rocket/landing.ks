@LAZYGLOBAL OFF.
Parameter INIT_TARGET to 100.

Local start_gui to gui(200).
Local start_button to start_gui:addbutton("Start deceleration program").
Local start_program to false.
Set start_button:onclick to {
  Set start_program to true.
}.
Start_gui:show().
Wait until start_program.
Start_gui:dispose().

Function throttle_func {
  Parameter speed.
  Parameter altitude.
  If ship:verticalspeed > 0 {
    Return 0.
  }
  Set altitude to altitude - INIT_TARGET.

  Local sp_kinetic_energy to 0.5 * speed^2.

  Local body to ship:body.
  Local body_g to body:mu / body:radius^2.
  Local sp_potential_energy to body_g * altitude.

  Local specific_energy to sp_kinetic_energy + sp_potential_energy.

  Local sp_work to (ship:availablethrust / ship:mass) * altitude.

  Return 0.01 * (specific_energy - sp_work) + 1.0.
}
Lock throttle to throttle_func(ship:velocity:surface:mag, alt:radar).


Local function distortion_vector {
  Local upvec to up:forevector:normalized.
  If not hastarget { Return 40 * upvec. }.
  Local targetvec to target:position.
  Set targetvec to targetvec - vdot(targetvec, upvec) * upvec.
  If targetvec:mag > 1500 {
    Set targetvec to 1500 * targetvec:normalized. 
  }
  Return 0.025 * targetvec + 20 * upvec.
}

SAS off.
Local control to ship:control.
Local pid_roll is pidloop(0.2, 0.0, 0.2, -1, 1).
Local pid_pitch is pidloop(1.6, 0, 6.4, -1, 1).
Local pid_yaw is pidloop(1.6, 0, 6.4, -1, 1).
Local target_direction is up.
On time:seconds {
  Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
  Set target_direction to (-ship:velocity:surface + distortion_vector()):normalized.
  Set control:pitch to pid_pitch:update(time:seconds,
    -vdot(target_direction, ship:facing:topvector)).
  Set control:yaw to pid_yaw:update(time:seconds,
    -vdot(target_direction, ship:facing:starvector)).
  Return true.
}






Wait until alt:radar < INIT_TARGET + 20.


Local pid_throttle to pidloop(0.1, 0, 1.0, 0, 1).
Set pid_throttle:setpoint to 100.
Local end_now to false.

Local scale_gui to gui(200).
Local label to scale_gui:addlabel("Target altitude: " + INIT_TARGET + " m").
Local slider to scale_gui:addvslider(INIT_TARGET, 200, 0).
Local end_button to scale_gui:addbutton("End hover").

Set slider:onchange to {
  Parameter target_alt.
  Set pid_throttle:setpoint to target_alt.
  Set label:text to "Target altitude: " + round(target_alt) + " m".
}.

Set end_button:onclick to {
  Set end_now to true.
}.

Local bounds to ship:bounds.

Lock throttle to pid_throttle:update(time:seconds, bounds:bottomaltradar).
Scale_gui:show().

Wait until end_now.
Unlock throttle.
Control:neutralize on.
Scale_gui:dispose().
