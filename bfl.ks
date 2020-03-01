SAS on.
Wait 0.5.
Set SASMode to "Retrograde".
When verticalspeed > -3 and alt:radar < 1000 then {
  Gear on.
}
When alt:radar < 5000 then {
  Local pid_thrust is pidloop(0.18, 0, 1.0, 0, 1).
  Local bounds is ship:bounds.
  Lock throttle to pid_thrust:update(time:seconds, bounds:bottomaltradar).
  When pid_thrust:output > 0.01 then {
    RCS on.
  }
}
When ship:velocity:surface:mag < 20 then {
  SAS off.
  Local control is ship:control.
  Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
  Local pid_pitch is pidloop(20.0, 5.0, 40.0, -1, 1).
  Local pid_yaw is pidloop(20.0, 5.0, 40.0, -1, 1).
  Local target_direction is body:position:normalized.  // away from SOI body
  On time:seconds {
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Set target_direction to (-ship:srfprograde:forevector:normalized + 10 * up:forevector:normalized):normalized.
    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_direction, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_direction, ship:facing:starvector)).
    Return true.
  }
}
Local should_end is false.
On AG1 { Set should_end to true. }.
Wait until should_end.
