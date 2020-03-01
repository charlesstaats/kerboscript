// Size 3 payload, Size 3 core, 4 engines
Local finished is false.
On AG2 {
  Runpath("0:/giant/launcher").
  // Parameter MAX_TIME_TO_APOAPSIS is 20.
  // Parameter TURN_ANGLE is 12.5.
  // Parameter CONTROL_FACTOR is 1.0.
  Launch(20, 13.5, 0.3).
}
On AG3 {
  Set finished to true.
}
Print "Press 2 to launch, 3 to cancel launch script.".
Wait until finished.
