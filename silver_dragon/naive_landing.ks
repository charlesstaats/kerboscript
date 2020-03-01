@LAZYGLOBAL OFF.

Runpath("0:/KSlib/library/lib_enum").
Runpath("0:/KSlib/library/lib_navigation").
Runpath("0:/my_lib/bisect").
Runpath("0:/my_lib/clip").
Runpath("0:/pump_fuel").
Runpath("0:/my_lib/fake_rcs").

Set target to "Launch pad".

Local control is ship:control.

AG5 on.  // Vent any remaining fuel and monopropellant from upper stage.
Local liquid_fuel_tank to ship:partsdubbedpattern("mk3FuselageLF")[0].
Wait until tank_empty(liquid_fuel_tank).

Local transfer_order is all_fuel_to_last_tank().
Transfer_order:activate().
Wait until transfer_order:done().

// Next task: Normally, wait until we arrive at the appropriate place in orbit.
// But for a logging-only run, set up logging instead.

Local function ergy {
  Local radius is Kerbin:radius.
  Local speed is ship:velocity:surface:mag.
  Local kinetic is speed * speed / 2.
  Local potential is CONSTANT:g0 * radius * (1 - radius / (altitude + radius)).
  Return kinetic + potential.
}

Local log_file is "0:/silver_dragon/descent_log.csv".
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

Local airbrakes is ship:partsdubbedpattern("airbrake").
Local function deployed {
  Parameter airbrake.
  Return airbrake:getmodule("ModuleAeroSurface"):getfield("deploy").
}
Local function set_airbrakes {
  Parameter brake_power.
  
  For airbrake in airbrakes {
    If deployed(airbrake) {
      Local power is clip(brake_power, 0, 1).
      Airbrake:getmodule("ModuleAeroSurface"):setfield("authority limiter", power * 100).
    }
  }
}
Local function unlock_steering_airbrakes {
  Parameter steering_power.
  
  For airbrake in airbrakes {
    If not deployed(airbrake) {
      Local power is clip(steering_power, 0, 1).
      Airbrake:getmodule("ModuleAeroSurface"):setfield("authority limiter", power * 100).
    }
  }
}


Local function expected_alt_at {
  Parameter phase.
  // Dummy function for naive landing only.
  Return ship:altitude.
}

Local function lock_altitude_retrograde {
  SAS off.
  Parameter lock_while_fn.

  Local pid_roll is pidloop(0.1, 0.02, 1.0, -1, 1).
  Set pid_roll:setpoint to 0.1.  // Rotate at 0.1 radians per second.
  // NOTE: Modification needed to make roll work.
  // 1. Compute the "ideal pitch" and the "ideal yaw" that ignore the current roll. Use pid here.
  // 2. Translate these into the current pitch and roll without using pid controllers.
  // Alternative (complementary?) note: To stop precessing, I need to target angular velocity, not
  // a specific location.
  Local pid_pitch is pidloop(8.0, 0, 64.0, -1, 1).
  Local pid_yaw is pidloop(8.0, 0, 64.0, -1, 1).

//  Local pid_ang_pitch is pidloop(0.1, 0.01, 1.0).
//  Local pid_ang_yaw is pidloop(0.1, 0.01, 1.0).

  Local pid_alt is pidloop(0.01, 0.0001, 0.02).
  Local target_direction is ship:srfretrograde:forevector.
  
  // Pitch tail down to slow down descent and reduce reentry heating.
  Local angle_of_attack to 0.

  Local MAX_VERTICAL_SHIFT to Constant:DegToRad * 15.

  On time:seconds {
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    //Set control:roll to pid_roll:update(time:seconds, vdot(-ship:up:forevector, ship:facing:starvector)).
    Local vertical_shift to ship:up:forevector * pid_alt:update(
        time:seconds, altitude - expected_alt_at(0)).//phaseAngle())).
    // This approximates the angle of attack as long as the angle is small and the retrograde direction
    // is horizontal.
    Set vertical_shift to -CONSTANT:DegToRad * angle_of_attack * ship:up:forevector.
    If vertical_shift:mag > MAX_VERTICAL_SHIFT {
      Set vertical_shift to MAX_VERTICAL_SHIFT * vertical_shift:normalized.
    }
    Set target_direction to (ship:srfretrograde:forevector  - vertical_shift):normalized.

    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_direction, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_direction, ship:facing:starvector)).
//    Set pid_pitch:setpoint to pid_ang_pitch:update(time:seconds,
//      vdot(target_direction, ship:facing:topvector)).
//    Set pid_yaw:setpoint to pid_ang_yaw:update(time:seconds,
//      -vdot(target_direction, ship:facing:starvector)).
//    Set control:pitch to pid_pitch:update(time:seconds, -vdot(ship:angularvel, ship:facing:starvector)).
//    Set control:yaw to pid_yaw:update(time:seconds, -vdot(ship:angularvel, ship:facing:upvector)).
    Return lock_while_fn().
  }
}

Local function lock_anti_target {
  RCS on.
  Local control is ship:control.
  Local pid_roll is pidloop(10.0, 0, 20.0, -1, 1).
  Local pid_pitch is pidloop(2.5, 0.25, 10.0, -1, 1).
  Local pid_yaw is pidloop(2.5, 0.25, 10.0, -1, 1).
  Local target_direction is ship:srfretrograde:forevector.
  // Pitch tail down to slow down descent and reduce reentry heating.
  Local angle_of_attack to -1.5.
  On time:seconds {
    If throttle > 0.05 {
      Return false.
    }
    Local vertical_shift to -CONSTANT:DegToRad * angle_of_attack * ship:up:forevector.
    Set target_direction to (ship:srfretrograde:forevector  - vertical_shift):normalized.
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector) + 0.5). 

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
  Set_airbrakes(0.8).
  Unlock_steering_airbrakes(1.0).
  When alt:radar < 20000 then {
    Set_airbrakes(1.0).
    Lock srf_retrograde to false.
    Lock_anti_target().
    When alt:radar < 1000 then {
      Local bounds to ship:bounds.
      Local pid_thrust is pidloop(0.125, 0, 0.5, 0, 1).
      Set pid_thrust:setpoint to -0.5.
      Lock throttle to pid_thrust:update(time:seconds, bounds:bottomaltradar).
    }
  }
}

When ship:velocity:surface:mag < 5 then {
  Gear on.
}

Local bounds is ship:bounds.

Local function distortion_vector {
  Local upvec to up:forevector:normalized.
  Local targetvec to V(0,0,0).//target:position.
  Set targetvec to targetvec - vdot(targetvec, upvec) * upvec.
  Return 0.2 * targetvec + 50 * upvec.
}

When throttle > 0.05 then {
  Lock srf_retrograde to false.
  RCS on.
  Local control is ship:control.
  Local pid_roll is pidloop(0.6, 0.0, 0.6, -1, 1).
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

Local should_end is false.
On AG1 { Set should_end to true. }.
Wait until should_end.
