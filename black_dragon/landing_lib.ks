@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/controller").

Local pitch_inertia to 10.0.
Local yaw_inertia to 10.0.
Local roll_inertia to 1.0.
Local prev_angular_velocity to V(0,0,0).
Local prev_time to -1.
Global function direction_rotation_controller {
  Parameter desired_direction.  // vector
  Parameter desired_angular_velocity.  // vector, radians per second
  Parameter kp, kd.  // scalars
  Parameter future to 0.0.

  // moments of inertia based on https://discord.com/channels/210513998876114944/210521083550498816/714767570644893707 by nuggreat
  LOCAL am IS SHIP:ANGULARMOMENTUM.
  LOCAL av TO SHIP:ANGULARVEL * -SHIP:FACING.//x = pitch(w = pos, s = neg), y = yaw(d = pos, a = neg), z  = roll(q = pos, e = neg)
  If abs(av:x) > 1e-6 { Set pitch_inertia to abs(am:x / av:x). }.
  If abs(av:y) > 1e-6 { Set yaw_inertia to abs(am:z / av:y). }.
  If abs(av:z) > 1e-6 { Set roll_inertia to abs(am:y / av:z). }.
  Local max_inertia to max(max(pitch_inertia, yaw_inertia), roll_inertia).

  Local comparison_angular_velocity to ship:angularvel.
  Local time_secs to time:seconds.
  If prev_time > 0 {
    Local duration to time_secs - prev_time.
    If duration > 0 and duration < 4 {
      Local angular_accel to (comparison_angular_velocity - prev_angular_velocity) / duration.
      Set prev_angular_velocity to comparison_angular_velocity.
      Set comparison_angular_velocity to comparison_angular_velocity + future * angular_accel.
    } else {
      Set prev_angular_velocity to comparison_angular_velocity.
    }.
  } else {
    Set prev_angular_velocity to comparison_angular_velocity.
  }.
  Set prev_time to time_secs.

  Local delta_omega to desired_angular_velocity - comparison_angular_velocity.

  Local ship_facing to ship:facing.
  Local current_direction to ship_facing:vector.
  Local delta_direction to desired_direction:normalized - current_direction.  
  Local delta_direction_mag to constant:degToRad * vang(desired_direction, current_direction).
  Until vang(delta_direction, current_direction) < 15 {
    // We should divide by two to take the midpoint, but since we are normalizing anyway it
    // does not matter.
    Set delta_direction to (delta_direction + current_direction):normalized.
  }.
  Local delta_direction_torque to delta_direction_mag * vcrs(current_direction, delta_direction):normalized.
  Local desired_angular_accel to kp * delta_direction_torque +
                                 kd * delta_omega.
  Local pitch to (pitch_inertia / max_inertia) * desired_angular_accel * -ship_facing:starvector.
  Local yaw to (yaw_inertia / max_inertia) * desired_angular_accel * ship_facing:upvector.
  Local roll to (roll_inertia / max_inertia) * desired_angular_accel * -current_direction.
  Return V(yaw, pitch, roll).
}.

Global function disable_verniers {
  For thruster in ship:partsDubbedPattern("vernier") {
    Thruster:getModule("ModuleRCSFX"):setField("thrust limiter", 0.0).
  }.
}.

Function max_angle_to_vertical {
  Parameter ship_altitude.
  If ship_altitude >= 20000 { Return 90. }.
  If ship_altitude <= 0 { Return 40. }.
  // Make it a linear function of altitude, with f(20000) = 90, f(0) = 40.
  Return 40 + 50 * (ship_altitude / 20000).
}

Global function current_heading {
  Local direction to ship:srfprograde:vector.
  Return arctan2(direction * ship:north:starvector, direction * ship:north:vector).
}.

Local function time_to_impact {
  Parameter vertical_velocity, height.
  Local accel to -body:mu / body:position:sqrmagnitude.
  Local twice_energy to vertical_velocity * vertical_velocity + 2 * accel * -height.
  Return (-vertical_velocity - sqrt(twice_energy)) / accel.
}.

Global function impact_position_horiz {
  Parameter height, horiz_velocity.
  Local delta_t to time_to_impact(ship:verticalspeed, height).
  Return delta_t * horiz_velocity.
}.

Global function weight {
  Return ship:mass * body:mu / body:position:sqrmagnitude.
}.
