@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/exponential_moving_avg").

Global lib_acceleration to lex().

Set lib_acceleration["new"] to {
  Local decay to 3.0.
  Local avg_x to exponential_moving_avg:new(decay).
  Local avg_y to exponential_moving_avg:new(decay).
  Local avg_z to exponential_moving_avg:new(decay).

  Local prev_velocity to V(0,0,0).
  Local prev_time to -1.

  Local retv to lex().
  
  Set retv["update"] to {
    Local current_time to time:seconds.
    Local current_velocity to ship:velocity:orbit.
    If (current_time <= 0) {
      Set prev_velocity to  current_velocity.
      Set prev_time to current_time.
      Return V(0,0,0).
    }
    Local duration to current_time - prev_time.
    If (duration <= 0) {
      Return V(avg_x:get(), avg_y:get(), avg_z:get()).
    }
    Local accel to (current_velocity - prev_velocity) / duration.
    Set prev_velocity to current_velocity.
    Set prev_time to current_time.
    Return V(avg_x:update(current_time, accel:x),
             avg_y:update(current_time, accel:y),
             avg_z:update(current_time, accel:z)).
  }.

  Set retv["get"] to {
    Return V(avg_x:get(), avg_y:get(), avg_z:get()).
  }.

  Set retv["get_experienced"] to {
    Local accel_vec to retv:get().
    Local gravity_accel to -ship:up:forevector * ship:body:mu / (
        ship:body:position - ship:position):sqrmagnitude.
    Return accel_vec - gravity_accel.
  }.

  Return retv.
}.
