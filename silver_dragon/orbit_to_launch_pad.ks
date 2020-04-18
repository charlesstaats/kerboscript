@LAZYGLOBAL OFF.

Parameter profile is "0:/silver_dragon/prime_descent_profile.csv".
Runpath("0:/KSlib/library/lib_enum").
Runpath("0:/KSlib/library/lib_navigation").
Runpath("0:/my_lib/bisect").
Runpath("0:/my_lib/clip").
Runpath("0:/my_lib/pid_update_slow").
Runpath("0:/my_lib/fake_rcs").
Runpath("0:/pump_fuel").

Set target to "North Launchpad".
Local north_launchpad to Vessel("North Launchpad").
Local south_launchpad to Vessel("South Launchpad").
Lock target_position to (north_launchpad:position + south_launchpad:position) / 2.

Local control is ship:control.

AG5 on.  // Vent any remaining fuel and monopropellant from upper stage.
RCS off.
Local liquid_fuel_tank to ship:partsdubbedpattern("mk3FuselageLF")[0].
Wait until tank_empty(liquid_fuel_tank).

Local transfer_order is all_fuel_to_last_tank().
Transfer_order:activate().
Wait until transfer_order:done().

// Wait until we arrive at the appropriate place in orbit.

Local function specific_energy {
  Local radius is Kerbin:radius.
  Local speed is ship:velocity:surface:mag.
  Local kinetic is speed * speed / 2.
  Local potential is CONSTANT:g0 * radius * (1 - radius / (altitude + radius)).
  Return kinetic + potential.
}

Local airbrakes is ship:partsdubbedpattern("airbrake").
Local function deployed {
  Parameter airbrake.
  Return airbrake:getmodule("ModuleAeroSurface"):getfield("deploy").
}
Local function set_airbrakes {
  Parameter brake_power.
  
  For airbrake in airbrakes {
    If deployed(airbrake) {
      Local power is clip(brake_power, 0, 0.9 / 0.7).
      Airbrake:getmodule("ModuleAeroSurface"):setfield("deploy angle", 0.7 * power * 100).
    }
  }
}
Local function unlock_steering_airbrakes {
  
  For airbrake in airbrakes {
    If not deployed(airbrake) {
      Local module to airbrake:getmodule("ModuleAeroSurface").
      Module:setfield("yaw", false).  // Confusingly, "false" means active, "true" means inactive.
      Module:setfield("pitch", false).  // Confusingly, "false" means active, "true" means inactive.
    }
  }
}

Local LOG_TRAJECTORY to false.
Local phase_angle to phaseAngle().
On time:seconds {
  Set phase_angle to phaseAngle().
  Return true.
}

Local function angle_to_std_range {
  Parameter angle, pivot is 180.
  Until angle <= pivot {
    Set angle to angle - 360.
  }
  Until angle >= pivot - 360 {
    Set angle to angle + 360.
  }
  Return angle.
}
Local angle_to_standard_range is angle_to_std_range@.

Local altitude_data is list().
Local phase_data is list().
Local specific_energy_data is list().
Local header_seen is false.
For line in open(profile):readall {
  If not header_seen {
    Set header_seen to true.
  } else {
    Local numbers is line:split(",").
    Local tmp is numbers[1]:tonumber(-1e99).
    If tmp < -1e98 { Print 0/0. }.
    Altitude_data:add(tmp). 
    Set tmp to numbers[2]:tonumber(-1e99).
    If tmp < -1e98 { Print 0/0. }.
    Phase_data:add(tmp).
    Set tmp to numbers[4]:tonumber(-1e99).
    If tmp < -1e98 { Print 0/0. }.
    specific_energy_data:add(tmp).
  }
}

Local pivot to 540.
Local start_at_phase is angle_to_std_range(phase_data[0]).
// Reverse the data since "interpolate" expects phase_data to be sorted in ascending order.
Set altitude_data to Enum:reverse(altitude_data).
Set phase_data to Enum:reverse(phase_data).
Set specific_energy_data to Enum:reverse(specific_energy_data).

Local function expected_specific_energy_at {
  Parameter phase.
  Set phase to angle_to_std_range(phase, pivot).
  Return interpolate(phase, phase_data, specific_energy_data).
}

Local function expected_alt_at {
  Parameter phase.
  Set phase to angle_to_std_range(phase, pivot).
  Return interpolate(phase, phase_data, altitude_data).
}

