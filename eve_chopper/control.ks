@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/clip").
RunOncePath("0:/my_lib/controller").
//RunOncePath("0:/my_lib/lib_smoothing").

AG1 on.  // Or toggle? Or directly set everything that needs setting?
Brakes off.

Local former_ag7 to AG7.

Local clockwise_rotor to 0.
Local ccw_rotor to 0.
For rotor in ship:modulesNamed("ModuleRoboticServoRotor") {
  If rotor:getField("rotation direction") {
    Set ccw_rotor to rotor.
  } else {
    Set clockwise_rotor to rotor.
  }.
}.

Local control to ship:control.

Local rotation_kp to 1.0.
Local rotation_kd to 8.0.
Local integrator to vector_integral(0.1).
Local velocity_derivative to vector_derivative().
Local desired_fwd_vel to 0.

Local blades to lex().
For rotor in list(clockwise_rotor, ccw_rotor) {
  For blade in rotor:part:children {
    Set blades[blade] to direction_derivative().
  }.
}.

Local CRITICAL_AOA to 9.  // This is just a guess. Trying to set it at least
// three degrees short of a stall, to ensure that cyclic control will have
// the desired effect. (Increasing the angle of attack by <= 3 degrees must
// increase, not decrease, the lift, otherwise pitch and roll controls will
// not work correctly.)
Local REVERSE_DRAG_SLOPE to tan(5).
Local MAX_DEGREES_PER_SEC to 460 * 360 / 60.
Local function set_blade_AoA {
  Parameter desired_aoa.
  Parameter guidance_up.
  Local meters_per_radian to 3.4.  // It's not clear what part of the blade to measure from.
                                   // Empirically this value seems to more or less work here.
  Local vertical_airspeed to vdot(guidance_up:normalized, ship:velocity:surface).
  If vertical_airspeed < 0 {
    Set desired_aoa to 2 * desired_aoa.
  }.
  For blade in blades:keys {
    Local desired_slope to tan(desired_aoa).
    Local part_facing to vxcl(guidance_up, blade:facing:vector).
    Local degrees_per_sec to blades[blade](time:seconds, part_facing).  // 13 seems to give correct answer?
    //Print degrees_per_sec / 360 * 60.
    Local horiz_airspeed to degrees_per_sec * constant:DegToRad * meters_per_radian.
    //Local horiz_airspeed to vxcl(guidance_up, vel):mag.
    //Print horiz_airspeed.
    Local neutral_slope to 0.
    If horiz_airspeed > 0.1 {
      Set neutral_slope to vertical_airspeed / horiz_airspeed.
    }.
    Set desired_slope to desired_slope + neutral_slope.
    If degrees_per_sec > 0.9 * MAX_DEGREES_PER_SEC {
      Local critical_slope to neutral_slope + tan(CRITICAL_AOA).
      If degrees_per_sec >= MAX_DEGREES_PER_SEC {
        Set desired_slope to critical_slope.
      } else {
        Local frac to (degrees_per_sec - 0.9 * MAX_DEGREES_PER_SEC) / (0.1 * MAX_DEGREES_PER_SEC).
        Set desired_slope to (1 - frac) * desired_slope + frac * critical_slope.
      }.
    }.

//    If desired_slope < REVERSE_DRAG_SLOPE {
//      Set desired_slope to min(REVERSE_DRAG_SLOPE, neutral_slope + tan(CRITICAL_AOA)).
//    }.
    Local desired_angle to arctan(desired_slope).
    //Set desired_angle to clip(desired_angle, -10, 10).
    Local bladeModule to blade:getModule("ModuleControlSurface").  // Helicopter blades ignored by FAR?
    BladeModule:setField("deploy angle", desired_angle).
  }.
//  For rotor in list(clockwise_rotor, ccw_rotor) {
//    Print rotor:getField("current rpm").
//    Local horiz_airspeed to rotor:getField("current rpm") / 60 * constant:PI * meters_per_radian.
//    Local neutral_slope to 0.
//    If abs(horiz_airspeed) > 0.1 {
//      Set neutral_slope to vertical_airspeed / horiz_airspeed.
//    }.
//    Local desired_angle to arctan(desired_slope + neutral_slope).
//    For blade in rotor:part:children {
//      Local bladeModule to blade:getModule("ModuleControlSurface").  // Helicopter blades ignored by FAR?
//      BladeModule:setField("deploy angle", desired_angle).
//    }.
//  }.
}.

