@LAZYGLOBAL OFF.
// Detach when liquid fuel per booster < 2200
Local DETACH_WHEN_FUEL_IS to 2200.

RunOncePath("0:/my_lib/fake_rcs").
RunOncePath("0:/my_lib/pump_fuel").

Local is_port_booster to (vdot(core:part:position - ship:position, ship:facing:starvector) < 0).
Print "is_port_booster: " + is_port_booster.

Local side_fuel_resources to list().
For tank in ship:partsdubbedpattern("side_fuel") {
  For resource in tank:resources {
    If resource:name = "liquidfuel" {
      Side_fuel_resources:add(resource).
    }.
  }.
}.

Local side_engines to ship:partsdubbedpattern("KE-1").

Function side_fuel_remaining {
  Local total_fuel to 0.0.
  For fuel_resource in side_fuel_resources { 
    Set total_fuel to total_fuel + fuel_resource:amount.
  }.
  Return total_fuel.
}


If is_port_booster {
  Wait until side_fuel_remaining() <= 2 * DETACH_WHEN_FUEL_IS.  // Includes both side boosters.
} else {
  Wait until alt:radar > 1000.  // Ensure init_stage is not triggered when rocket lifts off.
  Local init_stage to stage:number.
  Wait until stage:number <> init_stage.
}
Local SEPARATION_TIME to time:seconds.
If is_port_booster {
  For engine in side_engines {
    Engine:shutdown().
  }
  Stage.
}
Local control is ship:control.
FakeRCS:engage().
RCS on.
// Try to veer away from the core stage.
// For some reason, the starboard booster has its starboard vector inverted.
Set control:starboard to choose -1.0 if is_port_booster else -1.0.
Print "translation: " + control:translation.
Print "starvector: " + ship:facing:starvector.

Local side_engines to ship:partsdubbedpattern("KE-1"). // Stop considering the other booster's engines.

Local ctrl_surfaces is ship:partsdubbedpattern("ctrlsrf").
For ctrl_surface in ctrl_surfaces {
  Ctrl_surface:getmodule("FARControllableSurface"):setfield("std. ctrl", true).
}

Local north_launchpad to Vessel("North Launchpad").
Local south_launchpad to Vessel("South Launchpad").
Local launchpad_northvec to north_launchpad:north:forevector.
Local launchpad_eastvec to north_launchpad:north:starvector.
Local target_margin to V(0, 0, 0).
If is_port_booster {
  Set target_margin to -50 * launchpad_northvec.
} else {
  Set target_margin to 50 * launchpad_northvec.
}
Lock target_position to (north_launchpad:position + south_launchpad:position) / 2 + target_margin.

Lock throttle to 0.0.
For engine in side_engines {
  Engine:activate().
}

Local transfer_order is all_fuel_to_first_tank().
Transfer_order:activate().

Local function init_target_direction {
  Local retv to target_position:normalized.
  // Project to horizontal.
  Set retv to
      (retv - vdot(retv, ship:up:forevector) * ship:up:forevector):normalized.
  // Point up a bit.
  Set retv to (retv + 0.1 * ship:up:forevector):normalized.
  Return retv.
}

Local moving_forwards to true.
On time:seconds {
  Set moving_forwards to (vdot(ship:facing:forevector, ship:velocity:surface) > 0).
  Return true.
}
Local function fore_times {
  If moving_forwards {
    Return 1.0.
  } else {
    Return -1.0.
  }
}

