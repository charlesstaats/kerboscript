Local finished is false.
On AG2 {
  Runpath("0:/giant_2_3_3_1/launcher").
  //Parameter MAX_TIME_TO_APOAPSIS is 20.
  //Parameter TURN_ANGLE is 12.5.
  Launch(23, 20).
}
On AG3 {
  Set finished to true.
}
Print "Press 2 to launch, 3 to cancel launch script.".
Wait until finished.
