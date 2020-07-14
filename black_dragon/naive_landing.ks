@LAZYGLOBAL OFF.

Parameter profile is "0:/black_dragon/descent_profile.csv".
Print profile.
RunOncePath("0:/black_dragon/landing_lib").
RunOncePath("0:/KSlib/library/lib_enum").
RunOncePath("0:/KSlib/library/lib_navigation").
RunOncePath("0:/my_lib/basic_control_flow").
RunOncePath("0:/my_lib/bisect").
RunOncePath("0:/my_lib/clip").
RunOncePath("0:/my_lib/fake_rcs").
RunOncePath("0:/my_lib/lib_smoothing").
RunOncePath("0:/pump_fuel").

Local LOG_TRAJECTORY to true.
Local vars to lex().
Local cf to control_flow:new().
Local background to cf:background.

Set target to "North Launchpad".
Local north_launchpad to Vessel("North Launchpad").
Local south_launchpad to Vessel("South Launchpad").
Local north_geo to north_launchpad:geoposition.
Local south_geo to south_launchpad:geoposition.
Local target_geo to latlng((north_geo:lat + south_geo:lat)/2,
                           (north_geo:lng + south_geo:lng)/2).
Lock target_position to target_geo:position.

FakeRCS:find_engines().
Background:register_and_enqueue_op("fakercs",
  {
    FakeRCS:adjust().
    Return "fakercs".
  }
).
Local control to ship:control.
Local bounds to ship:bounds.  // For this particular ship, bounds should not require recalculation.

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
Local angle_to_standard_range to angle_to_std_range@.

Local start_at_phase to 0.
Local pivot to 540.
Local altitude_data to list().
Local phase_data to list().
Local specific_energy_data to list().
Local header_seen to false.
For line in open(profile):readall {
  If not header_seen {
    Set header_seen to true.
  } else {
    Local numbers to line:split(",").
    Local tmp to numbers[1]:tonumber(-1e99).
    If tmp < -1e98 { Print 0/0. }.
    Altitude_data:add(tmp). 
    Set tmp to numbers[2]:tonumber(-1e99).
    If tmp < -1e98 { Print 0/0. }.
    Phase_data:add(tmp).
    Set tmp to numbers[4]:tonumber(-1e99).
    If tmp < -1e98 { Print 0/0. }.
    specific_energy_data:add(tmp).
  }.
}.
Set start_at_phase to angle_to_std_range(phase_data[0]).
// Reverse the data since "interpolate" expects phase_data to be sorted in ascending order.
Set altitude_data to Enum:reverse(altitude_data).
Set phase_data to Enum:reverse(phase_data).
Set specific_energy_data to Enum:reverse(specific_energy_data).

Local function expected_specific_energy_at {
  Parameter phase.
  Return specific_energy().
  //Set phase to angle_to_std_range(phase, pivot).
  //Return interpolate(phase, phase_data, specific_energy_data).
}.

Local function expected_alt_at {
  Parameter phase.
  Return ship:altitude.
  //Set phase to angle_to_std_range(phase, pivot).
  //Return interpolate(phase, phase_data, altitude_data).
}.

Local kerbin_radius to Kerbin:radius.
Local function specific_energy {
  Parameter alt_meters to ship:altitude.
  Local speed to ship:velocity:surface:mag.
  Local kinetic to speed * speed / 2.
  Local potential to CONSTANT:g0 * kerbin_radius * (1 - kerbin_radius / (alt_meters + kerbin_radius)).
  Return kinetic + potential.
}.

Local phase_angle to phaseAngle().
Background:register_and_enqueue_op("update_phase",
  {
    Set phase_angle to phaseAngle().
    Return "update_phase".
  }
).

Local function control_surfaces_retrograde_seq {
  Local init_time to 0.
  Local ctrl_surfaces to list().
  Return list(
    {
      Set ctrl_surfaces to ship:modulesNamed("FARControllableSurface").
      For ctrl_surface in ctrl_surfaces {
        Ctrl_surface:setfield("std. ctrl", true).
      }.
      Set init_time to time:seconds.
    }, { Return time:seconds - init_time < 1.0. },
    {
      For ctrl_surface in ctrl_surfaces {
        // Reverse all the control surfaces since we are going retrograde.
        Ctrl_surface:setfield("pitch %", -100).
        Ctrl_surface:setfield("yaw %", -100).
        Ctrl_surface:setfield("roll %", -100).
        Ctrl_surface:setfield("ctrl dflct", 20).
      }.
    },
    { Print "control_surfaces_retrograde_seq done". }
  ).
}.

