@LAZYGLOBAL off.

RunOncePath("0:/KSLib/library/lib_location_constants").
RunOncePath("0:/planette/slope").

Local desired_geolocation to flattest_location_near(ship:geoposition).
Local function target_position {
  Return desired_geolocation:position.
}.

Local function distortion_vector {
  Local upvec to ship:up:vector.
  Local targetvec to vxcl(upvec, target_position()).
  Local up_component to 20 * upvec.
  Local horiz_component to 0.1 * targetvec.
  Return horiz_component + up_component.
}.

Local control to ship:control.
Local pid_roll to pidloop(1, 0, 0.5).
Local pid_pitch to pidloop(1, 0, 6).
Local pid_yaw to pidloop(1, 0, 6).
Local pid_throttle to pidloop(1, 0, 10).

When alt:radar < 5000 then {
  Toggle AG1.  // Switch to dry mode.
}.
When alt:radar < 4000 and ship:airspeed < 70 then {
  Set pid_pitch:kd to 2.
  Set pid_yaw:kd to 2.
}.

Local bounds to ship:bounds.
On round(time:seconds * 0.1) {
  Set bounds to ship:bounds.
  Return true.
}.

For ctrl_surface in ship:modulesNamed("FARControllableSurface") {
  Ctrl_surface:setfield("std. ctrl", true).
}.

Local init_time to time:seconds.
When time:seconds > init_time + 1 then {
  For ctrl_surface in ship:modulesNamed("FARControllableSurface") {
    Ctrl_surface:setfield("ctrl dflct", 0).
  }.
}.

Local throttle_var to 0.1.
Lock throttle to throttle_var.
Local function update_throttle_toward {
  Parameter goal.
  Local persistence to 0.995.
  Set throttle_var to persistence * throttle_var + (1 - persistence) * goal.
}.


Local function twr {
  Local body to ship:body.
  Local body_g to body:mu / body:radius^2.
  Local weight to body_g * ship:mass.
  Return ship:availablethrust / weight.
}.

Local function max_angle {
  Parameter current_altitude.
  Parameter current_height.
  If current_altitude > 8000 or current_height < 100 {
    Return 1.
  }.
  Return 10.
}.

Until ship:status <> "FLYING" {
  Local target_direction to (-ship:velocity:surface + distortion_vector()):normalized.

  // Keep the angle close enough to vertical that we won't lose control.
  Local angle_to_vertical to vang(ship:up:vector, target_direction).
  Local height to max(0.01, bounds:bottomaltradar).
  Local max_allowed_angle to max_angle(ship:altitude, height).
  If angle_to_vertical > max_allowed_angle {
    Local axis to vcrs(target_direction, ship:up:vector):normalized.
    Set target_direction to angleaxis(angle_to_vertical - max_allowed_angle, axis) * target_direction.
  }.
  Local current_twr to twr().
  Set control:roll to 2.0 / current_twr * pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
  Set control:pitch to 4.0 / current_twr * pid_pitch:update(time:seconds,
    -vdot(target_direction, ship:facing:topvector)).
  Set control:yaw to 4.0 / current_twr * pid_yaw:update(time:seconds,
    -vdot(target_direction, ship:facing:starvector)).

  Set pid_throttle:setpoint to -max(0.5, min(sqrt(height), 0.025 * height)).
  Update_throttle_toward(min(1, max(0.1, 5 * pid_throttle:update(time:seconds, verticalspeed)))).  
  If bounds:bottomaltradar < 250 and not gear { Gear on. }.
  Wait 0.
}.

Set control:pilotmainthrottle to 0.
Control:neutralize on.
