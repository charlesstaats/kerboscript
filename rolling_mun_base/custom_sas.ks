@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/controller").

SAS off.

Local desired_facing to ship:facing:vector.
Local desired_upvec to ship:facing:upvector.

Local arrow_root_part to ship:controlPart.
Local fore to vecdraw().
Local upvec to vecdraw().
Set fore:color to rgb(212/256, 175/256, 55/256).  // gold
Set upvec:color to cyan.
Set fore:show to true.
Set upvec:show to true.
Local function update_arrows {
  Set fore:start to arrow_root_part:position.
  Set fore:vec to desired_facing:normalized * 1000. 
  Set upvec:start to (fore:start + 20 * fore:vec:normalized).
  Set upvec:vec to desired_upvec:normalized * 10.
}.

Local control_var to ship:control.

Local prev_time to time:seconds.
Local DEGREES_PER_SEC to 5.
Local function update_desires {
  Local delta_t to time:seconds - prev_time.
  Set prev_time to time:seconds.
  Set desired_facing to angleAxis(control_var:pilotYaw * DEGREES_PER_SEC * delta_t, ship:facing:upvector) * desired_facing.
  Set desired_facing to angleAxis(control_var:pilotPitch * DEGREES_PER_SEC * delta_t, -ship:facing:starvector) * desired_facing.
  Set desired_upvec to angleAxis(control_var:pilotRoll * DEGREES_PER_SEC * delta_t, -ship:facing:vector) * desired_upvec.
}.

Local rotation_kp to 100.0.
Local rotation_kd to 4.0 * rotation_kp.
Until SAS {
  Update_desires().
  Update_arrows().
  Local factor to (1 / max(0.1, ship:control:pilotmainthrottle)).
  Set control_var:rotation to
     factor * direction_rotation_controller(
        desired_facing,
        desired_upvec,
        V(0,0,0),
        rotation_kp,
        rotation_kd).
  Wait 0.
}.

Control_var:neutralize on.
Fore:show off.
Upvec:show off.
