@LAZYGLOBAL OFF.

Local bounds to ship:bounds.
Local P2I to 2.0.
Function throttle_func {
  Parameter speed.
  Parameter altitude.
  If ship:verticalspeed > 0 {
    Return 0.
  }
  Return 0.1 * (speed^2 - P2I * altitude) + 0.4.
}
Lock throttle to throttle_func(ship:velocity:surface:mag, alt:radar).
Wait until ship:velocity:surface:mag < 50.
Lock throttle to throttle_func(ship:velocity:surface:mag, bounds:bottomaltradar).
Wait until bounds:bottomaltradar < 100.
Gear on.
Local prev_ag3 to AG3.
Wait until AG3 <> prev_ag3.
Unlock throttle.
RCS on.
Set ship:control:fore to -0.2.
Wait 5.
Set ship:control:neutralize to true.
HUDText("Script finished. Reverting to manual control.", 10, 2, 15, red, true).
