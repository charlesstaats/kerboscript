Local finished is false.
On AG2 {
  Runpath("0:/jool/launcher").
  //Parameter MAX_TIME_TO_APOAPSIS is 20.
  //Parameter TURN_ANGLE is 20.
  Launch(23, 16).
}
On AG3 {
  Set finished to true.
}
Print "Press 2 to launch, 3 to cancel launch script.".
Wait until finished.
