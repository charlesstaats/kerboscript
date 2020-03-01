@LAZYGLOBAL OFF.

Runpath("0:/KSlib/library/lib_circle_nav").
Runpath("0:/KSlib/library/lib_enum").
Runpath("0:/KSlib/library/lib_navigation").
Runpath("0:/my_lib/bisect.ks").
Runpath("0:/my_lib/clip.ks").
Runpath("0:/pump_fuel").

Local control is ship:control.

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

// First of all, put the booster in a purely equatorial orbit.
Wait until abs(ship:latitude) <= 0.01.
KUniverse:TimeWarp:CancelWarp().
Local function burn_direction {
  Local normal_direction is vcrs(ship:prograde:forevector, ship:up:forevector).
  Return choose normal_direction
         if vdot(ship:prograde:forevector, ship:north:forevector) < 0
         else -normal_direction.
}
Local keep_locked is true.
Rcs_lock_to_target({ Return keep_locked. }, burn_direction@).
Wait until vang(ship:facing:forevector, burn_direction()) < 1.
Lock throttle to 0.1.
Wait until abs(ship:orbit:inclination) < 0.01 or vang(ship:facing:forevector, burn_direction()) > 5.
Set keep_locked to false.
Lock throttle to 0.0.

Local transfer_order is all_fuel_to_last_tank().
Transfer_order:activate().
Wait until transfer_order:done().

Local airbrakes is ship:partsdubbedpattern("airbrake").
Local function set_airbrakes {
  Parameter brake_power.
  Parameter steering_power.
  
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

Set target to "Runway West".

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
For line in open("0:/jool_1_profile.csv"):readall {
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
  Set next_log_time to next_log_time + 10.

  Local logentry is time:seconds + "," +
                    altitude + "," +
                    phaseAngle() + "," +
                    ship:velocity:surface:mag + "," +
                    round(ergy()) + "," +
                    round(expected_ergy_at(phaseAngle())).
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

Local AoA_factor to 10 * constant:DegToRad.
Local function lock_surface_retrograde {
  Parameter lock_while_fn.

  Local control is ship:control.
  Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
  Local pid_pitch is pidloop(2.0, 0.2, 480.0, -1, 1).
  Local pid_yaw is pidloop(2.0, 0.2, 480.0, -1, 1).
  Local target_direction is ship:srfretrograde:forevector:normalized.
  Local counter is 0.
  On time:seconds {
    Set counter to counter + 1.
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

  Local control is ship:control.
  Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
  Local pid_pitch is pidloop(5.0, 0.5, 40.0, -1, 1).
  Local pid_yaw is pidloop(5.0, 0.5, 40.0, -1, 1).
  Local target_direction is -target:position:normalized.
  On time:seconds {
    If throttle > 0.001 return false.
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Set target_direction to -target:position:normalized.
    // Experiment: try rotating about "up" rather than directly aiming at the target.
    // (alternative to consider: rotate about "srfretrograde")
    Local upvec is ship:up:forevector.
    Local movedirection is vcrs(ship:facing:forevector, upvec).
    Local target_position is vdot(target_direction, movedirection) * movedirection.
    // WARNING: I'm not sure what will happen when target and "facing" are more than 90 degrees
    // away from each other.

    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_position, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_position, ship:facing:starvector)).
    Return true.
  }
}

Lock rcs_retrograde to true.
Lock_orbit_retrograde({ Return rcs_retrograde. }).

Wait until vang(-ship:facing:forevector, ship:velocity:orbit) < 3 and ship:angularvel:mag < 0.1.
Lock throttle to 0.2.
Wait until alt:periapsis <= 65000.
Unlock throttle.

Lock srf_retrograde to true.
When ship:angularvel:mag < 0.004 then {
  RCS off.
  Lock rcs_retrograde to false.
  Lock_surface_retrograde({ Return srf_retrograde. }).
}

When altitude < 70000 then {
  // We are in the atmosphere now.
  Brakes on.
  Local pid_ergy is pidloop(0.1, 0.05, 0.0, -0.25, 0.25).
  Local pid_ergy_thrust is pidloop(0.1, 0, 0, 0, 1).
  Lock throttle to pid_ergy:update(time:seconds, expected_ergy_at(phaseAngle()) + 1000 - ergy()).
  When altitude < 50000 then { Unlock throttle. }.
  On time:seconds {
    If alt:radar < 10000 {
      Set_airbrakes(1.0, 0.2).
      Return false.
    }
    Set_airbrakes(0.75 + pid_ergy:update(time:seconds, expected_ergy_at(phaseAngle()) - ergy()), 0.3).
    Return true.
  }
}

When alt:radar < 10000 then {
  Lock srf_retrograde to false.
  Lock_anti_target().
}

When ship:velocity:surface:mag < 4 then {
  Gear on.
}
When alt:radar < 5000 then {
  Local pid_thrust is pidloop(0.24, 0, 1.0, 0, 1).
  Set pid_thrust:setpoint to -1.
  Local bounds is ship:bounds.
  Lock throttle to pid_thrust:update(time:seconds, bounds:bottomaltradar).
  When pid_thrust:output > 0.01 then {
    RCS on.
    Local control is ship:control.
    Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
    Local pid_pitch is pidloop(20.0, 5.0, 40.0, -1, 1).
    Local pid_yaw is pidloop(20.0, 5.0, 40.0, -1, 1).
    Local target_direction is body:position:normalized.  // away from SOI body
    On time:seconds {
      Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
      Set target_direction to (-ship:velocity:surface  + 20 * up:forevector:normalized):normalized.
      Set control:pitch to pid_pitch:update(time:seconds,
        -vdot(target_direction, ship:facing:topvector)).
      Set control:yaw to pid_yaw:update(time:seconds,
        -vdot(target_direction, ship:facing:starvector)).
      Return true.
    }
  }
}
Local should_end is false.
On AG1 { Set should_end to true. }.
Wait until should_end.
