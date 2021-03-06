@LAZYGLOBAL OFF.

Local function assert {
  Parameter valid.
  Parameter error_message.
  If not valid {
    Print error_message.
    Print 1/0.
  }
}

Local ZERO_VEC to V(0,0,0).

// "proportional-future controller"
Global function pf_controller {
  Parameter proportional.
  Parameter future_secs. // how many secs in the future based on linear projection
  Parameter min_out is "".
  Parameter max_out is 0.
  If min_out:isType("scalar") {
    Return pidloop(proportional, 0, proportional * future_secs, min_out, max_out).
  } else {
    Return pidloop(proportional, 0, proportional * future_secs).
  }.
}

Local pitch_inertia to 10.0.
Local yaw_inertia to 10.0.
Local roll_inertia to 1.0.
Local prev_facing to ship:facing.
Local prev_time to -1.
Global function direction_rotation_controller {
  Parameter desired_direction.  // vector
  Parameter desired_up.  // vector, ideally orthogonal to desired_direction.
  Parameter desired_angular_velocity.  // vector, radians per second
  Parameter kp, kd.  // scalars

  // moments of inertia based on https://discord.com/channels/210513998876114944/210521083550498816/714767570644893707 by nuggreat
  LOCAL am IS SHIP:ANGULARMOMENTUM.
  LOCAL av TO SHIP:ANGULARVEL * -SHIP:FACING.//x = pitch(w = pos, s = neg), y = yaw(d = pos, a = neg), z  = roll(q = pos, e = neg)
  If abs(av:x) > 1e-6 { Set pitch_inertia to abs(am:x / av:x). }.
  If abs(av:y) > 1e-6 { Set yaw_inertia to abs(am:z / av:y). }.
  If abs(av:z) > 1e-6 { Set roll_inertia to abs(am:y / av:z). }.
  Assert(pitch_inertia > 0 and yaw_inertia > 0 and roll_inertia > 0, "non-positive moment of inertia").
  Local max_inertia to max(max(pitch_inertia, yaw_inertia), roll_inertia).

  Local time_secs to time:seconds.
  Local ship_facing to ship:facing.
  Local current_direction to ship_facing:vector.
  Local comparison_angular_velocity to ZERO_VEC.
  If prev_time > 0 {
    Local ship_facing_up to ship_facing:upvector.
    Set comparison_angular_velocity to
        (vcrs(prev_facing:vector, current_direction) +
         current_direction * (current_direction * vcrs(prev_facing:upvector, ship_facing_up)))
        / (time_secs - prev_time).
  }
  Set prev_facing to ship_facing.
  Set prev_time to time_secs.

  Local delta_omega to desired_angular_velocity - comparison_angular_velocity.

  Local delta_direction to desired_direction:normalized - current_direction.  
  Local delta_direction_mag to constant:degToRad * vang(desired_direction, current_direction).
  Until vang(delta_direction, current_direction) < 15 {
    // We should divide by two to take the midpoint, but since we are normalizing anyway it
    // does not matter.
    Set delta_direction to (delta_direction + current_direction):normalized.
  }.
  Local delta_direction_torque to delta_direction_mag * vcrs(current_direction, delta_direction):normalized.

  Local delta_up_torque to ZERO_VEC.
  If desired_up:mag > 1e-6 {
    Set desired_up to vxcl(desired_direction, desired_up):normalized.
    Local current_up to ship_facing:upvector.
    Local delta_up to desired_up - current_up.  
    Local delta_up_mag to constant:degToRad * vang(desired_up, current_up).
    Until vang(delta_up, current_up) < 15 {
      // We should divide by two to take the midpoint, but since we are normalizing anyway it
      // does not matter.
      Set delta_up to (delta_up + current_up):normalized.
    }.
    Set delta_up_torque to delta_up_mag * vcrs(current_up, delta_up):normalized.
  }.

  Local desired_angular_accel to kp * (delta_direction_torque + delta_up_torque) +
                                 kd * delta_omega.
  Local pitch to (pitch_inertia / max_inertia) * desired_angular_accel * -ship_facing:starvector.
  Local yaw to (yaw_inertia / max_inertia) * desired_angular_accel * ship_facing:upvector.
  Local roll to (roll_inertia / max_inertia) * desired_angular_accel * -current_direction.
  Return V(yaw, pitch, roll).
}.


Global function vector_integral {
  Parameter max_magnitude.
  Local prev_time to -1.
  Local prev_value to ZERO_VEC.
  Local accumulation to ZERO_VEC.
  Return {
    Parameter new_time.
    Parameter new_value.
    If prev_time < 0 {
      Set prev_time to new_time.
      Set prev_value to new_value.
      Set accumulation to ZERO_VEC.
      Return ZERO_VEC.
    }.
    Local delta_t to new_time - prev_time.
    If delta_t <= 0 {
      Set prev_time to new_time.
      Set prev_value to new_value.
      Return accumulation.
    }.
    Set accumulation to accumulation + delta_t * prev_value.
    Set prev_value to new_value.
    Set prev_time to new_time.
    Local accum_mag to accumulation:mag.
    If accum_mag > max_magnitude {
      Set accumulation to accumulation * (max_magnitude / accum_mag).
    }.
    Return accumulation.
  }.
}.

Global function vector_derivative {
  Local prev_time to -1.
  Local prev_value to ZERO_VEC.
  Return {
    Parameter new_time.
    Parameter new_value.
    If prev_time < 0 {
      Set prev_time to new_time.
      Set prev_value to new_value.
      Return ZERO_VEC.
    }.
    Local delta_t to new_time - prev_time.
    If delta_t <= 0 {
      Set prev_time to new_time.
      Set prev_value to new_value.
      Return ZERO_VEC.
    }.
    Local delta_v to new_value - prev_value.
    Set prev_time to new_time.
    Set prev_value to new_value.
    Return delta_v / delta_t.
  }.
}.

Global function scalar_derivative {
  Local prev_time to -1.
  Local prev_value to 0.
  Local prev_output to 0.
  Return {
    Parameter new_time.
    Parameter new_value.
    If prev_time < 0 {
      Set prev_time to new_time.
      Set prev_value to new_value.
      Return 0.
    }.
    Local delta_t to new_time - prev_time.
    If delta_t <= 0 {
      Set prev_time to new_time.
      Set prev_value to new_value.
      Return prev_output.
    }.
    Local delta_v to new_value - prev_value.
    Set prev_time to new_time.
    Set prev_value to new_value.
    Set prev_output to delta_v / delta_t.
    Return prev_output.
  }.
}.

Global function direction_derivative {
  Local prev_time to -1.
  Local prev_direction to 0.
  Return {
    Parameter new_time.
    Parameter new_direction.
    If prev_time < 0 {
      Set prev_time to new_time.
      Set prev_direction to new_direction.
      Return 0.
    }.
    Local delta_t to new_time - prev_time.
    If delta_t <= 0 {
      Set prev_time to new_time.
      Set prev_direction to new_direction.
      Return 0.
    }.
    Local delta_v to vang(new_direction, prev_direction).
    Set prev_time to new_time.
    Set prev_direction to new_direction.
    Return delta_v / delta_t.
  }.
}.
