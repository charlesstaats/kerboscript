@LAZYGLOBAL off.

runoncepath("0:/KSLib/library/lib_location_constants").

local goal_geo to location_constants:reverse_runway_start.
local function goal {
  return goal_geo:position.
}

local steering_var to "kill".
lock steering to steering_var.
local throttle_var to 0.0.
lock throttle to throttle_var.

local bounds to ship:bounds.
local TIME_TO_DESIRED_VELOCITY to 0.1.
local throttle_pid to pidloop(1.0, 0.0, TIME_TO_DESIRED_VELOCITY).

local MAX_TILT to 10.  // Allow 10 degrees tilt.
local function update_throttle {
  local weight to ship:mass * body:mu / body:position:sqrmagnitude.
  set throttle_var to 0.1 * throttle_pid:update(time:seconds, ship:verticalspeed) + weight / ship:availablethrust.
}
local function update_steering {
  local horiz_velocity to vxcl(ship:up:vector, ship:velocity:surface).
  local desired_horiz_velocity to V(0, 0, 0).
  if bounds:bottomaltradar > 30 {
    set desired_horiz_velocity to vxcl(ship:up:vector, 0.05 * goal()).
  }
  local look_at_horiz to 0.01 * (desired_horiz_velocity - horiz_velocity).
  local look_at to ship:up:vector + look_at_horiz.
  if vang(look_at, ship:up:vector) > MAX_TILT {
    set look_at to ship:up:vector + tan(MAX_TILT) * look_at_horiz:normalized. 
  }
  set steering_var to lookdirup(look_at, ship:facing:upvector).
  wait 0.
}

stage.

set throttle_pid:setpoint to 1.0.  // one m/s
until bounds:bottomaltradar > 100 {
  update_throttle().
  update_steering().
  wait 0.
}
set throttle_pid:setpoint to -1.0.
until ship:status = "LANDED" {
  update_throttle().
  update_steering().
  wait 0.
}