Local function disable_control_surfaces_seq {
  Local init_time to 0.
  Local ctrl_surfaces to list().
  Return list(
    {
      Set ctrl_surfaces to ship:modulesNamed("FARControllableSurface").
      For ctrl_surface in ctrl_surfaces {
        Ctrl_surface:setfield("std. ctrl", true).
      }.
      Set init_time to time:seconds.
    }, { Return time:seconds - init_time < 1.0. },
    {
      For ctrl_surface in ctrl_surfaces {
        Ctrl_surface:setfield("ctrl dflct", 0).
      }.
    }
  ).
}.

// To be enqueued if appropriate
Background:register_sequence("log_trajectory", list(
  {
    Set vars["log_file"] to "0:/black_dragon/descent_log.csv".
    Log "time,altitude,phase_angle,airspeed,specific_energy" to vars:log_file.
    Set vars["next_log_time"] to time:seconds.
  },
  {
    If time:seconds < vars:next_log_time { Return true. }
    Set vars["next_log_time"] to vars["next_log_time"] + (choose 10 if ship:altitude > 15000 else 1).
    Local logentry to time:seconds + "," +
                      altitude + "," +
                      phase_angle + "," +
                      ship:velocity:surface:mag + "," +
                      round(specific_energy()).
    Log logentry to vars:log_file.
    Return true.
  })
).

// We want update_pivot running no matter where we start.
Background:register_and_enqueue_op("update_pivot", control_flow:waituntil_then(
  { Return angle_to_std_range(phase_angle, pivot) < 359 or ship:altitude < 65000. },
  { Set pivot to 359. },
  "update_pivot")
).

Local function desired_ang_vel {
  Return 0.5 * (ship:facing:vector + 0.05 * ship:prograde:vector):normalized
       - (2 * constant:pi / ship:orbit:period) * ship:north:vector.
}.

Cf:register_op("rotate_while_emptying",
  {
    If vars:hasKey("mk3_fuel_tank") and tank_empty(vars:mk3_fuel_tank) {
      RCS off.
      Control:neutralize on.
      Return list().
    }.
    Set control:rotation to
        direction_rotation_controller(
            ship:prograde:vector,
            desired_ang_vel(),
            10.0,
            100.0).
    Return "rotate_while_emptying".
  }
).

Local function starting_in_orbit_seq {
  Return list(
    {
      SAS off.
      RCS on.
      Disable_verniers().
      Set vars["mk3_fuel_tank"] to ship:partsdubbedpattern("mk3Fuselage")[0].
    }, control_flow:fork("rotate_while_emptying"),
    { 
      If tank_empty(vars:mk3_fuel_tank) { Return false. }.
      Return vang(ship:prograde:vector, ship:facing:vector) > 5 or
             (desired_ang_vel() - ship:angularvel):mag > 0.5 * constant:degToRad. },
    {
      Toggle AG5.  // Vent any remaining fuel and monopropellant from upper stage.
    },
    { Return not tank_empty(vars:mk3_fuel_tank). },
    { Toggle AG4. },  // Open crossfeed to fuel twitch-RCS thrusters at nose.
    {
      Set vars["transfer_order"] to all_fuel_to_last_tank().
      Vars:transfer_order:activate().
    },
    { Return not vars:transfer_order:done(). },
    { Vars:remove("transfer_order"). },
    {
      Set vars["print_phase"] to true.
      Background:register_and_enqueue_op("do_print_phase", {
        HUDText("Angle from starting point: " + angle_to_standard_range(phase_angle - start_at_phase, 10),
                50 / kuniverse:timewarp:rate, 1, 15, green, false).
        Set vars["next_print_phase_time"] to time:seconds + 10.
        Return "wait_print_phase".
      }).
      Background:register_op("wait_print_phase", {
        If not vars:haskey("print_phase") {
          Vars:remove("next_print_phase_time").
          Return list().
        } else if time:seconds >= vars:next_print_phase_time {
          Return "do_print_phase".
        } else {
          Return "wait_print_phase".
        }.
      }).
    },
    { Return angle_to_standard_range(phase_angle - start_at_phase, 10) < 0. },
    {
      Kuniverse:timewarp:cancelwarp().
      Print "canceling warp.".
    },
    { Return angle_to_standard_range(phase_angle - start_at_phase, 10) > 0. },
    {
      Print "current warp rate: " + kuniverse:timewarp:rate.
      Vars:remove("print_phase").
      If LOG_TRAJECTORY { Background:enqueue_op("log_trajectory"). }.
    }
  ).
}.

