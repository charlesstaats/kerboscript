@LAZYGLOBAL OFF.

Runpath("0:/KSlib/library/lib_circle_nav").
Runpath("0:/KSlib/library/lib_enum").
Runpath("0:/KSlib/library/lib_navigation").
Runpath("0:/my_lib/bisect.ks").
Runpath("0:/my_lib/clip.ks").
Runpath("0:/pump_fuel").

Local control is ship:control.

Local fake_rcs is ship:partsdubbed("fakeRCS").
Local function set_fake_rcs {
  If RCS {
    For engine in fake_rcs {
      If not engine:ignition { Engine:activate(). }
      Local steering_relevance is vdot(engine:facing:forevector,
          control:yaw*ship:facing:starvector + control:pitch*ship:facing:upvector).
      Local power is clip(steering_relevance, 0, 1).
      Set engine:thrustlimit to 100 * power.
    }
  } else {
    For engine in fake_rcs {
      Set engine:thrustlimit to 0.
      If engine:ignition { Engine:shutdown(). }
    }
  }
}

On time:seconds {
  Set_fake_rcs().
  Return true.
}

Local function rcs_lock_to_target {
  Parameter lock_while_fn.
  Parameter target_direction_fn.

  SAS off.
  RCS on.

  Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
  Local pid_pitch is pidloop(4.8, 0.08, 35, -0.3, 0.3).
  Local pid_yaw is pidloop(4.8, 0.08, 35, -0.3, 0.3).
  On time:seconds {
    If not lock_while_fn() {
      RCS off.
      SAS on.
      Return false.
    }
    Local target_direction to target_direction_fn():normalized.
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_direction, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_direction, ship:facing:starvector)).
    Return true.
  }
}

Local transfer_order is all_fuel_to_tank(2).
Transfer_order:activate().
Wait until transfer_order:done().

Local airbrakes is ship:partsdubbedpattern("airbrake").
Local function set_airbrakes {
  Parameter brake_power.
  Parameter steering_power is 0.0.
  
  For airbrake in airbrakes {
    Local steering_relevance is vdot(airbrake:rotation:forevector,
        control:yaw*ship:facing:starvector + control:pitch*ship:facing:upvector).
    Local power is clip(brake_power - steering_power * steering_relevance, 0, 1).
    Airbrake:getmodule("ModuleAeroSurface"):setfield("authority limiter", power * 100).
  }
}

Set_airbrakes(0.75, 0.0).

Local ctrl_surfaces is ship:partsdubbedpattern("ctrlsrf").
For ctrl_surface in ctrl_surfaces {
  // Reverse all the control surfaces since we are going retrograde.
  Ctrl_surface:getmodule("FARControllableSurface"):setfield("std. ctrl", true).
  Wait 0.5.
  Ctrl_surface:getmodule("FARControllableSurface"):setfield("pitch %", -100).
  Ctrl_surface:getmodule("FARControllableSurface"):setfield("yaw %", -100).
  Ctrl_surface:getmodule("FARControllableSurface"):setfield("roll %", -100).
}

Set target to "Launch pad".
Lock target_position to target:position.//(runway_east:position + runway_west:position) / 2.


