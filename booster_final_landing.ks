@LAZYGLOBAL OFF.

Runpath("0:/KSlib/library/lib_circle_nav").
Runpath("0:/KSlib/library/lib_enum").
Runpath("0:/KSlib/library/lib_navigation").
Runpath("0:/my_lib/bisect.ks").
Runpath("0:/my_lib/clip.ks").
Runpath("0:/pump_fuel").

Set navmode to "surface".

Local control is ship:control.

Local runway_east to vessel("Runway East").
Local runway_west to vessel("Runway West").
Lock target_position to (runway_east:position + runway_west:position) / 2.

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

Local fake_rcs is ship:partsdubbed("fakeRCS").
Local function set_fake_rcs {
  For engine in fake_rcs {
    Local steering_relevance is vdot(engine:rotation:forevector,
        control:yaw*ship:facing:starvector + control:pitch*ship:facing:upvector).
    Local power is clip(steering_relevance, 0, 1).
    Set engine:thrustlimit to 100 * power.
  }
}


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

Set target to "Runway East".

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

Local function lock_anti_target {

  RCS on.
  Local control is ship:control.
  Local pid_roll is pidloop(10.0, 0, 10.0, -1, 1).
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
    Set target_direction to (target_direction + 0.9 * (target_direction - ship:up:forevector)):normalized.

    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(target_direction, ship:facing:topvector)).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(target_direction, ship:facing:starvector)).
    Return true.
  }
}

When altitude < 70000 then {
  // We are in the atmosphere now.
  Brakes on.
  On time:seconds {
    If alt:radar < 13000 {
      If throttle >= 0.05 {
        Set_airbrakes(1.0, 0.0).
        Return false.
      }
      Set_airbrakes(1.0, 0.3).
      Return true.
    }
    Return true.
  }
}

Brakes on.

When alt:radar < 13000 then {
  Lock_anti_target().
}

When ship:velocity:surface:mag < 5 then {
  Gear on.
}

Local bounds is ship:bounds.
When ship:velocity:surface:mag < 0.3 and bounds:bottomaltradar < 0.1 and vang(ship:facing:forevector, ship:up:forevector) < 10 then {
  Brakes off.
  RCS off.
}

Local function distortion_vector {
  Local upvec to up:forevector:normalized.
  Local targetvec to target_position.
  Set targetvec to targetvec - vdot(targetvec, upvec) * upvec.
  Return 0.2 * targetvec + 20 * upvec.
}

When throttle > 0.05 then {
  RCS on.
  Local control is ship:control.
  Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
  Local pid_pitch is pidloop(20.0, 5.0, 40.0, -1, 1).
  Local pid_yaw is pidloop(20.0, 5.0, 40.0, -1, 1).
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

When alt:radar < 900 then {
  Lock throttle to 0.3.  // Give it a chance to spin around before going to full throttle.
}

When alt:radar < 800 then {
  Local pid_thrust is pidloop(0.24, 0, 1.0, 0, 1).
  Set pid_thrust:setpoint to -0.5.
  Local bounds is ship:bounds.
  Lock throttle to pid_thrust:update(time:seconds, bounds:bottomaltradar).
}
Local should_end is false.
On AG1 { Set should_end to true. }.
Wait until should_end.