Local print_phase is true.
Local next_print_phase_time is time:seconds.
When time:seconds >= next_print_phase_time then {
  If not print_phase { Return false. }.
  HUDText("Angle from starting point: " + angle_to_standard_range(phase_angle - start_at_phase, 10),
          50 / kuniverse:timewarp:rate, 1, 15, green, false).
  Set next_print_phase_time to time:seconds + 10.
  Return print_phase.
}

Wait until angle_to_standard_range(phase_angle - start_at_phase, 10) >= 0.
Kuniverse:timewarp:cancelwarp().
Print "canceling warp.".

Wait until angle_to_standard_range(phase_angle - start_at_phase, 10) <= 0.
Print "current warp rate: " + kuniverse:timewarp:rate.
Set print_phase to false.

If LOG_TRAJECTORY {
  Local log_file is "0:/silver_dragon/prime_descent_log.csv".
  Log "time,altitude,phase_angle,airspeed,specific_energy" to log_file.
  Local next_log_time is time:seconds.
  When time:seconds >= next_log_time then {
    Set next_log_time to next_log_time + (choose 10 if altitude > 15000 else 1).

    Local logentry is time:seconds + "," +
                      altitude + "," +
                      phaseAngle() + "," +
                      ship:velocity:surface:mag + "," +
                      round(specific_energy()).
    Log logentry to log_file.
    Return true.
  }
}


SAS on.
Set navmode to "orbit".
Wait 1.
Set sasmode to "retrograde".
Wait 60.
Lock throttle to 0.05.
Wait until alt:periapsis <= 60000.
Unlock throttle.

AG4 on.  // Allow booster tank to pump fuel to fake RCS engines.
FakeRCS:engage().

When angle_to_std_range(phase_angle, pivot) < 359 then {
  Set pivot to 359.
}

Local pid_specific_energy is pidloop(0.1, 0.05, 0.0, -0.25, 0.25).
Local pid_alt is pidloop(0.0001, 0, 0.04).

Local function lock_altitude_retrograde {
  Parameter lock_while_fn.

  SAS off.
  Local pid_roll is pidloop(0.2, 0.04, 2.0, -1, 1).
  Set pid_roll:setpoint to 0.1.  // Rotate at 0.1 radians per second.

  Local pid_up is pidloop(4.0, 0, 32.0, -1, 1).
  Local pid_south is pidloop(4.0, 0, 32.0, -1, 1).
  When altitude < 50000 then {
    Set pid_up:kd to 8.0.
    Set pid_up:maxoutput to 0.2.
    Set pid_up:minoutput to -0.2.
    Set pid_south:kd to 8.0.
    Set pid_south:maxoutput to 0.2.
    Set pid_south:minoutput to -0.2.
  }
  Local pid_pitch is pidloop(4.0, 0, 32.0, -1, 1).
  Local pid_yaw is pidloop(4.0, 0, 32.0, -1, 1).

  Local target_direction is ship:srfretrograde:forevector.
  
  Local MAX_VERTICAL_SHIFT to Constant:DegToRad * 15.
  When ship:Q > 0.15 then { Set MAX_VERTICAL_SHIFT to Constant:DegToRad * 5. }.

  Local next_print_alt_time to time:seconds.
  On time:seconds {
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Local vertical_shift to ship:up:forevector * pid_alt:update(
        time:seconds, altitude - expected_alt_at(phase_angle)).
    If time:seconds >= next_print_alt_time {
      HUDText("altitude error: " + round(pid_alt:input, 1) + "m", 50 / kuniverse:timewarp:rate, 1, 15, green, false).
      HUDText("specific energy error: " + round(-pid_specific_energy:input, 1) + " m^2/s^2", 50 / kuniverse:timewarp:rate, 3, 15, green, false).
      Set next_print_alt_time to time:seconds + 10.
    }
    If vertical_shift:mag > MAX_VERTICAL_SHIFT {
      Set vertical_shift to MAX_VERTICAL_SHIFT * vertical_shift:normalized.
    }
    Set target_direction to (ship:srfretrograde:forevector  - vertical_shift):normalized.

    Local projected_up to ship:up:forevector.
    Set projected_up to (projected_up - vdot(projected_up, ship:facing:forevector) * ship:facing:forevector):normalized.
    Local control_up to pid_up:update(time:seconds, -vdot(target_direction, projected_up)).
    Local projected_south to -ship:north:forevector.
    Set projected_south to (projected_south - vdot(projected_south, ship:facing:forevector) * ship:facing:forevector):normalized.
    Local control_south to pid_south:update(time:seconds, -vdot(target_direction, projected_south)).
    Local control_vec to control_up * projected_up + control_south * projected_south.
    Local pitch_vec to ship:facing:topvector.
    Set control:pitch to clip(vdot(ship:facing:topvector, control_vec), -1, 1).
    Set control:yaw to clip(vdot(ship:facing:starvector, control_vec), -1, 1).
    Return lock_while_fn().
  }
}