Local function deorbit_seq {
  Local zero_vec to V(0,0,0).
  Return list(
    {
      Set vars["rcs_retrograde"] to true.
      RCS on.
    },
    Control_flow:fork("lock_retrograde", list(
      {
        If not vars:hasKey("rcs_retrograde") { Return false. }.
        Set control:rotation to direction_rotation_controller(-ship:prograde:vector, zero_vec, 10.0, 50.0).
        Return true.
      }
    )),
    Control_flow:waitForSecs(60),
    { Lock throttle to 0.05. },
    { Return alt:periapsis > 50000. },
    { 
      Unlock throttle.
      Set control:pilotmainthrottle to 0.0.
      Vars:remove("rcs_retrograde").
    }
  ).
}.

Local airbrake_modules to enum:map(ship:partsdubbedpattern("airbrake"), {
  Parameter airbrake.
  Return airbrake:getmodule("ModuleAeroSurface").
}).
Local function set_airbrakes {
  Parameter brake_power.
  
  For airbrake in airbrake_modules {
    Local power to clip(brake_power, 0, 1).
    Airbrake:setfield("deploy angle", 0.7 * power * 100).
  }.
}.

Background:register_and_enqueue_seq("navmode", list(
  { Return ship:altitude > 55000. },
  { 
    If navmode <> "surface" {
      Set navmode to "surface".
    }.
    Return true.
  }
)).

Local pid_specific_energy to pidloop(0.01, 0, 0.0, -0.25, 0.25).
Local pid_alt to pf_controller(0.00002, 512).
Local AIMING_ALTITUDE to 20000.
Local next_print_alt_time to -1.
Local most_recent_pid_specific_energy_nonpositive to -1.
Cf:register_op("update_alt_and_specific_energy_pids", {
  Local alt_meters to ship:altitude.
  Local time_secs to time:seconds.
  If alt_meters <= AIMING_ALTITUDE {
    Return list().
  }.
  Pid_specific_energy:update(time_secs, specific_energy(alt_meters) - expected_specific_energy_at(phase_angle)).
  Local expected_alt_raw to expected_alt_at(phase_angle).
  Local expected_alt_smoothed to expected_alt_raw.
  Pid_alt:update(time_secs, alt_meters - expected_alt_smoothed).
  If time_secs >= next_print_alt_time or next_print_alt_time < 0 {
    Set next_print_alt_time to time_secs + 10.
    HUDText("altitude error: " + round(alt_meters - expected_alt_raw, 1) + "m",
            50 / kuniverse:timewarp:rate, 1, 15, green, false).
    HUDText("specific energy error: " + round(pid_specific_energy:input, 1) + " m^2/s^2",
            50 / kuniverse:timewarp:rate, 3, 15, green, false).

  }.
  If most_recent_pid_specific_energy_nonpositive < 0 {
    Set most_recent_pid_specific_energy_nonpositive to time_secs. // Start out assuming "okay" state.
  } else if pid_specific_energy:input <= 0 {
    Set most_recent_pid_specific_energy_nonpositive to time_secs.
    Set control:pilotmainthrottle to 0.0.
  } else if most_recent_pid_specific_energy_nonpositive > 0 and
            time_secs - most_recent_pid_specific_energy_nonpositive > 60 {
    If pid_alt:input > 100 {
      Set control:pilotmainthrottle to 0.04.
    } else {
      Set control:pilotmainthrottle to 0.01.
    }.
  }.
  Return "update_alt_and_specific_energy_pids".
}).