On time:seconds {
  If AG7 <> former_ag7 { Return false. }.
  Local desired_up to ship:up:vector.
  Local horiz_velocity to vxcl(desired_up, ship:velocity:surface - desired_fwd_vel * heading(90, 0):vector).
  Set horiz_velocity to horiz_velocity + velocity_derivative(time:seconds, horiz_velocity).
  Set desired_up to clip_to_cone(desired_up - 0.01 * horiz_velocity, desired_up, 10).
  Local desired_direction to vxcl(desired_up, heading(90, 0):vector).
  Local desired_angular_velocity to V(0, 0, 0).
  Local pre_rotation to 4 * direction_rotation_controller(
    desired_direction,
    desired_up,
    desired_angular_velocity,
    rotation_kp,
    rotation_kd 
  ). 
  Set pre_rotation:x to 0.5 * pre_rotation:x.  // Adjust yaw authority.
  Set pre_rotation:y to pre_rotation:y.  // Adjust pitch authority.
  If ship:airspeed > 10 { Set pre_rotation:z to 2 * pre_rotation:z. }.  // Adjust roll authority.
  Set pre_rotation to pre_rotation + 2 * integrator(time:seconds, pre_rotation).
//  If control:pilotyaw <> 0 {
//    Set pre_rotation:x to control:pilotyaw.
//  }.
//  If control:pilotpitch <> 0 {
//    Set pre_rotation:y to control:pilotpitch.
//  }.
//  If control:pilotroll <> 0 {
//    Set pre_rotation:z to control:pilotroll.
//  }.
  Set control:rotation to pre_rotation.

  Local yaw to control:yaw.
  Local ccw_factor to clip(1 + 1.0 * yaw, 0, 1).
  Local clockwise_factor to clip(1 - 1.0 * yaw, 0, 1).
  Ccw_rotor:setField("torque limit(%)", 100 * ccw_factor).
  //Ccw_rotor:setField("rpm limit", 460 * ccw_factor).
  Clockwise_rotor:setField("torque limit(%)", 100 * clockwise_factor).
  //Clockwise_rotor:setField("rpm limit", 460 * clockwise_factor).

  //Local pressure to body:atm:altitudePressure(ship:altitude).
  //Local desired_slope to 0.08 / pressure.
  //Local desired_aoa to arctan(desired_slope).
  Local desired_aoa to 2.5.
  Set_blade_AoA(desired_aoa, ship:facing:upvector).

  Return AG7 = former_ag7.
}.


Wait until AG7 <> former_ag7.

Local heat_shield to ship:partsDubbedPattern("HeatShield")[0].
Local ablator_deriv to scalar_derivative().
//Local throttle_smoother to lib_smoothing:rate_limited(1.0).

Wait 0.1.
Set control:neutralize to true.
Local GRAVTURN_ANGLE to 18.
Lock steering to heading(90, 90 - GRAVTURN_ANGLE).
Local throttle_on to true.
When true then {
  If throttle_on {
    Local ablator_change to ablator_deriv(time:seconds, heat_shield:resources[0]:amount).
    Set control:pilotmainthrottle to clip(1.0 + 20 * ablator_change, 0.1, 1.0).
    Print ablator_change.
  } else {
    Print "Throttle off.".
  }.
  Return throttle_on.
}.
Until ship:availableThrust > 0 {
  Stage.
  Wait 0.1.
}.
// IDEA: Throttle based on ablator resource change.
Wait until ship:verticalspeed > 100 and eta:apoapsis > 20.
Lock steering to ship:srfprograde.
When ship:availableThrust = 0 then {
  Stage.
}.
Wait until ship:orbit:apoapsis >= 95_000.
Set throttle_on to false.
Set control:pilotmainthrottle to 0.
Unlock steering.
Print "Script finished. You're on your own now.".