Local function lock_target {
  Parameter lock_while_fn.
  Local pid_roll is pidloop(5.0, 0, 0.0, -1, 1).
  Local pid_pitch is pidloop(5.0, 0.0, 0.0, -1, 1).
  Local pid_yaw is pidloop(5.0, 0.0, 0.0, -1, 1).

  On time:seconds {
    Local direction to init_target_direction().

    Set control:pitch to pid_pitch:update(time:seconds,
      -vdot(direction, ship:facing:topvector)) + 10 * vdot(ship:facing:starvector, ship:angularvel).
    Set control:yaw to pid_yaw:update(time:seconds,
      -vdot(direction, ship:facing:starvector)) - 10 * vdot(ship:facing:upvector, ship:angularvel).
    Set control:roll to pid_roll:update(time:seconds,
      vdot((fore_times() * ship:velocity:surface:normalized - direction):normalized, ship:facing:upvector)) + 10 * vdot(ship:facing:forevector, ship:angularvel).
    Return lock_while_fn().
  }
}
Local function lock_anti_target {
  Parameter anti_fn.

  RCS on.
  Local MAX_TO_RETROGRADE to 0.4.

  Local target_direction is anti_fn() * target_position:normalized.
  On time:seconds {
    If throttle > 0.05 or brakes {
      RCS off.
      Return false.
    }
    Set target_direction to anti_fn() * target_position:normalized.
    // Point a bit down from the "target direction".
    Set target_direction to (target_direction + 0.8 * (target_direction + anti_fn() * ship:up:forevector)):normalized.
    If ship:velocity:surface:mag > 20 {
      // Don't get too far away from retrograde, to maintain aerodynamic stability.
      Local retro to anti_fn() * ship:srfprograde:forevector.
      If (retro - target_direction):mag > MAX_TO_RETROGRADE {
        Set target_direction to (target_direction - vdot(target_direction, retro) * retro):normalized.
        Set target_direction to (retro + MAX_TO_RETROGRADE * target_direction):normalized.
      }
    }

    Set control:pitch to 20 * vdot(target_direction, ship:facing:topvector) + 20 * vdot(ship:facing:starvector, ship:angularvel).

    Set control:yaw to 20 * vdot(target_direction, ship:facing:starvector) +
        -20 * vdot(ship:facing:upvector, ship:angularvel).

    Set control:roll to -10 * vdot((fore_times() * ship:velocity:surface:normalized - target_direction):normalized, ship:facing:upvector) +
        10 * vdot(ship:facing:forevector, ship:angularvel).

    Return true.
  }
}

When time:seconds > SEPARATION_TIME + 2 then {
  Set control:starboard to 0.0.

  When time:seconds > SEPARATION_TIME + 3 then {
    Brakes on.
    On moving_forwards {
      If moving_forwards {
        For ctrl_surface in ctrl_surfaces {
          Ctrl_surface:getmodule("FARControllableSurface"):setfield("roll %", 100).
        }
      } else {
        For ctrl_surface in ctrl_surfaces {
          Ctrl_surface:getmodule("FARControllableSurface"):setfield("roll %", -100).
        }
      }
      Return true.
    }
    Local pointing_toward_target to true.
    Lock_target({ Return pointing_toward_target. }).
    When time:seconds > SEPARATION_TIME + 20 then {
      RCS off.
      Lock throttle to 1.0.
      When vdot(ship:velocity:surface, init_target_direction()) > -60 then {
        Brakes off.
        When vdot(ship:velocity:surface, init_target_direction()) > 120 then {
          Lock throttle to 0.0.
          RCS on.
          Set pointing_toward_target to false.
          Lock_anti_target({ Return -1.0. }).
        }
      }
    }
  }
}

When alt:radar < 4000 then {
  Brakes on.
  When alt:radar < 1000 then {
    Local bounds to ship:bounds.
    Local pid_thrust is pidloop(0.2, 0, 0.45, 0, 1).
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

When ship:velocity:surface:mag < 5 then {
  Gear on.
}

Local bounds is ship:bounds.

Local function distortion_vector {
  Local upvec to up:forevector:normalized.
  Local targetvec to target_position.
  Set targetvec to targetvec - vdot(targetvec, upvec) * upvec.
  If targetvec:mag > 1000 { Set targetvec to V(0,0,0). }  // The "abort" case.
  Return 0.17 * targetvec + 20 * upvec.
}

When throttle > 0.05 and alt:radar < 1000 then {
  If is_port_booster {
    Lock target_position to (north_launchpad:position + south_launchpad:position) / 2
        + 8 * launchpad_eastvec
        + (-5) * launchpad_northvec.
  } else {
    Lock target_position to (north_launchpad:position + south_launchpad:position) / 2
        + (-8) * launchpad_eastvec
        + 5 * launchpad_northvec.
  }
  Lock srf_retrograde to false.
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

Local should_end is false.
On AG1 { Set should_end to true. }.
Wait until should_end.