Local pid_roll to pf_controller(0.2, 10, -1, 1).
Set pid_roll:setpoint to 0.1.  // Rotate at 0.1 radians (about 5 degrees) per second.
Local pid_pitch to pf_controller(0.6, 16, -0.5, 0.5).
Local pid_yaw to pf_controller(0.6, 16, -0.5, 0.5).
Local MAX_VERTICAL_SHIFT to Constant:DegToRad * 15.
Local rotation_kp to 1.0.
Local rotation_kd to 5.0.
Local function high_altitude_steering_seq {
  Return list(
    {
      RCS on.
    },
    control_flow:fork("tune_steering_for_altitude", list(
      control_flow:waituntil_then(
        { Return ship:Q * constant:ATMtokPa > 1.0. },
        {
          Print "starting aerodynamic control".
          RCS off.
          Set rotation_kp to 5.0.
          Set rotation_kd to 25.0.
        }
      )
    )),
    {
      Local time_secs to time:seconds.
      Local ship_facing to ship:facing.
      Local vertical_shift to ship:up:forevector * pid_alt:output.
       
      If vertical_shift:mag > MAX_VERTICAL_SHIFT {
        Set vertical_shift to MAX_VERTICAL_SHIFT * vertical_shift:normalized.
      }.
      Local target_direction to (ship:srfretrograde:forevector  - vertical_shift):normalized.

      Local target_heading to target_geo:heading.
      Local heading_now to current_heading().
      If abs(target_heading - heading_now) < 5 {
        Local heading_shift to clip(100 * (target_heading - heading_now), -5, 5).
        Set target_direction to angleaxis(heading_shift, ship:up:vector) * target_direction.
      }.

      Local desired_ang_vel to -0.1 * target_direction + vcrs(ship:velocity:orbit, body:position) / body:position:sqrmagnitude.
      Set control:rotation to
          direction_rotation_controller(
              target_direction,
              desired_ang_vel,
              rotation_kp,
              rotation_kd,
              1.0).
      Return ship:altitude > AIMING_ALTITUDE.
    }
  ).
}.

Local function fuel_remaining {
  For resource in ship:resources {
    If resource:name = "LIQUIDFUEL" {
      Return resource:amount.
    }.
  }.
  Return 0.
}.


Local function should_abort {
  Return (alt:radar < 200 and vxcl(ship:up:vector, target_position):mag > 1000)
         or fuel_remaining() <= 1000.
}.

Local function over_water {
  Return abs(ship:altitude - alt:radar) <= 5.
}.

Local function distortion_vector {
  Local upvec to ship:up:vector.
  Local targetvec to V(0,0,0).//vxcl(upvec, target_position).
  If should_abort() { Set targetvec to V(0,0,0). }.
  Local up_component to 30 * upvec.
  Local horiz_component to 0.2 * targetvec.
  Local max_horiz_component to 1.3 * up_component:mag.
  If horiz_component:mag > max_horiz_component {
    Set horiz_component to max_horiz_component * horiz_component:normalized.
  }.
  Return horiz_component + up_component.
}.

