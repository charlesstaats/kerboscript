@LAZYGLOBAL off.

local steering_var to "kill".
lock steering to steering_var.
local throttle_var to 0.0.
lock throttle to throttle_var.

local bounds to ship:bounds.
local TIME_TO_DESIRED_VELOCITY to 0.1.
local throttle_pid to pidloop(1.0, 0.0, TIME_TO_DESIRED_VELOCITY).

function do_update {
  local weight to ship:mass * body:mu / body:position:sqrmagnitude.
  set throttle_var to 0.1 * throttle_pid:update(time:seconds, ship:verticalspeed) + weight / ship:availablethrust.
  wait 0.
}.

stage.

set throttle_pid:setpoint to 1.0.  // one m/s
until bounds:bottomaltradar > 10 {
  do_update().
}.
set throttle_pid:setpoint to -1.0.
until ship:status = "LANDED" {
  do_update().
}.
