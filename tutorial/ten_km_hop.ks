@LAZYGLOBAL off.

runoncepath("0:/KSLib/library/lib_location_constants").

local goal_geo to location_constants:launchpad.
local function goal {
  return goal_geo:position.
}

local steering_var to "kill".
lock steering to steering_var.
local throttle_var to 0.0.
lock throttle to throttle_var.

local bounds_var to ship:bounds.
local TIME_TO_DESIRED_VELOCITY to 0.1.
local throttle_pid to pidloop(1.0, 0.0, TIME_TO_DESIRED_VELOCITY).

local function potential_energy_at_height { 
  parameter height.
  // This is an approximation that assumes the altitude is small compared to the planet's radius.
  return ship:mass * (body:mu / body:radius^2) * height.  // mgh
}

local MIN_THROTTLE to 0.04.
local function update_throttle_going_up {
  local weight to ship:mass * body:mu / body:position:sqrmagnitude.
  set throttle_var to max(MIN_THROTTLE,
      weight / ship:availablethrust + 0.01 * throttle_pid:update(time:seconds, ship:apoapsis)).
}

local function update_throttle_going_down {
  local weight to ship:mass * body:mu / body:position:sqrmagnitude.

  local sheddable_energy to ship:availablethrust * (bounds_var:bottomaltradar - 10).  // work = force * distance
  local potential_energy to potential_energy_at_height(bounds_var:bottomaltradar).
  local desired_kinetic_energy to max(0, sheddable_energy - potential_energy).
  local desired_verticalspeed to sqrt(2 * desired_kinetic_energy / ship:mass).
  set desired_verticalspeed to -0.9 * desired_verticalspeed.
  set desired_verticalspeed to min(-1.0, desired_verticalspeed).
  set throttle_pid:setpoint to desired_verticalspeed.
  set throttle_var to max(MIN_THROTTLE,
      weight / ship:availablethrust + 0.1 * throttle_pid:update(time:seconds, ship:verticalspeed)).
}
local MAX_TILT to 10.  // Allow 10 degrees tilt.
local function update_steering {
  local horiz_velocity to vxcl(ship:up:vector, ship:velocity:surface).
  local desired_horiz_velocity to V(0, 0, 0).
  if bounds_var:bottomaltradar > 30 {
    set desired_horiz_velocity to vxcl(ship:up:vector, 0.2 * goal()).
  }
  local look_at_horiz to 0.02 * (desired_horiz_velocity - horiz_velocity).
  local look_at to ship:up:vector + look_at_horiz.
  if vang(look_at, ship:up:vector) > MAX_TILT {
    set look_at to ship:up:vector + tan(MAX_TILT) * look_at_horiz:normalized. 
  }
  set steering_var to lookdirup(look_at, ship:facing:upvector).
}

stage.

set throttle_pid:setpoint to 10_000.
until ship:altitude > 10_000 {
  update_throttle_going_up().
  update_steering().
  wait 0.
}
set throttle_pid to pidloop(1.0, 0.0, TIME_TO_DESIRED_VELOCITY).
until ship:status = "LANDED" {
  update_throttle_going_down().
  update_steering().
  wait 0.
}
