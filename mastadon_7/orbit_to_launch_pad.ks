@LAZYGLOBAL OFF.

Parameter profile is "0:/mastadon_7/descent_profile.csv".
Parameter NAIVE to false.
Print profile.
RunOncePath("0:/mastadon_7/landing_lib").
RunOncePath("0:/KSlib/library/lib_enum").
RunOncePath("0:/KSlib/library/lib_location_constants").
RunOncePath("0:/KSlib/library/lib_navigation").
RunOncePath("0:/my_lib/basic_control_flow").
RunOncePath("0:/my_lib/bisect").
RunOncePath("0:/my_lib/clip").
RunOncePath("0:/my_lib/display_bounds").
RunOncePath("0:/my_lib/fake_rcs").
RunOncePath("0:/my_lib/lib_smoothing").
RunOncePath("0:/pump_fuel").

Local LOG_TRAJECTORY to NAIVE.
Local vars to lex().
Local zero_vec to V(0,0,0).
Local cf to control_flow:new().
Local background to cf:background.

Set target to "North Launchpad".
Local target_geo to location_constants:launchpad.
Lock target_position to target_geo:position.
Local launchpad_altitude to target_geo:terrainheight.

FakeRCS:find_engines().
Background:register_and_enqueue_op("fakercs",
  {
    FakeRCS:adjust().
    Return "fakercs".
  }
).
Local control to ship:control.
Local bounds to ship:bounds.  // For this particular ship, bounds should not require recalculation.
Local bounds_computation_time to time:seconds.  // But let's recompute it periodically to be on the safe side.
Background:register_and_enqueue_op("recompute_bounds",
  {
    Local time_secs to time:seconds.
    If time_secs - bounds_computation_time >= 60 {
      Set bounds to ship:bounds.
      Set bounds_computation_time to time_secs.
      If NAIVE {
        ClearVecDraws().
        Draw_box(bounds).
      }.
    }.
    Return "recompute_bounds".
  }
).

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
  Set phase to angle_to_std_range(phase, pivot).
  Return interpolate(phase, phase_data, specific_energy_data).
}.

Local function expected_alt_at {
  Parameter phase.
  Set phase to angle_to_std_range(phase, pivot).
  Return interpolate(phase, phase_data, altitude_data).
}.

Local kerbin_radius to Kerbin:radius.
Local kerbin_surface_acceleration to Kerbin:mu / Kerbin:radius^2.
Local function potential_energy_at_altitude {
  Parameter alt_meters.
  Return ship:mass * kerbin_surface_acceleration * kerbin_radius * (
      1 - kerbin_radius / (alt_meters + kerbin_radius)).
}.

