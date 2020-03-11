@LAZYGLOBAL OFF.
Parameter INIT_TARGET to 100.

Runoncepath("0:/my_lib/pid_update_slow").

Local control to ship:control.
Local pid_throttle to pidloop(0.1, 0.0, 0.1, -0.25, 0.25).
Set pid_throttle:setpoint to INIT_TARGET.
Local end_now to false.

Local scale_gui to gui(200).
Local label to scale_gui:addlabel("Target altitude: " + INIT_TARGET + " m").
Local slider to scale_gui:addvslider(INIT_TARGET, 200, 0).
Local end_button to scale_gui:addbutton("End hover").

Set slider:onchange to {
  Parameter target_alt.
  Set pid_throttle:setpoint to target_alt.
  Set label:text to "Target altitude: " + round(target_alt) + " m".
}.

Set end_button:onclick to {
  Set end_now to true.
}.

Local bounds to ship:bounds.

//Local thrust_updater to slow_updater(pid_throttle, 1.0, 0.0, 0.5).

On time:seconds {
  Set control:pilotmainthrottle to 0.25 + pid_throttle:update(time:seconds, alt:radar).
//thrust_updater(alt:radar).
  Return not end_now.
}
Scale_gui:show().

Wait until end_now.
Set control:pilotmainthrottle to 0.0.
Control:neutralize on.
Scale_gui:dispose().
