Local finished is false.
On AG2 {
  Runpath("0:/stump/launcher").
  Local params to core:tag:split(",").
  If params:length = 0 {
    Launch().
  } else if params:length = 1 {
    Launch(params[0]:tonumber()).
  } else if params:length = 2 {
    Launch(params[0]:tonumber(), params[1]:tonumber()).
  } else {
    Launch(params[0]:tonumber(), params[1]:tonumber(), params[2]:tonumber()).
  }.
}
Local landing to false.
On AG7 {
  Set landing to true.
}
On AG3 {
  Set finished to true.
}
Print "Press 2 to launch, 7 to land, 3 to cancel.".
Wait until finished or landing.
If landing {
  Runpath("0:/stump/orbit_to_launch_pad").
}.
