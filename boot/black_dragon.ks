Local finished is false.
On AG2 {
  Runpath("0:/black_dragon/launcher").
  Local params to core:tag:split(",").
  // Parameter MAX_TIME_TO_APOAPSIS is 20.
  // Parameter TURN_ANGLE is 20.
  Launch(params[0]:tonumber(), params[1]:tonumber()).
}
Local landing to false.
On AG7 {
  Set landing to true.
}
On AG3 {
  Set finished to true.
}
Print "Press 2 to launch, 3 to cancel launch script.".
Wait until finished or landing.
If landing {
  Runpath("0:/black_dragon/orbit_to_launch_pad").
}.