Local function lock_anti_target {

  RCS on.
  Local pid_roll is pidloop(10.0, 0, 20.0, -1, 1).
  Local pid_pitch is pidloop(2.5, 0.25, 10.0, -1, 1).
  Local pid_yaw is pidloop(2.5, 0.25, 10.0, -1, 1).

  Local target_direction is -target_position:normalized.
  On time:seconds {
    If throttle > 0.05 {
      Return false.
    }
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector) + 0.5). 
    Set target_direction to -target_position:normalized.
    // Point a bit down from the "target direction".
    Set target_direction to (target_direction + 0.48 * (target_direction - ship:up:forevector)):normalized.
    // Don't get too far away from retrograde, to maintain aerodynamic stability.
    Local retro to ship:srfretrograde:forevector.
    If (retro - target_direction):mag > 0.2 {
      Set target_direction to (target_direction - vdot(target_direction, retro) * retro):normalized.
      Set target_direction to (retro + 0.2 * target_direction):normalized.
    }

    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_direction, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_direction, ship:facing:starvector)).
    Return true.
  }
}

Lock srf_retrograde to true.
Lock_altitude_retrograde({ Return srf_retrograde. }).

When altitude < 70000 then {
  // We are in the atmosphere now.
  Brakes on.
  Set_airbrakes(0.75).
  Unlock_steering_airbrakes().
  Set navmode to "surface".
  On navmode {
    Set navmode to "surface".
    Return true.
  }
  On time:seconds {
    If alt:radar < 20000 {
      Set_airbrakes(1.0).
      Return false.
    }

    Set_airbrakes(0.75 + pid_specific_energy:update(time:seconds, expected_specific_energy_at(phaseAngle()) - specific_energy())).
    Return true.
  }
}

When alt:radar < 20000 then {
  KUniverse:TimeWarp:CancelWarp().
  Lock srf_retrograde to false.
  Lock_anti_target().
  //When ship:velocity:surface:mag < 300 then {  // NOTE: When https://github.com/KSP-KOS/KOS/issues/2666 is fixed, restore this.
    //Unlock_steering_airbrakes(1.0).
  //}
  When alt:radar < 1000 then {
    Local bounds to ship:bounds.
    Local pid_thrust is pidloop(0.125, 0, 0.45, 0, 1).
    Set pid_thrust:setpoint to 40.
    Lock throttle to pid_thrust:update(time:seconds, bounds:bottomaltradar).
    When (alt:radar < 175 and (target_position - vdot(target_position, ship:up:forevector) * ship:up:forevector):mag < 10)
         or (alt:radar < 115 and target_position:mag > 1000)  // The "abort" case.
         then
    {
      Set pid_thrust:setpoint to
          choose -0.5
          if abs(altitude - alt:radar) > 10 
          else -7.0.  // water landing
    }
  }
}

Local bounds is ship:bounds.

Local function distortion_vector {
  Local upvec to up:forevector:normalized.
  Local targetvec to target_position.
  Set targetvec to targetvec - vdot(targetvec, upvec) * upvec.
  If targetvec:mag > 1000 { Set targetvec to V(0,0,0). }  // The "abort" case.
  Return 0.17 * targetvec + 20 * upvec.
}

When throttle > 0.05 then {
  Lock srf_retrograde to false.
  RCS on.
  Local pid_roll is pidloop(0.2, 0.0, 0.2, -1, 1).
  Local pid_pitch is pidloop(1.0, 0, 4.0, -1, 1).
  Local pid_yaw is pidloop(1.0, 0, 4.0, -1, 1).
  Local target_direction is body:position:normalized.  // away from SOI body
  On time:seconds {
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Set target_direction to (-ship:velocity:surface + distortion_vector()):normalized.
    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_direction, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_direction, ship:facing:starvector)).
    Return true.
  }
}

Wait until ship:status = "LANDED" or ship:status = "SPLASHED".
RCS off.
Lock throttle to 0.
Unlock throttle.
Set control:pilotmainthrottle to 0.0.
Brakes off.
Wait 1.
