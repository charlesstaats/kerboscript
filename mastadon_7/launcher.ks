@LAZYGLOBAL OFF.

RunOncePath("0:/KSLib/library/lib_navigation.ks").
Runoncepath("0:/my_lib/basic_control_flow").
Runoncepath("0:/my_lib/clip").
RunOncePath("0:/my_lib/controller").
RunOncePath("0:/my_lib/fake_rcs").
RunOncePath("0:/my_lib/lib_smoothing").

Local function define_update_eta {
  Local pid_eta is pidloop(0, 0, 1.0).
  Local prev_output is 0.
  Local prev_dOdt is 0.
  Local prev_time is 0.
  Return {
    Local current_time is time:seconds.
    If prev_time = 0 { Set prev_time to current_time. }.
    If prev_time = current_time { Return prev_output. }.
    Local interval is current_time - prev_time.
    Set prev_time to current_time.
    Local adjusted_apoapsis to eta:apoapsis.
    If adjusted_apoapsis > ship:orbit:period / 2 {
      Set adjusted_apoapsis to adjusted_apoapsis - ship:orbit:period.
    }.
    Local dOdt is pid_eta:update(current_time, adjusted_apoapsis) - 0.2.
    Local retv is clip(0.2 * prev_dOdt * interval + prev_output, 0, 1).
    Set prev_output to retv.
    Set prev_dOdt to dOdt.
    Return retv.
  }.
}

Local function adjusted_eta {
  Parameter raw_eta_seconds.
  Local period_var to ship:orbit:period.
  If raw_eta_seconds > period_var / 2 {
    Return raw_eta_seconds - period_var.
  }.
  Return raw_eta_seconds.
}.

Local function is_apoapsis_closer {
  Local period is ship:orbit:period.
  Local eta_ap is eta:apoapsis.
  Local ap_dist is min(eta_ap, period - eta_ap).
  Local eta_per is eta:periapsis.
  Local per_dist is min(eta_per, period - eta_per).
  Return ap_dist < per_dist.
}

Local function reference_frame_angular_velocity {
  Return vcrs(ship:velocity:orbit, body:position) / body:position:sqrmagnitude.
}.

Local function gravitational_acceleration {
  Return body:position:normalized * body:mu / body:position:sqrmagnitude.
}.

Local function srfprograde_angular_velocity {
  Return vcrs(ship:velocity:surface, gravitational_acceleration()) / ship:velocity:surface:sqrmagnitude
    + reference_frame_angular_velocity().
}.

Local function prograde_angular_velocity {
  Return vcrs(ship:velocity:orbit, gravitational_acceleration()) / ship:velocity:orbit:sqrmagnitude.
}.

Local body_radius to body:radius.
Local surface_gravity to body:mu / body_radius^2.
Local function potential {
  Parameter alt_meters to ship:altitude.
  Return surface_gravity * body_radius * (1 - body_radius / (alt_meters + body_radius)).
}.
Local function specific_energy {
  Parameter speed to ship:velocity:orbit:mag.
  Parameter alt_meters to ship:altitude.
  Local kinetic to speed * speed / 2.
  Return kinetic + potential(alt_meters).
}.
Local function speed_at_altitude {
  Parameter desired_altitude.
  Parameter current_speed to ship:velocity:orbit:mag.
  Parameter current_altitude to ship:altitude.
  Local invariant_specific_energy to specific_energy(current_speed, current_altitude).
  Local desired_potential to potential(desired_altitude).
  Local desired_kinetic to invariant_specific_energy - desired_potential.
  Return sqrt(2 * desired_kinetic).
}.
Local function orbital_velocity_at_altitude {
  Parameter desired_altitude.
  Return sqrt(body:mu / (body_radius + desired_altitude)).
}.


