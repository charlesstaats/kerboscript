Local finished is false.
Runpath("0:/silver_dragon/launcher").
On AG2 {
  Launch().
}
On AG3 {
  Set finished to true.
}
Print "Press 2 to launch, 3 to cancel launch script.".
Wait until finished.