Local function low_altitude_steering_seq {
  Local MAX_DIST_FROM_RETROGRADE to 0.0.//2.0.
  Local target_direction to -target_position:normalized.
  Return list(
    {
      RCS on.
      Set pid_roll to pf_controller(0.1, 20, -1, 1).
      Set pid_roll:setpoint to -0.5.
      Local smoothed_pid_roll to lib_smoothing:exponential_moving_avg(1.0).
      Set vars["update_roll"] to {
        Parameter time_secs.
        Parameter pid_input.
        Return smoothed_pid_roll:update(time_secs, pid_roll:update(time_secs, pid_input)).
      }.
      Set pid_pitch to pidloop(2.5, 0, 10.0, -1, 1).
      Set pid_yaw to pidloop(2.5, 0, 10.0, -1, 1).
    },
    {
      If throttle > 0.05 or alt:radar < 400 {
        Return false.
      }
      Set control:roll to vars:update_roll(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 

      // Point the tail a bit up from the target.
      Set target_direction to -target_position:normalized.
      Set target_direction to (target_direction + 0.4 * (target_direction - ship:up:forevector)):normalized.

      // But not so far up that you can't force it down again.
      Local angle_to_vertical to vang(ship:up:vector, target_direction).
      Local max_allowed_angle to max_angle_to_vertical(ship:altitude).
      If angle_to_vertical > max_allowed_angle {
        Local axis to vcrs(target_direction, ship:up:vector):normalized.
        Set target_direction to angleaxis(angle_to_vertical - max_allowed_angle, axis) * target_direction.
      }.

      // TODO: more horizontal variation.
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
    },
    {
      RCS on.
      Set pid_roll to pf_controller(0.2, 5, -0.2, 0.2).
      Set pid_pitch to pf_controller(1.0, 4, -0.3, 0.3).
      Set pid_yaw to pf_controller(1.0, 4, -0.3, 0.3).
      Set target_direction to ship:up:vector.
    }, 
    control_flow:fork("disable_ctrl_surfaces", disable_control_surfaces_seq()), 
    {
      Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
      Set target_direction to (-ship:velocity:surface + distortion_vector()):normalized.
      Set control:pitch to pid_pitch:update(time:seconds,
        -vdot(target_direction, ship:facing:topvector)).
      Set control:yaw to pid_yaw:update(time:seconds,
        -vdot(target_direction, ship:facing:starvector)).
      Return ship:status = "FLYING" or ship:airspeed > 0.5 or (ship:status = "SPLASHED" and ship:airspeed > 0.1).
    }, {
      Print "steering sequence done".
    }
  ).
}.

Local airbrake_smoother to lib_smoothing:exponential_moving_avg(1.0).
Local function atm_speed_control_seq {
  Local pid_thrust to pf_controller(0.05, 4, 0, 1).
  Return list(
    { Return ship:altitude > 70000. },
    { Brakes on. },
    {
      If alt:radar < AIMING_ALTITUDE {
        Kuniverse:timewarp:cancelwarp().
        Print "canceling warp.".
        Set_airbrakes(1.0).
        Return false.
      }
      Set_airbrakes(airbrake_smoother:update(time:seconds, 0.75)).// + pid_specific_energy:output)).
      Return true.
    },
    { Return alt:radar >= 2000. },
    {
      Set pid_thrust:setpoint to 45.
      Lock throttle to pid_thrust:update(time:seconds, bounds:bottomaltradar).
    },
    {
      If should_abort() { Return false. }.
      If alt:radar >= 175 or ship:airspeed >= 3 { Return true. }.
      Local height to bounds:bottomaltradar.
      Local upvec to ship:up:vector.
      Local horiz_velocity to vxcl(upvec, ship:velocity:surface).
      Return vxcl(upvec, impact_position_horiz(height, horiz_velocity) - target_position):mag > 6.
    },
    {
      Set pid_thrust to pf_controller(0.05, 2.5, 0, 1).
      Set pid_thrust:setpoint to
          choose -7.0
          if over_water()
          else -0.2.
    },
    { Return ship:status = "FLYING" or ship:airspeed > 0.2. },
    {
      RCS off.
      Brakes off.
      Unlock throttle.
      Set control:pilotmainthrottle to 0.
    }, control_flow:waitForSecs(1)
  ).
}.

Local main_sequence to list().

Cf:register_and_enqueue_seq("ctrl_surfaces", control_surfaces_retrograde_seq()).
If alt:periapsis > 69000 {
  If abs(angle_to_standard_range(phase_angle - start_at_phase, 10)) > 2 {
    For op in starting_in_orbit_seq {
      Main_sequence:add(op).
    }.
  }.
  For op in deorbit_seq {
    Main_sequence:add(op).
  }.
}.
Cf:register_sequence("low_altitude_steering", low_altitude_steering_seq()).
If ship:altitude > AIMING_ALTITUDE {
  Main_sequence:add(control_flow:fork("update_alt_and_specific_energy_pids")).
  Cf:register_sequence("high_altitude_steering", high_altitude_steering_seq(), "low_altitude_steering").
  Main_sequence:add(control_flow:fork("high_altitude_steering")).
} else {
  Cf:enqueue_op("low_altitude_steering").
}.

For op in atm_speed_control_seq() {
  Main_sequence:add(op).
}.
Main_sequence:add({ Print "main sequence complete.". }).
Cf:register_and_enqueue_seq("main_sequence", main_sequence).

Core:part:parent:controlfrom().
Until not cf:active() {
  Cf:run_pass().
  Wait 0.
}.
