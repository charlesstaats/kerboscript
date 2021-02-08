@LazyGlobal off.

Global function fuel_for_delta_v {
  Parameter desired_delta_v.
  Parameter dry_mass.
  Parameter specific_impulse.
  Local exhaust_speed to specific_impulse * CONSTANT:g0.
  Local wet_mass to dry_mass * CONSTANT:e ^ (desired_delta_v / exhaust_speed).
  Return wet_mass - dry_mass.
}.

// If I do a burn, deploy a payload, and then do a second burn to return the
// booster to its previous orbit, how much delta v can the booster afford to
// put into each of these two burns?
Global function split_booster_burn {
  Parameter payload_mass.
  Parameter booster_initial_mass.
  Parameter booster_final_mass.
  Parameter specific_impulse.
  Local payload_over_2booster to payload_mass / (2 * booster_final_mass).
  Local booster_intermediate_over_final to
      sqrt((booster_initial_mass + payload_mass) / booster_final_mass + payload_over_2booster^2)
        - payload_over_2booster. 
  
  Local exhaust_speed to specific_impulse * CONSTANT:g0.
  Return exhaust_speed * ln(booster_intermediate_over_final).
}.
