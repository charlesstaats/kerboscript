@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/controller").

Global function vector_control_loop {
  Local prev_time to -1.
  Local prev_value to V(0,0,0).
  Local output to V(0,0,0).
  Return {
    Parameter time_secs.
    Parameter new_value.
    Parameter remaining_time.

    If time_secs = prev_time {
      Return choose output if prev_time > 0 else new_value.
    } else if time_secs < prev_time {
      Print 0/0.
    }.

    Set output to new_value.
    If prev_time > 0 {
      Local deriv to (new_value - prev_value) / (time_secs - prev_time).
      Set output to new_value + remaining_time * deriv.
    }.
    Set prev_time to time_secs.
    Set prev_value to new_value.
    Return output.
  }.
}.

Local SEA_LEVEL_MAX_ANGLE to 5.
Function max_angle_to_vertical {
  Parameter ship_altitude.
  If ship_altitude >= 5000 { Return 90. }.
  If ship_altitude <= 0 { Return SEA_LEVEL_MAX_ANGLE. }.
  // Make it a linear function of altitude, with f(5000) = 90, f(0) = SEA_LEVEL_MAX_ANGLE.
  Return SEA_LEVEL_MAX_ANGLE + (90 - SEA_LEVEL_MAX_ANGLE) * (ship_altitude / 5000).
}

Global function current_heading {
  Local direction to ship:srfprograde:vector.
  Return arctan2(direction * ship:north:starvector, direction * ship:north:vector).
}.

Local function time_to_impact {
  Parameter vertical_velocity, height.
  Set height to max(0, height).
  Local accel to -body:mu / body:position:sqrmagnitude.
  Local twice_energy to vertical_velocity * vertical_velocity + 2 * accel * -height.
  Return (-vertical_velocity - sqrt(twice_energy)) / accel.
}.

Global function impact_position_and_time {
  Parameter height, horiz_velocity.
  Local delta_t to time_to_impact(ship:verticalspeed, height).
  Return list(delta_t * horiz_velocity, delta_t).
}.


Global function impact_position_horiz {
  Parameter height, horiz_velocity.
  Local delta_t to time_to_impact(ship:verticalspeed, height).
  Return delta_t * horiz_velocity.
}.

Global function weight {
  Return ship:mass * body:mu / body:position:sqrmagnitude.
}.

Global function reference_frame_angular_velocity {
  Return vcrs(ship:velocity:orbit, body:position) / body:position:sqrmagnitude.
}.

Global function gravitational_acceleration {
  Return body:position:normalized * body:mu / body:position:sqrmagnitude.
}.

Global function srfprograde_angular_velocity {
  Return vcrs(ship:velocity:surface, gravitational_acceleration()) / ship:velocity:surface:sqrmagnitude
    + reference_frame_angular_velocity().
}.

Global function prograde_angular_velocity {
  Return vcrs(ship:velocity:orbit, gravitational_acceleration()) / ship:velocity:orbit:sqrmagnitude.
}.

Global function disable_several_engines {
  Local engine_list to list().
  List engines in engine_list.
  For engine in engine_list {
    If engine:maxthrust > 100 and abs(engine:position * ship:facing:starvector) > 0.2 {
      Engine:shutdown().
    }.
  }.
}.

Global function disable_gimbals {
  Local engine_list to list().
  List engines in engine_list.
  For engine in engine_list {
    If engine:maxthrust > 100 {
      Engine:gimbal:lock on.
    }.
  }.
}.

// Map a horizontal vector onto the starboard-dorsal plane via a rotation.
Global function decompose_horiz {
  Parameter horiz_vector.
  Parameter ship_facing.  // Direction
  Parameter ship_up_vector.
 
  Local rotation_axis to vcrs(ship_facing:vector, ship_up_vector):normalized. 
  Local rotation_angle to vang(ship_facing:vector, -ship_up_vector).

  Return angleAxis(rotation_angle, rotation_axis) * horiz_vector.
  //Return [horiz_vector * ship_facing:starvector, horiz_vector * ship_facing:upvector].
}.