Local print_phase is true.
Local next_print_phase_time is time:seconds.
When time:seconds >= next_print_phase_time then {
  If not print_phase { Return false. }.
  HUDText("Current phase angle: " + phaseAngle(), 50 / kuniverse:timewarp:rate, 1, 15, green, false).
  Set next_print_phase_time to time:seconds + 10.
  Return print_phase.
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
For line in open("0:/giant_profile.csv"):readall {
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

Local start_at_phase is angle_to_std_range(phase_data[0]).
// Reverse the data since "interpolate" expects phase_data to be sorted in ascending order.
Set altitude_data to Enum:reverse(altitude_data).
Set phase_data to Enum:reverse(phase_data).
Set ergy_data to Enum:reverse(ergy_data).

Local function expected_ergy_at {
  Parameter phase.
  Set phase to angle_to_std_range(phase, 359).
  Return interpolate(phase, phase_data, ergy_data).
}

Local function expected_alt_at {
  Parameter phase.
  Set phase to angle_to_std_range(phase, 359).
  Return interpolate(phase, phase_data, altitude_data).
}
Local function ergy {
  Local radius is Kerbin:radius.
  Local speed is ship:velocity:surface:mag.
  Local kinetic is speed * speed / 2.
  Local potential is CONSTANT:g0 * radius * (1 - radius / (altitude + radius)).
  Return kinetic + potential.
}

Wait until angle_to_standard_range(phaseAngle() - start_at_phase, 350) <= 0.
Kuniverse:timewarp:cancelwarp().
Print "canceling warp.".

Wait until angle_to_standard_range(phaseAngle() - start_at_phase, 350) >= 0.
Print "current warp rate: " + kuniverse:timewarp:rate.
Set print_phase to false.

Local log_file is "0:/descent_profile_2.csv".
Log "time,altitude,phase_angle,airspeed,ergy,expected_ergy" to log_file.
Local next_log_time is time:seconds.
When time:seconds >= next_log_time then {
  Set next_log_time to next_log_time + (choose 10 if altitude > 15000 else 1).

  Local logentry is time:seconds + "," +
                    altitude + "," +
                    phaseAngle() + "," +
                    ship:velocity:surface:mag + "," +
                    round(ergy()) + "," + round(expected_ergy_at(phaseAngle())).
  Log logentry to log_file.
  Return true.
}

SAS off.
RCS on.


Local function lock_orbit_retrograde {
  Parameter lock_while.

  Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
  Local pid_pitch is pidloop(0.6, 0.01, 3.6, -1, 1).
  Local pid_yaw is pidloop(0.6, 0.01, 3.6, -1, 1).
  Local target_direction is body:position:normalized.  // away from SOI body
  On time:seconds {
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Set target_direction to ship:retrograde:forevector:normalized.
    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_direction, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_direction, ship:facing:starvector)).
    Return lock_while().
  }
}

Local pid_ergy is pidloop(0.1, 0.05, 0.0, -0.25, 0.25).

Local function lock_altitude_retrograde {
  Parameter lock_while_fn.

  Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
  Local pid_pitch is pidloop(2.0, 0.2, 480.0, -1, 1).
  Local pid_yaw is pidloop(2.0, 0.2, 480.0, -1, 1).

  Local pid_alt is pidloop(0.001, 0, 5.12).
  Local target_direction is ship:srfretrograde:forevector.

  Local MAX_VERTICAL_SHIFT to Constant:DegToRad * 15.

  Local next_print_alt_time to time:seconds.
  On time:seconds {
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Local vertical_shift to ship:up:forevector * pid_alt:update(
        time:seconds, altitude - expected_alt_at(phaseAngle())).
    If time:seconds >= next_print_alt_time {
      HUDText("altitude error: " + round(pid_alt:input, 1) + "m", 50 / kuniverse:timewarp:rate, 1, 15, green, false).
      HUDText("energy error: " + round(-pid_ergy:input, 1) + " m^2/s^2", 50 / kuniverse:timewarp:rate, 3, 15, green, false).
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
    Return lock_while_fn().
  }
  When altitude < 60000 then {
    Set pid_pitch to pidloop(10.0, 0.0, 80.0, -0.5, 0.5).
    Set pid_yaw to pidloop(10.0, 0.0, 80.0, -0.5, 0.5).
    When altitude < 25000 then {
      Set pid_pitch to pidloop(5.0, 0.0, 40.0, -0.5, 0.5).
      Set pid_yaw to pidloop(5.0, 0.0, 40.0, -0.5, 0.5).
    }
  }
}

Local function lock_surface_retrograde {
  Parameter lock_while_fn.

  Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
  Local pid_pitch is pidloop(2.0, 0.2, 480.0, -1, 1).
  Local pid_yaw is pidloop(2.0, 0.2, 480.0, -1, 1).
  Local target_direction is ship:srfretrograde:forevector:normalized.
  On time:seconds {
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Set target_direction to ship:srfretrograde:forevector:normalized.
    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_direction, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_direction, ship:facing:starvector)).
    Return lock_while_fn().
  }
  When altitude < 60000 then {
    Set pid_pitch to pidloop(10.0, 1.0, 80.0, -0.5, 0.5).
    Set pid_yaw to pidloop(10.0, 1.0, 80.0, -0.5, 0.5).
    When altitude < 25000 then {
      Set pid_pitch to pidloop(5.0, 0.5, 40.0, -0.5, 0.5).
      Set pid_yaw to pidloop(5.0, 0.5, 40.0, -0.5, 0.5).
    }
  }
}

