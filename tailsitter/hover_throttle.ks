@LAZYGLOBAL OFF.

Local start_gui to gui(200).
Local start_button to start_gui:addbutton("Hover").
Local start_program to false.
Set start_button:onclick to {
  Set start_program to true.
}.
Start_gui:show().
Wait until start_program or ABORT.
Start_gui:dispose().

Local pid_throttle to pidloop(0.15, 0.001, 0.1, 0, 1).
Set pid_throttle:setpoint to 0.

Local scale_gui to gui(200).
Local label to scale_gui:addlabel("Target vertical velocity: " + round(pid_throttle:setpoint, 1):tostring + " m/s").
Local slider to scale_gui:addvslider(0.0, 20, -20).
Local end_button to scale_gui:addbutton("Unlock throttle").

Set slider:onchange to {
  Parameter target_alt.
  Set pid_throttle:setpoint to target_alt.
  Set label:text to "Target vertical velocity: " + round(target_alt, 1):tostring + " m/s".
}.

Local end_now to false.
Set end_button:onclick to {
  Set end_now to true.
}.

Local control to ship:control.

On time:seconds {
  Set control:pilotmainthrottle to pid_throttle:update(time:seconds, ship:verticalspeed).
  Return not (end_now or ABORT).
}
Scale_gui:show().

Local bounds to ship:bounds.
When bounds:bottomaltradar < 1.0 then {
  ABORT on.
}

Wait until end_now or ABORT.
Set control:pilotmainthrottle to 0.
Control:neutralize on.
Scale_gui:dispose().
