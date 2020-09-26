@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/clip").
RunOncePath("0:/my_lib/controller").
RunOncePath("0:/my_lib/lib_smoothing").

Local function set_propeller_power {
  Parameter rotor_module.
  Parameter power.

  //Rotor_module:setfield("torque limit(%)", 100 * power).
  Rotor_module:setfield("rpm limit", 460 * power).
}

Local rotor_modules to ship:modulesNamed("ModuleRoboticServoRotor").
Local rotor_to_module to lex().
For rotor_module in rotor_modules {
  Set rotor_to_module[rotor_module:part] to rotor_module.
}.

Local yaw_plus to list().
For rotor in ship:partsDubbedPattern("yaw\+") {
  Yaw_plus:add(Rotor_to_module[rotor]).
}.
Local yaw_minus to list().
For rotor in ship:partsDubbedPattern("yaw-") {
  Yaw_minus:add(rotor_to_module[rotor]).
}.
Local pitch_plus to list().
For rotor in ship:partsDubbedPattern("pitch\+") {
  Pitch_plus:add(rotor_to_module[rotor]).
}.
Local pitch_minus to list().
For rotor in ship:partsDubbedPattern("pitch-") {
  Pitch_minus:add(rotor_to_module[rotor]).
}.
Local roll_plus to list().
For rotor in ship:partsDubbedPattern("roll\+") {
  Roll_plus:add(rotor_to_module[rotor]).
}.
Local roll_minus to list().
For rotor in ship:partsDubbedPattern("roll-") {
  Roll_minus:add(rotor_to_module[rotor]).
}.

//Local default_power to 0.55.  // Roughly the amount of power needed to stay aloft.

Local function set_power_for {
  Parameter throt, pitch, yaw, roll.

  Set throt to clip(throt, 0.05, 0.9).
  Local computed_power to lex().
  For rotor in rotor_modules {
    Set computed_power[rotor] to throt.
  }.
  Local factor to min(throt, 1 - throt).
  For rotor in yaw_plus {
    Set computed_power[rotor] to computed_power[rotor] + factor * yaw.
  }.
  For rotor in yaw_minus {
    Set computed_power[rotor] to computed_power[rotor] - factor * yaw.
  }.
  For rotor in pitch_plus {
    Set computed_power[rotor] to computed_power[rotor] + factor * pitch.
  }.
  For rotor in pitch_minus {
    Set computed_power[rotor] to computed_power[rotor] - factor * pitch.
  }.
  For rotor in roll_plus {
    Set computed_power[rotor] to computed_power[rotor] + factor * roll.
  }.
  For rotor in roll_minus {
    Set computed_power[rotor] to computed_power[rotor] - factor * roll.
  }.

  For rotor in rotor_modules {
    Set_propeller_power(rotor, computed_power[rotor]).
  }.
}.

Local control to ship:control.
When true then {
  Set_power_for(control:pilotmainthrottle, control:pitch, control:yaw, control:roll).
  Return true.
}.

Local updates_per_second to 50.
Local target_altitude to 300.
Local max_speed to 20.
Local smoothed_throt to lib_smoothing:exponential_moving_avg().
Local smoothed_control to lib_smoothing:exponential_moving_avg(1.0).
Local control_bias to V(0,0,0).
// Set pitch, yaw, and roll based on pilot input using direction_rotation_controller:
// pitch -> facing:upvector component of desired_direction. (TODO: make this behave like trim.)
// roll -> facing:starvector component of desired_up.
// yaw -> facing:upvector component of desired_angular_velocity.
On round(updates_per_second * time:seconds) {
  Local facing_dir to ship:facing.
  Local time_secs to time:seconds.
  If ship:airspeed > max_speed {
    Set control:pilotmainthrottle to smoothed_throt:update(time_secs, choose 0.5 if ship:velocity:surface * facing_dir:upvector > 0 else 1).
  } else {
    Set control:pilotmainthrottle to smoothed_throt:update(time_secs, clip(0.1 * (target_altitude - (ship:altitude + 4*ship:verticalspeed)), 0, 1)).
  }.


  // Note: not excluding ship:up:vector from facing_dir:vector should hopefully make this behave
  // like trim.
  Local desired_direction to facing_dir:vector + control:pilotpitch * facing_dir:upvector.//-ship:north:starvector.
  Local desired_up to ship:up:vector + control:pilotroll * facing_dir:starvector.
  Local desired_angular_velocity to 0.3 * control:pilotyaw * facing_dir:upvector.
  Local pre_rotation to direction_rotation_controller(desired_direction,
                                                      desired_up,
                                                      desired_angular_velocity, 
                                                      0.2,
                                                      8.0).
  Set control_bias to control_bias + pre_rotation / (10 * updates_per_second).
  Set control:rotation to smoothed_control:update(time_secs, pre_rotation + control_bias).
  Return true.
}.

//Vecdraw(V(0,0,0), { Return ship:angularvel. }, blue, "", 5.0, true).

Wait until false.