function Launch {
  Parameter MAX_TIME_TO_APOAPSIS is 20.
  Parameter TURN_ANGLE is 20.
  Parameter MAX_DYNAMIC_PRESSURE to 0.17.

  Local orig_control to ship:controlpart.
  Core:part:parent:controlfrom().

  Local control is ship:control.

  Local GOAL_APOAPSIS to 70_400.
  Local GOAL_PERIAPSIS to 70_300.
  
  Local cf to control_flow:new().

  Local start_time to time:seconds.
  Cf:enqueue_op("ignition").
  Cf:register_op("ignition", {
    If ship:status = "PRELAUNCH" {
      Stage.
      Set start_time to time:seconds.
    }.
    Return list("throttle", "steering").
  }).

  {
    Local pid_throttle is pidloop(50.0, 2.0, 50.0, 0, 1).
    Set pid_throttle:setpoint to MAX_DYNAMIC_PRESSURE.
    Local update_eta to define_update_eta().
    Local eng_list to list().
    List engines in eng_list.
    Local burn_time to 0.
    Cf:register_sequence("throttle", list(
      {
        Set control:pilotmainthrottle to 1.0.
        Return false.
      }, {
        Set control:pilotmainthrottle to pid_throttle:update(time:seconds, ship:Q).
        Return alt:apoapsis < GOAL_APOAPSIS - 2000.
      }, {
        Set pid_throttle to pf_controller(0.01, 1, 0, 1).
        Set pid_throttle:setpoint to GOAL_APOAPSIS.
        Set control:pilotmainthrottle to pid_throttle:update(time:seconds, alt:apoapsis).
        Return false.
      }, {
        Set control:pilotmainthrottle to pid_throttle:update(time:seconds, alt:apoapsis).
        Return eta:apoapsis > MAX_TIME_TO_APOAPSIS.
      },
      {
        Set control:pilotmainthrottle to 0.

        Local delta_v to orbital_velocity_at_altitude(GOAL_APOAPSIS) - speed_at_altitude(GOAL_APOAPSIS).
        Local circularization_node to  node(time:seconds + eta:apoapsis, 0, 0, delta_v).
        Add circularization_node.
        Set burn_time to getBurnTime(delta_v).
      },
      {
        Return nextNode:eta > burn_time / 2.
      },
      {
        Set control:pilotmainthrottle to 1.0.
      },
      {
        Return ship:orbit:periapsis < 60_000.
      },
      {
        Set control:pilotmainthrottle to 0.1.
      },
      {
        Return ship:orbit:periapsis < GOAL_PERIAPSIS.
      },
      {
        Set control:pilotmainthrottle to 0.0.
        Remove allNodes[0].
      }
    )).
  }
  {
    Local surface_fraction_prograde to 1.0.
    Local pitch_smoother to lib_smoothing:rate_limited(90, 2.0).  // 2.0 degrees per second
    Local rotation_kp to 1.0.
    Local rotation_kd to rotation_kp * 4.0.

    Local pid_apoapsis to pf_controller(0.3, 4).
    Set pid_apoapsis:setpoint to GOAL_APOAPSIS.
    Local smoothed_pid_apoapsis to lib_smoothing:exponential_moving_avg(4.0).
    Local pid_eta_apoapsis to pf_controller(0.2, 6).


    Cf:register_sequence("steering", list(
      {
        Local target_direction to ship:up:vector.
        Local now to time:seconds.
        Local angularvel to ship:angularvel.
        Local facing to ship:facing.
        Local desired_up to heading(90, 0):vector.

        Local control_rotation to
            (1 / max(1e-3, control:pilotmainthrottle)) * direction_rotation_controller(
                target_direction,
                desired_up,
                reference_frame_angular_velocity(),
                rotation_kp,
                rotation_kd).
        Set control_rotation:z to 10 * control_rotation:z.
        Set control:rotation to control_rotation.
        Return ship:verticalspeed <= 100.
      }, {
        Local desired_pitch to pitch_smoother:update(time:seconds, 90 - TURN_ANGLE).
        Local desired_heading to heading(90, desired_pitch).
        Local control_rotation to
            (1 / max(1e-3, control:pilotmainthrottle)) * direction_rotation_controller(
                desired_heading:vector,
                -ship:up:vector,
                srfprograde_angular_velocity(),
                rotation_kp,
                rotation_kd).
        Set control_rotation:z to 10 * control_rotation:z.
        Set control:rotation to control_rotation.
        Return vang(ship:velocity:surface, ship:up:vector) < TURN_ANGLE.
      },
      control_flow:fork("surface_to_orbital_prograde"),
      {
        Local prograde to surface_fraction_prograde * ship:velocity:surface:normalized +
                          (1 - surface_fraction_prograde) * ship:velocity:orbit:normalized.
        Local desired_facing to heading(90, 90 - vang(ship:up:vector, prograde)):vector.
        Local desired_up to vxcl(desired_facing, -ship:up:vector).
        Local desired_angular_velocity to
            surface_fraction_prograde * srfprograde_angular_velocity() +
            (1 - surface_fraction_prograde) * prograde_angular_velocity().
        Local control_rotation to
            (1 / max(1e-3, control:pilotmainthrottle)) * direction_rotation_controller(
                desired_facing,
                desired_up,
                desired_angular_velocity,
                rotation_kp,
                rotation_kd).
        Set control_rotation:z to 10 * control_rotation:z.
        Set control:rotation to control_rotation.
        Return not hasNode.
      }, {
        If not hasNode { Return false. }.
        Local target_direction to nextNode:burnvector.
//        Local attitude_adjustment to pid_apoapsis:update(time_secs, alt:apoapsis) /
//            max(1e-3, control:pilotmainthrottle).
//        Set attitude_adjustment to clip(attitude_adjustment, -10, 10).
//        Set attitude_adjustment to smoothed_pid_apoapsis:update(time_secs, attitude_adjustment).
//        Local desired_heading to heading(90, attitude_adjustment).
        Local factor to choose 1.0 if RCS else (1 / max(1e-3, control:pilotmainthrottle)).
        Set control:rotation to
             factor * direction_rotation_controller(
                target_direction,
                -ship:up:vector,
                prograde_angular_velocity(),
                rotation_kp,
                rotation_kd).
        Return nextNode:eta > 0.
      },
      {
        Local attitude_adjustment to pid_eta_apoapsis:update(time:seconds, adjusted_eta(eta:apoapsis)).
        Set attitude_adjustment to clip(attitude_adjustment, -10, 10).
        Local desired_heading to heading(90, attitude_adjustment).
        Set control:rotation to direction_rotation_controller(
            desired_heading:vector,
            -ship:up:vector,
            prograde_angular_velocity(),
            rotation_kp,
            rotation_kd).
        Return not cf:sequence_done("throttle").
      }
    )).

    Cf:register_sequence("surface_to_orbital_prograde", list(
      { Return ship:Q >= 0.01 or ship:airspeed < 1000. },
      {
        Stage.  // deploy payload fairing
      },
      {
        // Ensure change is gradual.
        Set surface_fraction_prograde to clip(ship:Q / 0.01, 0, 1).
        Return ship:Q > 0.0001.
      }, {
        Set surface_fraction_prograde to 0.0.
      }
    )).

  }.

  Until not cf:active() {
    Cf:run_pass().
    Wait 0.
  }
  Control:neutralize on.
  Orig_control:controlfrom().
  Wait 0.

  HUDText("Program finished; returning control.", 5, 2, 15, green, true).
}
