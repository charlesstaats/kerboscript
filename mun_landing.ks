@LAZYGLOBAL OFF.

Local bounds to ship:bounds.
Wait until ship:velocity:surface:mag > 0.1 * bounds:bottomaltradar.
Lock throttle to 1.0.
Wait until ship:velocity:surface:mag < 50.
Local pid to pidloop(0.1, 0, 0.3, 0, 1).
Set pid:setpoint to -1.
Lock throttle to pid:update(time:seconds, bounds:bottomaltradar).
Wait until bounds:bottomaltradar < 10.
Unlock throttle.
HUDText("Script finished. Reverting to manual control.", 10, 2, 15, red, false).