Local function lock_anti_target {

  RCS on.
  Local control is ship:control.
  Local pid_roll is pidloop(10.0, 0, 20.0, -1, 1).
  Local pid_pitch is pidloop(5.0, 0.5, 20.0, -1, 1).
  Local pid_yaw is pidloop(5.0, 0.5, 20.0, -1, 1).
  Local target_direction is -target_position:normalized.
  Print "lock_anti_target activated".
  On time:seconds {
    If throttle > 0.05 {
      Print "lock_anti_target deactivated.".
      return false.
    }
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector) + 0.5). 
    Set target_direction to -target_position:normalized.
    // Experiment: try rotating about "up" rather than directly aiming at the target.
    // (alternative to consider: rotate about "srfretrograde")
    Set target_direction to (target_direction + 0.5 * (target_direction - ship:up:forevector)):normalized.
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

Lock rcs_retrograde to true.
Lock_orbit_retrograde({ Return rcs_retrograde. }).

Wait until vang(-ship:facing:forevector, ship:velocity:orbit) < 3 and ship:angularvel:mag < 0.1.
Lock throttle to 0.1.
Wait until alt:periapsis <= 65000.
Unlock throttle.

Lock srf_retrograde to true.
When ship:angularvel:mag < 0.004 then {
  RCS off.
  Lock rcs_retrograde to false.
  Lock_altitude_retrograde({ Return srf_retrograde. }).
}

Local most_recent_pid_ergy_nonpositive to time:seconds.

When altitude < 70000 then {
  // We are in the atmosphere now.
  Brakes on.
  //Local pid_ergy_thrust is pidloop(0.1, 0, 0, 0, 1).
  //Lock throttle to pid_ergy_thrust:update(time:seconds, expected_ergy_at(phaseAngle()) + 1000 - ergy()).
  When altitude < 55000 then { 
    Set navmode to "surface".
    On navmode {
      Set navmode to "surface".
      Return true.
    }
    Unlock throttle. 
  }
  Local transfer_order is all_fuel_to_tank(-2).
  When altitude < 30000 then {
    Transfer_order:activate().
  }
  On time:seconds {
    If alt:radar < 20000 {
      Set_airbrakes(1.0).
      Return false.
    }
    Set_airbrakes(0.75 + pid_ergy:update(time:seconds, expected_ergy_at(phaseAngle()) - 1000 - ergy()), 0.3).
    If pid_ergy:output <= 0 {
      Set most_recent_pid_ergy_nonpositive to time:seconds.
    }
    If time:seconds - most_recent_pid_ergy_nonpositive > 300 {
      Lock throttle to 0.01.
    } else {
      Lock throttle to 0.
    }
    Return true.
  }
}

When alt:radar < 20000 then {
  Lock srf_retrograde to false.
  Lock_anti_target().
  Set_airbrakes(1.0, 0.0).
  Local transfer_order is all_fuel_to_last_tank().
  Transfer_order:activate().
}

When ship:velocity:surface:mag < 5 then {
  Gear on.
}

Local bounds is ship:bounds.

Local function distortion_vector {
  Local upvec to up:forevector:normalized.
  Local targetvec to target:position.
  Set targetvec to targetvec - vdot(targetvec, upvec) * upvec.
  If targetvec:mag > 1000 { Set targetvec to V(0,0,0). }  // The "abort" case.
  Return 0.2 * targetvec + 50 * upvec.
}

When throttle > 0.05 then {
  RCS on.
  Local control is ship:control.
  Local pid_roll is pidloop(0.6, 0.0, 0.6, -1, 1).
  Local pid_pitch is pidloop(0.5, 0, 2.0, -1, 1).
  Local pid_yaw is pidloop(0.5, 0, 2.0, -1, 1).
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

When alt:radar < 1000 then {
  Local bounds to ship:bounds.
  Local pid_thrust is pidloop(0.125, 0, 0.5, 0, 1).
  Set pid_thrust:setpoint to 15.
  Lock throttle to pid_thrust:update(time:seconds, bounds:bottomaltradar).
  When (alt:radar < 150 and (target:position - vdot(target:position, ship:up:forevector) * ship:up:forevector):mag < 10)
       or (alt:radar < 100 and target:position:mag > 1000)  // The "abort" case.
       then
  {
    Set pid_thrust:setpoint to
        choose -0.5
        if abs(altitude - alt:radar) > 10 
        else -7.0.  // water landing
  }

}
Local should_end is false.
On AG1 { Set should_end to true. }.
Wait until should_end.
