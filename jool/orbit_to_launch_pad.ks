@LAZYGLOBAL OFF.

Parameter profile is "0:/jool/descent_profile.csv".
Parameter EXTRA_PERIAPSIS_HEIGHT is 0.

Runpath("0:/jool/rcs_lock_to_target").
Runpath("0:/KSlib/library/lib_enum").
Runpath("0:/KSlib/library/lib_navigation").
Runpath("0:/my_lib/bisect").
Runpath("0:/my_lib/clip").
Runpath("0:/my_lib/fake_rcs").
Runpath("0:/pump_fuel").

Set target to "North Launchpad".
Local north_launchpad to Vessel("North Launchpad").
Local south_launchpad to Vessel("South Launchpad").
Lock target_position to (north_launchpad:position + south_launchpad:position) / 2.
FakeRCS:engage().

Local control is ship:control.


Local transfer_order is all_fuel_to_last_tank().
Transfer_order:activate().
Wait until transfer_order:done().

// Wait until we arrive at the appropriate place in orbit.
Local function ergy {
  Local radius is Kerbin:radius.
  Local speed is ship:velocity:surface:mag.
  Local kinetic is speed * speed / 2.
  Local potential is CONSTANT:g0 * radius * (1 - radius / (altitude + radius)).
  Return kinetic + potential.
}

Local airbrakes is ship:partsdubbedpattern("airbrake").
Local function set_airbrakes {
  Parameter brake_power.
  Parameter steering_power is 0.0.
  
  For airbrake in airbrakes {
    Local steering_relevance is vdot(airbrake:rotation:forevector,
        control:yaw*ship:facing:starvector + control:pitch*ship:facing:upvector).
    Local power is clip(brake_power - steering_power * steering_relevance, 0, 1 / 0.7).
    Airbrake:getmodule("ModuleAeroSurface"):setfield("deploy angle", 0.7 * power * 100).
  }
}

Local LOG_TRAJECTORY to false.
If LOG_TRAJECTORY {
  Local log_file is "0:/jool/descent_log.csv".
  Log "time,altitude,phase_angle,airspeed,ergy" to log_file.
  Local next_log_time is time:seconds.
  When time:seconds >= next_log_time then {
    Set next_log_time to next_log_time + (choose 10 if altitude > 15000 else 1).

    Local logentry is time:seconds + "," +
                      altitude + "," +
                      phaseAngle() + "," +
                      ship:velocity:surface:mag + "," +
                      round(ergy()).
    Log logentry to log_file.
    Return true.
  }
}

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
Local ergy_data is list().
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
    Ergy_data:add(tmp).
  }
}

Local pivot to 540.
Local start_at_phase is angle_to_std_range(phase_data[0]).
// Reverse the data since "interpolate" expects phase_data to be sorted in ascending order.
Set altitude_data to Enum:reverse(altitude_data).
Set phase_data to Enum:reverse(phase_data).
Set ergy_data to Enum:reverse(ergy_data).

Local function expected_ergy_at {
  Parameter phase.
  Set phase to angle_to_std_range(phase, pivot).
  Return interpolate(phase, phase_data, ergy_data).
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


When angle_to_std_range(phase_angle, pivot) < 359 then {
  Set pivot to 359.
}

Local function lock_orbit_retrograde {
  Parameter lock_while_fn.

  Rcs_lock_to_target(lock_while_fn@, {
    Return ship:retrograde:forevector.
  }).
}

Local rcs_retrograde to true.
Lock_orbit_retrograde({ Return rcs_retrograde. }).

Wait 15.
Lock throttle to 0.05.
Wait until alt:periapsis <= 65000 + EXTRA_PERIAPSIS_HEIGHT.
Unlock throttle.
Set rcs_retrograde to false.

Local steering_power to 0.3.
Local pid_ergy is pidloop(0.1, 0, 0.0, -0.25, 0.25).
Local pid_alt is pidloop(0.001, 0, 2.56).

Local function lock_altitude_retrograde {
  Parameter lock_while_fn.

  Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
  Local target_direction is ship:srfretrograde:forevector.

  Local pid_pitch is pidloop(2.0, 0.0, 240.0, -1, 1).
  Local pid_yaw is pidloop(2.0, 0.0, 240.0, -1, 1).
  
  Local MAX_VERTICAL_SHIFT to Constant:DegToRad * 15.
  //When ship:Q > 0.15 then { Set MAX_VERTICAL_SHIFT to Constant:DegToRad * 5. }.

  Local next_print_alt_time to time:seconds.
  Local control_already_running to false.
  On time:seconds {
    If control_already_running { Return true. }.
    Set control_already_running to true.
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Local vertical_shift to ship:up:forevector * pid_alt:update(
        time:seconds, altitude - expected_alt_at(phase_angle)).
    If time:seconds >= next_print_alt_time {
      HUDText("altitude error: " + round(pid_alt:input, 1) + "m", 50 / kuniverse:timewarp:rate, 1, 15, green, false).
      HUDText("specific energy error: " + round(-pid_ergy:input, 1) + " m^2/s^2", 50 / kuniverse:timewarp:rate, 3, 15, green, false).
      Set next_print_alt_time to time:seconds + 10.
    }
    If vertical_shift:mag > MAX_VERTICAL_SHIFT {
      Set vertical_shift to MAX_VERTICAL_SHIFT * vertical_shift:normalized.
    }
    Set target_direction to (ship:srfretrograde:forevector  - vertical_shift):normalized.
    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_direction, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_direction, ship:facing:starvector)).
    Local should_repeat to lock_while_fn().
    Set control_already_running to false.
    Return should_repeat.
  }
  When altitude < 60000 then {
    Set pid_pitch:kp to 5.0.
    Set pid_yaw:kp to 5.0.
    When altitude < 25000 then {
      Set pid_pitch to pidloop(5.0, 0.5, 40.0, -0.5, 0.5).
      Set pid_yaw to pidloop(5.0, 0.5, 40.0, -0.5, 0.5).
    }
  }
}

