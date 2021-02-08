@LazyGlobal off.

RunOncePath("0:/my_lib/parts").
RunOncePath("0:/my_lib/rocket_equation").

// Average Isp calculation
// Copied from lib_navigation, altered.
Local function _avg_isp_at {
    Parameter pressure.
    local burnEngines is list().
    list engines in burnEngines.
    local massBurnRate is 0.
    for e in burnEngines {
        if e:ignition {
            set massBurnRate to massBurnRate + e:availableThrustAt(pressure)/(e:ISPAt(pressure) * constant:g0).
        }
    }
    local isp is -1.
    if massBurnRate <> 0 {
        set isp to ship:availablethrustat(pressure) / (massBurnRate * constant:g0).
    }
    return isp.
}

Local booster_root to ship:partstagged("jool_booster_root")[0].
Local booster_initial_mass to mass_with_root(booster_root).
Local booster_dry_mass to dry_mass_with_root(booster_root).
Local booster_final_mass to booster_dry_mass + fuel_for_delta_v(450, booster_dry_mass, _avg_isp_at(1.0)).
Local payload_mass to ship:mass - booster_initial_mass.

Local delta_v_per_burn to split_booster_burn(payload_mass, booster_initial_mass, booster_final_mass, _avg_isp_at(0.0)).

Print delta_v_per_burn.
