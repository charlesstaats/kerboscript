@LAZYGLOBAL OFF.

Local bounds to ship:bounds.
Local TARGET to 0.
Function throttle_func {
  Parameter speed.
  Parameter altitude.
  If ship:verticalspeed > 0 {
    Return 0.
  }
  Set altitude to altitude - TARGET.

  Local sp_kinetic_energy to 0.5 * speed^2.

  Local body to ship:body.
  Local body_g to body:mu / body:radius^2.
  Local sp_potential_energy to body_g * altitude.

  Local specific_energy to sp_kinetic_energy + sp_potential_energy.

  Local sp_work to (ship:availablethrust / ship:mass) * altitude.

  Return 0.01 * (specific_energy - sp_work) + 1.0.
}
Lock throttle to throttle_func(ship:velocity:surface:mag, alt:radar).

Wait until ship:velocity:surface:mag < 50.
Lock throttle to throttle_func(ship:velocity:surface:mag, bounds:bottomaltradar).
Wait until bounds:bottomaltradar < 200.
Gear on.
Local prev_ag3 to AG3.
Wait until AG3 <> prev_ag3.
Unlock throttle.
HUDText("Script finished. Reverting to manual control.", 10, 2, 15, red, true).
