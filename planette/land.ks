@LAZYGLOBAL off.

Parameter return_to_launchpad to false.

RunOncePath("0:/KSLib/library/lib_location_constants").
RunOncePath("0:/my_lib/clip").
RunOncePath("0:/my_lib/controller").
RunOncePath("0:/my_lib/lib_smoothing").
RunOncePath("0:/planette/slope").

Local desired_geolocation to ship:geoposition.
For wp in allWaypoints() {
  If wp:isselected {
    Set desired_geolocation to wp:geoposition.
  }.
}.
Set desired_geolocation to flattest_location_near(desired_geolocation).
Local landing_sideways_heading to descent_heading(desired_geolocation).
On round(0.1 * time:seconds) {
  Set landing_sideways_heading to descent_heading(desired_geolocation).
}.
If return_to_launchpad {
  Set desired_geolocation to location_constants:kerbin:launchpad.
}.
Local function target_position {
  Return desired_geolocation:position.
}.

Local keep_waiting to true.
On AG2 {
  Keep_waiting off.
}.
Wait until not keep_waiting.

Local goal_arrow to vecdraw().
On round(time:seconds) {
  Set goal_arrow:vec to target_position().
  Return true.
}.
Goal_arrow:show on.

Local function distortion_vector {
  Local upvec to ship:up:vector.
  Local targetvec to vxcl(upvec, target_position()).
  Local up_component to 20 * upvec.
  Local horiz_component to 0.1 * targetvec.
  Return horiz_component + up_component.
}.

SAS off.
If addons:hassuffix("AA") {
  Print "trying to turn of AtmosphereAutopilot".
  Addons:aa:fbw on.
  Addons:aa:fbw off.
}

Local control to ship:control.
//Local pid_roll to pidloop(1, 0, 4).
//Local pid_pitch to pidloop(1, 0, 6).
//Local pid_yaw to pidloop(1, 0, 6).
Local rotation_kp to 1.0.
Local rotation_kd to 3.0.
Local pid_throttle to pidloop(1, 0, 10).

Local throttle_var to 0.1.
Lock throttle to throttle_var.

When ship:altitude < 5000 and throttle_var < 0.45 then {
  If alt:radar > 1000 {
    Toggle AG1.  // Switch to dry mode.
  }.
}.
//When ship:altitude < 4000 and ship:airspeed < 70 then {
//  Set pid_pitch:kd to 1.
//  Set pid_yaw:kd to 2.
//}.

Local bounds to ship:bounds.
On round(time:seconds * 0.1) {
  Set bounds to ship:bounds.
  Return true.
}.

For ctrl_surface in ship:modulesNamed("FARControllableSurface") {
  Ctrl_surface:setfield("std. ctrl", true).
}.

Local init_time to time:seconds.
Local ctrl_surface_to_prev_setting to lex().
When time:seconds > init_time + 1 then {
  For ctrl_surface in ship:modulesNamed("FARControllableSurface") {
    Set ctrl_surface_to_prev_setting[ctrl_surface] to ctrl_surface:getfield("ctrl dflct").
    Ctrl_surface:setfield("ctrl dflct", 0).
  }.
}.

Local throttle_smoother to lib_smoothing:exponential_moving_avg(2.0).
Local function update_throttle_toward {
  Parameter goal.
//  Local persistence to 0.995.
//  Set throttle_var to persistence * throttle_var + (1 - persistence) * goal.
  Set throttle_var to throttle_smoother:update(time:seconds, goal).
}.


Local eng_list to list().
List engines in eng_list.
Local function twr {
  Local body to ship:body.
  Local body_g to body:mu / body:radius^2.
  Local weight to body_g * ship:mass.
  Local thrust to 0.1.  // avoid returning zero thrust.
  For eng in eng_list {
    Set thrust to thrust + eng:thrust.
  }.
  Return V(thrust / weight, ship:availableThrust / weight, 0).
}.

Local function max_angle {
  Parameter current_altitude.
  Parameter current_height.
  If current_altitude > 10000 or current_height < 30 {
    Return 1.
  }.
  Return 10.
}.

Local ROLL_FACTOR to 4.
Local roll_choice to 1.
Until ship:status <> "FLYING" {
  Local target_direction to (-ship:velocity:surface + 0.5 * distortion_vector()):normalized.

  // Keep the angle close enough to vertical that we won't lose control.
  Local angle_to_vertical to vang(ship:up:vector, target_direction).
  Local height to max(0.01, bounds:bottomaltradar).
  Local max_allowed_angle to max_angle(ship:altitude, height).
  If angle_to_vertical > max_allowed_angle {
    Local axis to vcrs(target_direction, ship:up:vector):normalized.
    Set target_direction to angleaxis(angle_to_vertical - max_allowed_angle, axis) * target_direction.
  }.
  Local twr_vec to twr().
  Local current_twr to twr_vec:X.
  Local available_twr to twr_vec:Y.
  Local desired_up to ship:facing:upvector.
  If ship:velocity:surface:mag < 10 {
    Set desired_up to heading(landing_sideways_heading + 90, 0):vector.
  } else {
    If vang(ship:srfprograde:vector, roll_choice * ship:facing:upvector) > 100 {
      Set roll_choice to -roll_choice.
    }.
    Set desired_up to angleaxis(roll_choice * 90, ship:facing:vector) * vxcl(ship:facing:vector, ship:srfprograde:vector).
//    Set control:roll to 1.0 / current_twr * pid_roll:update(
//      time:seconds,
//      //-vdot(ship:angularvel, ship:facing:forevector)). 
//      roll_choice * ship:facing:upvector * ship:srfprograde:vector).
  }.
//  Set control:pitch to 2.0 / current_twr * pid_pitch:update(time:seconds,
//    -vdot(target_direction, ship:facing:topvector)).
//  Set control:yaw to 4.0 / current_twr * pid_yaw:update(time:seconds,
//    -vdot(target_direction, ship:facing:starvector)).
  Local pre_rotation to 6 * (1 / current_twr) * direction_rotation_controller(
      target_direction,
      desired_up,
      V(0,0,0),
      rotation_kp,
      rotation_kd).
  Set pre_rotation:z to ROLL_FACTOR * pre_rotation:z.
  Set control:rotation to pre_rotation.


  Local min_vertical_speed to 1.0.
  If height < 10 { Set min_vertical_speed to 0.5. }.
  Set pid_throttle:setpoint to -clip(min(sqrt(height), 0.025 * height), min_vertical_speed, 100).
  Update_throttle_toward(clip(0.5 * pid_throttle:update(time:seconds, verticalspeed) + 1 / available_twr,
                              0.1, 1.0)).
  
  If height < 250 and not gear { Gear on. }.
  Wait 0.
}.

Set control:pilotmainthrottle to 0.
Control:neutralize on.

For ctrl_surface in ship:modulesNamed("FARControllableSurface") {
  Ctrl_surface:setfield("std. ctrl", true).
}.
Wait 1.
For ctrl_surface in Ctrl_surface_to_prev_setting:keys {
  Ctrl_surface:setfield("ctrl dflct", ctrl_surface_to_prev_setting[ctrl_surface]).
}.
Goal_arrow:show off.
