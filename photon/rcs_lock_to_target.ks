@LAZYGLOBAL OFF.

Function rcs_lock_to_target {
  Parameter lock_while_fn.
  Parameter target_direction_fn.

  SAS off.
  Local prev_rcs is RCS.
  RCS on.

  Local control is ship:control.

  Local pid_roll is pidloop(10.0, 0.0, 10.0, -1, 1).
  Local pid_pitch is pidloop(1.25, 0.025, 5, -1, 1).
  Local pid_yaw is pidloop(1.25, 0.025, 5, -1, 1).
  On time:seconds {
    If not lock_while_fn() {
      Set RCS to prev_rcs.
      Return false.
    }
    Local target_direction to target_direction_fn():normalized.
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_direction, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_direction, ship:facing:starvector)).
    Return true.
  }
}