Local function specific_energy {
  Parameter alt_meters to ship:altitude.
  Local speed to ship:velocity:surface:mag.
  Local kinetic to speed * speed / 2.
  Local potential to kerbin_surface_acceleration * kerbin_radius * (1 - kerbin_radius / (alt_meters + kerbin_radius)).
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
    Set vars["log_file"] to "0:/mastadon_7/descent_log.csv".
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

Local function starting_in_orbit_seq {
  Return list(
    {
      SAS off.
      RCS on.
    }, 
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
  Return list(
    {
      Set vars["rcs_retrograde"] to true.
      RCS on.
    },
    Control_flow:fork("lock_retrograde", list(
      {
        If not vars:hasKey("rcs_retrograde") { Return false. }.
        Set control:rotation to direction_rotation_controller(
            -ship:prograde:vector,
            zero_vec,
            prograde_angular_velocity(),
            10.0,
            50.0).
        Return true.
      }
    )),
    Control_flow:waitForSecs(60),
    { Set control:pilotmainthrottle to 0.05. },
    { Return alt:periapsis > 60000. },
    { 
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
Local pid_alt to pf_controller(0.00004, 512).
If NAIVE {
  Set pid_alt to pidloop(0.0).
}.
Local AIMING_ALTITUDE to 10000.
Local next_print_alt_time to -1.
Local most_recent_pid_specific_energy_nonpositive to -1.
Local expected_alt_smoother to lib_smoothing:exponential_moving_avg(5.0).
Local expected_alt_corrector to lib_smoothing:exponential_moving_avg(50.0).
Cf:register_op("update_alt_and_specific_energy_pids", {
  Local alt_meters to ship:altitude.
  Local time_secs to time:seconds.
  If alt_meters <= AIMING_ALTITUDE {
    Set control:pilotmainthrottle to 0.
    Return list().
  }.
  Local specific_energy_error to specific_energy(alt_meters) - expected_specific_energy_at(phase_angle).
  If NAIVE {
    Set specific_energy_error to 0.
  }.
  Pid_specific_energy:update(time_secs, specific_energy_error).
  Local expected_alt_raw to expected_alt_at(phase_angle).
  Local expected_alt_smoothed to expected_alt_smoother:update(time_secs, expected_alt_raw).
  Local expected_alt_correction to
      expected_alt_corrector:update(time_secs, expected_alt_raw - expected_alt_smoothed).
  Set expected_alt_smoothed to expected_alt_smoothed + expected_alt_correction.
  Pid_alt:update(time_secs, alt_meters - expected_alt_smoothed).
  If time_secs >= next_print_alt_time or next_print_alt_time < 0 {
    Set next_print_alt_time to time_secs + 10.
    HUDText("altitude error: " + round(alt_meters - expected_alt_raw, 1) + "m",
            50 / kuniverse:timewarp:rate, 1, 15, green, false).
    HUDText("smoothing error: " + round(expected_alt_smoothed - expected_alt_raw, 1) + "m",
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
        { Return ship:Q * constant:ATMtokPa > 10.0. },
        {
//          Print "starting aerodynamic control".
//          RCS off.
          Set rotation_kp to 7.0.
          Set rotation_kd to 5.0.
        }
      ),
      control_flow:waituntil_then(
        { Return ship:altitude <= 30000. },
        { Set pid_alt:kd to 0.5 * pid_alt:kd. }
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
      If not NAIVE and abs(target_heading - heading_now) < 5 {
        Local heading_shift to clip(100 * (target_heading - heading_now), -5, 5).
        Set target_direction to angleaxis(heading_shift, ship:up:vector) * target_direction.
      }.

      Local desired_ang_vel to -0.1 * target_direction + srfprograde_angular_velocity().
      Set control:rotation to
          direction_rotation_controller(
              target_direction,
              zero_vec,
              desired_ang_vel,
              rotation_kp,
              rotation_kd).
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
         or fuel_remaining() <= 500.
}.

Local function over_water {
  Return abs(ship:altitude - alt:radar) <= 5.
}.

Local kinematic_impact_vec to vecdraw().
Set kinematic_impact_vec:color to blue.
Set kinematic_impact_vec:label to "kinematic impact".

Local impact_vec to vecdraw().
Set impact_vec:color to green.
Set impact_vec:label to "extrapolated impact".



Local impact_error_control to vector_control_loop().
Local adjustment_integral to vector_integral(0.05).

Local function launchpad_vertical_distance {
  Return ship:altitude - launchpad_altitude - bounds:furthestCorner(-ship:facing:vector):mag.
}.

Local function update_impact_error {
  Local facing_direction to ship:facing.
  Local height to launchpad_vertical_distance().
  Local upvec to ship:up:vector.
  Local impact_pos to impact_position_and_time(height, vxcl(upvec, ship:velocity:surface)).
  Local time_to_impact to impact_pos[1].
  Set impact_pos to impact_pos[0].
  Local impact_error to vxcl(upvec, target_position - impact_pos).
  Set impact_error to impact_error_control(time:seconds, impact_error, 0.5 * time_to_impact).
  // <DEBUG>
  Set impact_vec:vec to target_position - impact_error.
  Impact_vec:show on.
  Set kinematic_impact_vec:vec to (impact_pos - height * upvec).
  Kinematic_impact_vec:show on.
  // </DEBUG>
  Return impact_error.
}.

Local function distortion_vector {
  Local impact_error to update_impact_error().
  // Aim a bit farther out to end up at the correct point after the burn.
  Set impact_error to impact_error + 100 * vxcl(ship:up:vector, target_position):normalized.
  Local height to launchpad_vertical_distance().
  Set impact_error to impact_error / (height + 10).
  Local adjustment to vxcl(ship:facing:vector, -impact_error).
//  // Exaggerate the lateral adjustment since the desired heading, once fixed, tends to
//  // stay fixed (unlike the desired vertical angle, which requires constant adjustment).
//  Local lateral_axis to vcrs(ship:up:vector, target_position):normalized.
//  Set adjustment to adjustment + 0.2 * vdot(lateral_axis, adjustment) * lateral_axis.
  // This seems to help.
  Set adjustment to adjustment + adjustment_integral(time:seconds, adjustment).
  If should_abort() or NAIVE { Set adjustment to V(0,0,0). }.
  // <DEBUG>
  //Set adjustment_vec:vec to 200 * adjustment.
  //Adjustment_vec:show on.
  // </DEBUG>
  Return adjustment.
}.

Local function low_altitude_steering_seq {
  Local MAX_DIST_FROM_RETROGRADE to 0.1.
  If NAIVE { Set MAX_DIST_FROM_RETROGRADE to 0.0. }.
  Local target_direction to -target_position:normalized.
  Return list(
    {
      RCS off.
      Set rotation_kd to 2 * rotation_kp.
//      Set pid_roll to pf_controller(0.1, 20, -1, 1).
//      Set pid_roll:setpoint to -0.5.
//      Local smoothed_pid_roll to lib_smoothing:exponential_moving_avg(1.0).
//      Set vars["update_roll"] to {
//        Parameter time_secs.
//        Parameter pid_input.
//        Return smoothed_pid_roll:update(time_secs, pid_roll:update(time_secs, pid_input)).
//      }.
//      Set pid_pitch to pf_controller(2.5, 4, -1, 1).
//      Set pid_yaw to pf_controller(2.5, 4, -1, 1).
    },
    {
      If control:pilotmainthrottle > 0.05 or alt:radar < 400 {
        Return false.
      }
//      Set control:roll to vars:update_roll(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 

      Set target_direction to (-ship:velocity:surface:normalized + 4 * distortion_vector()):normalized.

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
      
      Local retro_facing_diff to (retro - ship:facing:vector):mag.
      If retro_facing_diff > MAX_DIST_FROM_RETROGRADE + 0.02 {
        If not RCS { RCS on. }.
      } else if retro_facing_diff < MAX_DIST_FROM_RETROGRADE {
        If RCS { RCS off. }.
      }.

//      Set control:pitch to pid_pitch:update(time:seconds,
//        -vdot(target_direction, ship:facing:topvector)).
//      Set control:yaw to pid_yaw:update(time:seconds,
//        -vdot(target_direction, ship:facing:starvector)).
      Set control:rotation to 2 * direction_rotation_controller(
          target_direction,
          zero_vec,
          srfprograde_angular_velocity(),
          rotation_kp,
          rotation_kd).
      
      Return true.
    },
    {
      RCS on.
//      Set pid_roll to pf_controller(0.2, 5, -0.2, 0.2).
//      Set pid_pitch to pf_controller(2.5, 4, -1, 1).
//      Set pid_yaw to pf_controller(2.5, 4, -1, 1).
      Set target_direction to ship:up:vector.
      Set vars["target_direction_deriv"] to vector_derivative().
      //Set MAX_DIST_FROM_RETROGRADE to 0.0.
    }, 
    //control_flow:fork("disable_ctrl_surfaces", disable_control_surfaces_seq()), 
    {
      Local upvec to ship:up:vector.
      Local retrogradevec to ship:srfretrograde:vector.
      Local axis to vcrs(upvec, retrogradevec). 
      Local horiz_speed to vxcl(upvec, ship:velocity:surface):mag.
      Local angle_factor to 1.2.
      Local angle to angle_factor * vang(upvec, retrogradevec).
      //Set angle to min(angle,  max_angle_to_vertical(ship:altitude)).
      Local look_at to angleAxis(angle, axis) * upvec + 0.01 * update_impact_error().
      Local desired_angular_velocity to reference_frame_angular_velocity().
      Set look_at to look_at + max(0, 0.01 * ship:verticalspeed + 1) * upvec.
      Local max_vertical_angle to max_angle_to_vertical(ship:altitude).
      If vang(look_at, upvec) > max_vertical_angle {
        Set look_at to upvec + tan(max_vertical_angle) * vxcl(upvec, look_at):normalized.
      }.
      Local MAX_RETROGRADE_ANGLE to 5.
      If ship:Q > 0.1 and vang(look_at, retrogradevec) > MAX_RETROGRADE_ANGLE {
        Set look_at to retrogradevec + tan(MAX_RETROGRADE_ANGLE) * vxcl(retrogradevec, look_at):normalized.
      }.
      Local factor to 0.3 / (control:pilotmainthrottle + 0.1).
      Set rotation_kd to 1.0 * rotation_kp.
      Set control:rotation to factor * direction_rotation_controller(
          look_at,
          zero_vec,
          desired_angular_velocity,
          rotation_kp,
          rotation_kd).
      Return ship:status = "FLYING" or ship:airspeed > 0.5 or
        (ship:status = "SPLASHED" and ship:airspeed > 0.1) or
        bounds:bottomaltradar > 1.
    }, {
      Print "steering sequence done".
    }
  ).
}.

Local airbrake_smoother to lib_smoothing:exponential_moving_avg(1.0).
Local function atm_speed_control_seq {
  Local pid_thrust to pf_controller(0.1, 1.0, -1, 1).
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
      Set_airbrakes(airbrake_smoother:update(time:seconds, 0.75 - pid_specific_energy:output)).
      Return true.
    },
    { Return alt:radar >= 4000. },
    {
      Disable_several_engines().
      //Disable_gimbals().
      Set pid_thrust:setpoint to 0.
      Set vars["fake_locked_throttle"] to true.
      Set vars["smoothed_pid_thrust"] to lib_smoothing:exponential_moving_avg(0.5).
      //Set vars["min_throttle"] to 0.0.
    },
    control_flow:fork("throttle_control_landing", {
      If not vars:fake_locked_throttle { Return false. }.
      Local current_verticalspeed to ship:verticalspeed.
      If current_verticalspeed > 0 {
        Set control:pilotmainthrottle to 0.
        Return false.
      }.
      Local time_secs to time:seconds.
      Local bottomaltradar to bounds:bottomaltradar.
      Local sheddable_energy to ship:availablethrust * (bottomaltradar - 2).
      Local potential_energy to potential_energy_at_altitude(bottomaltradar).

      Local desired_kinetic_energy to max(0, sheddable_energy - potential_energy).
      Local desired_verticalspeed to sqrt(2 * desired_kinetic_energy / ship:mass).
      Set desired_verticalspeed to -0.8 * desired_verticalspeed.
      Set desired_verticalspeed to min(-1.0, desired_verticalspeed).
      Set control:pilotmainthrottle to vars:smoothed_pid_thrust:update(time_secs,
          weight() / ship:availablethrust + pid_thrust:update(
            time_secs, current_verticalspeed - desired_verticalspeed)) /
          (ship:facing:vector * ship:up:vector).
//      Set control:pilotmainthrottle to clip(vars:smoothed_pid_thrust:update(
//          time_secs,
//          pid_thrust:update(time:seconds, bounds:bottomaltradar)
//        ) + weight() / ship:maxthrust, vars:min_throttle, 1).
//      If control:pilotmainthrottle > 0.05 {
//        Set vars["min_throttle"] to 0.06.
//      }.
      Return true.
    }),
    { Return ship:status = "FLYING" or ship:airspeed > 0.2 or bounds:bottomaltradar > 1. },
    {
      RCS off.
      Brakes off.
      Set vars["fake_locked_throttle"] to false.
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
