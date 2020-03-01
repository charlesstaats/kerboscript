Local finished is false.
On AG2 {
  Runpath("0:/photon/launcher").
  Launch(20, 18).
}
On AG3 {
  Set finished to true.
}
Print "Press 2 to launch, 3 to cancel launch script.".
Wait until finished.
