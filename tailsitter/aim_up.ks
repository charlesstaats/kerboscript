@LAZYGLOBAL OFF.

Local control is ship:control.

Local start_gui to gui(200).
Local manual_text to "Steer manually".
Local auto_text to "Kill horizontal velocity".
Start_gui:addRadioButton(manual_text, true).
Start_gui:addRadioButton(auto_text, false).
Local aiming_up to false.
Set start_gui:onRadioChange to {
  Parameter which_button.
  If which_button:text = "Steer manually" {
    Set aiming_up to false.
    Control:neutralize on.
  } else {
    Control:neutralize off.
    Set aiming_up to true.
  }
}.
Start_gui:show().

Local pid_roll is pidloop(0.2, 0.0, 0.2, -1, 1).
Local pid_pitch is pidloop(1.0, 0, 4.0, -1, 1).
Local pid_yaw is pidloop(1.0, 0, 4.0, -1, 1).

On time:seconds {
  If aiming_up {
    Local distortion to -ship:velocity:surface.
    If distortion:mag > 10 {
      Set distortion to 10 * distortion:normalized.
    }
    Local target_direction to (distortion + 20 * up:forevector):normalized.
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_direction, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_direction, ship:facing:starvector)).
  }
  Return true.
}

Wait until ABORT.
Start_gui:dispose().