Local function lock_anti_target {

  RCS on.
  Local pid_roll is pidloop(10.0, 0, 20.0, -1, 1).
  Local pid_pitch is pidloop(2.5, 0.25, 10.0, -1, 1).
  Local pid_yaw is pidloop(2.5, 0.25, 10.0, -1, 1).

  Local MAX_DIST_FROM_RETROGRADE to 0.2.
  Local target_direction is -target_position:normalized.
  On time:seconds {
    If throttle > 0.05 {
      Return false.
    }
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector) + 0.5). 
    Set target_direction to -target_position:normalized.
    // Experiment: try rotating about "up" rather than directly aiming at the target.
    // (alternative to consider: rotate about "srfretrograde")
    Set target_direction to (target_direction + 0.5 * (target_direction - ship:up:forevector)):normalized.
    // Don't get too far away from retrograde, to maintain aerodynamic stability.
    Local retro to ship:srfretrograde:forevector.
    If (retro - target_direction):mag > MAX_DIST_FROM_RETROGRADE {
      Set target_direction to (target_direction - vdot(target_direction, retro) * retro):normalized.
      Set target_direction to (retro + MAX_DIST_FROM_RETROGRADE * target_direction):normalized.
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

Local most_recent_pid_ergy_nonpositive to time:seconds.

When altitude < 70000 then {
  // We are in the atmosphere now.
  Brakes on.
  Local control_already_running to false.
  When altitude < 55000 then { 
    Set navmode to "surface".
    On navmode {
      Set navmode to "surface".
      Return true.
    }
  }
  On time:seconds {
    If control_already_running { Return true. }.
    Set control_already_running to true.
    If alt:radar < 20000 {
      Set_airbrakes(1.0).
      Lock throttle to 0.0.
      Return false.
    }
    Set_airbrakes(0.75 + pid_ergy:update(time:seconds, expected_ergy_at(phaseAngle()) - ergy()), steering_power).
    If pid_ergy:output <= 0 {
      Set most_recent_pid_ergy_nonpositive to time:seconds.
    }
    If time:seconds - most_recent_pid_ergy_nonpositive > 60 {
      If pid_alt:input > 100 {
        Lock throttle to 0.04.
      } else {
        Lock throttle to 0.01.
      }
    } else {
      Lock throttle to 0.
    }
    Set control_already_running to false.
    Return true.
  }

  When alt:radar < 20000 then {
    Lock srf_retrograde to false.
    Lock_anti_target().
    When alt:radar < 1000 then {
      Local bounds to ship:bounds.
      Local pid_thrust is pidloop(0.24, 0, 1.0, 0, 1).
      Set pid_thrust:setpoint to 30.
      Lock throttle to pid_thrust:update(time:seconds, bounds:bottomaltradar).
      When (alt:radar < 175 and (target_position - vdot(target_position, ship:up:forevector) * ship:up:forevector):mag < 10)
           or (alt:radar < 75 and target_position:mag > 500)  // The "abort" case.
           then
      {
        Set pid_thrust:setpoint to
            choose -0.5
            if abs(altitude - alt:radar) > 10 
            else -7.0.  // water landing
      }
    }
  }
}

When ship:velocity:surface:mag < 4 then {
  Gear on.
}

Local bounds is ship:bounds.

Local function distortion_vector {
  Local upvec to up:forevector:normalized.
  Local targetvec to target_position.
  Set targetvec to targetvec - vdot(targetvec, upvec) * upvec.
  If targetvec:mag > 500 { Set targetvec to V(0,0,0). }  // The "abort" case.
  Return 0.2 * targetvec + 20 * upvec.
}

When throttle > 0.05 then {
  Lock srf_retrograde to false.
  RCS on.
  Local pid_roll is pidloop(5.0, 10.0, 5.0, -1, 1).
  Local pid_pitch is pidloop(5.0, 1.0, 20.0, -1, 1).
  Local pid_yaw is pidloop(10.0, 1.0, 20.0, -1, 1).
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

Local should_end is false.
On AG1 { Set should_end to true. }.
Wait until should_end.
