@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/clip").
RunOncePath("0:/my_lib/controller").
RunOncePath("0:/my_lib/lib_smoothing").

Local function define_update_eta {
  Local pid_eta to pidloop(0, 0, 1.0).
  Local prev_output to 0.
  Local prev_dOdt to 0.
  Local prev_time to 0.
  Return {
    Local current_time to time:seconds.
    If prev_time = 0 { Set prev_time to current_time. }
    If prev_time = current_time { Return prev_output. }
    Local interval to current_time - prev_time.
    Set prev_time to current_time.
    Local adjusted_apoapsis to eta:apoapsis.
    If adjusted_apoapsis > ship:orbit:period / 2 {
      Set adjusted_apoapsis to adjusted_apoapsis - ship:orbit:period.
    }
    Local dOdt to pid_eta:update(current_time, adjusted_apoapsis) - 0.2.
    Local retv to clip(prev_dOdt * interval + prev_output, 0, 1).
    Set prev_output to retv.
    Set prev_dOdt to dOdt.
    Return retv.
  }.
}

Local function is_apoapsis_closer {
  Local period to ship:orbit:period.
  Local eta_ap to eta:apoapsis.
  Local ap_dist to min(eta_ap, period - eta_ap).
  Local eta_per to eta:periapsis.
  Local per_dist to min(eta_per, period - eta_per).
  Return ap_dist < per_dist.
}

function Launch {
  Parameter MAX_TIME_TO_APOAPSIS to 30.
  Parameter TURN_ANGLE to 20.
  Parameter MAX_DYNAMIC_PRESSURE to 0.17.

  Local orig_control to ship:controlpart.
  Core:part:parent:controlfrom().

  Local control to ship:control.


  Local pid_pressure to pidloop(50.0, 2.0, 50.0, 0, 1).
  Set pid_pressure:setpoint to MAX_DYNAMIC_PRESSURE.
  Lock throttle to pid_pressure:update(time:seconds, ship:Q).


  Local pid_pitch to pidloop(3.2, 16.0, 0.0, -1, 1).
  Local pid_yaw to pidloop(3.2, 6.4, 0.0, -1, 1).
  Local pid_roll to pidloop(0.9, 0, 19.2, -1.0, 1.0).
  Local rotation_kp to 10.0.
  Local rotation_kd to rotation_kp * 4.0.
  Local initial_ascent to true.

  Stage.

  On time:seconds {
    If SAS or not initial_ascent { Return false. }
    Local target_direction to ship:up:vector.
    Local desired_ang_vel to vcrs(ship:velocity:orbit, body:position) / body:position:sqrmagnitude.
    Local desired_up to -ship:north:vector.
    Local init_rotation to
        direction_rotation_controller(
            target_direction,
            desired_up,
            desired_ang_vel,
            rotation_kp,
            rotation_kd).
    Set control:rotation to init_rotation.
    Return true.
  }

  When verticalspeed > 2.5 then {
    Gear off.

    When verticalspeed > 100 then {
      Set initial_ascent to false.
      Set control:pitch to 0.05.
      Local pid_roll to pidloop(10.0, 20.0, 10.0, -1, 1).
      Local pid_pitch to pidloop(7.2, 6.0, 2.16, -1, 1).
      Local pid_yaw to pidloop(1.0, 0.6, 2.0, -1, 1).
      Set pid_yaw:setpoint to 6 * CONSTANT:DegToRad. 
      On time:seconds {
        Local target_direction to heading(90, 90-TURN_ANGLE):vector.

        Local reference_frame_rotation to vcrs(ship:velocity:orbit, body:position) / body:position:sqrmagnitude.
        Local gravitational_acceleration to body:position:normalized * body:mu / body:position:sqrmagnitude.
        Local prograde_rotation to vcrs(ship:velocity:surface, gravitational_acceleration) / ship:velocity:surface:sqrmagnitude.
        Local desired_up to V(0,0,0).
        Local init_rotation to
            direction_rotation_controller(
                target_direction,
                desired_up,
                reference_frame_rotation + prograde_rotation,
                rotation_kp,
                rotation_kd).
        Set control:rotation to init_rotation.
        If vang(ship:facing:forevector, ship:up:vector) < TURN_ANGLE {
          Return true.
        } else {
          Print "now maintaining angle".
          On time:seconds {
            Local target_direction to heading(90, 90-TURN_ANGLE):vector.
            Local reference_frame_rotation to vcrs(ship:velocity:orbit, body:position) / body:position:sqrmagnitude.
            Local gravitational_acceleration to body:position:normalized * body:mu / body:position:sqrmagnitude.
            Local prograde_rotation to vcrs(ship:velocity:surface, gravitational_acceleration) / ship:velocity:surface:sqrmagnitude.
            Local desired_up to V(0,0,0).
            Local init_rotation to
                direction_rotation_controller(
                    target_direction,
                    desired_up,
                    reference_frame_rotation + prograde_rotation,
                    rotation_kp,
                    rotation_kd).
            Set control:rotation to init_rotation.
            If vang(ship:up:vector, ship:srfprograde:vector) < TURN_ANGLE {
              Return true.
            }
            Print "now following prograde".
            On time:seconds {
              Local target_direction to vxcl(ship:north:vector, ship:velocity:surface):normalized.
              Local reference_frame_rotation to vcrs(ship:velocity:orbit, body:position) / body:position:sqrmagnitude.
              Local gravitational_acceleration to body:position:normalized * body:mu / body:position:sqrmagnitude.
              Local prograde_rotation to vcrs(ship:velocity:surface, gravitational_acceleration) / ship:velocity:surface:sqrmagnitude.
              Local desired_up to V(0,0,0).
              Local init_rotation to
                  direction_rotation_controller(
                      target_direction,
                      desired_up,
                      reference_frame_rotation + prograde_rotation,
                      rotation_kp,
                      rotation_kd).
              Set control:rotation to init_rotation.
              If altitude < 50000 and ship:velocity:surface:mag < 1300 { Return true. }

              Set control:neutralize to true.
              SAS on.
              Local current_time to time:seconds.
              When time:seconds > current_time + 0.5 then {
                Set SASMode to "PROGRADE".
              }
              Return false.
            }
            Return false.
          }
          Return false.
        }
      }

      When alt:apoapsis >= 70400 then {
        Local apoapsis_throttle_pid to pf_controller(0.01, 1, 0, 1).
        Set apoapsis_throttle_pid:setpoint to 70400.
        Lock throttle to apoapsis_throttle_pid:update(time:seconds, alt:apoapsis).

        When eta:apoapsis <= MAX_TIME_TO_APOAPSIS + 10 then {
          Stage.  // payload fairing
        }
        Local eng_list to list().
        List engines in eng_list.

        When eta:apoapsis <= MAX_TIME_TO_APOAPSIS then {
          Local update_eta to define_update_eta().
          Lock throttle to choose update_eta()
                           if min(eta:apoapsis, ship:orbit:period - eta:apoapsis) <= MAX_TIME_TO_APOAPSIS
                              or alt:apoapsis - alt:periapsis < 300
                              or alt:apoapsis < 70300
                           else 0.
          When alt:periapsis > 50_000 then {
            For engine in eng_list {
              If engine:ignition {
                Set engine:thrustlimit to 10.
              }
            }
          }

          Local pid_apoapsis to pf_controller(0.3, 4).
          Set pid_apoapsis:setpoint to 70400.
          Local smoothed_attitude_adjustment to lib_smoothing:exponential_moving_avg(4.0).
          SAS off.
          When true then {
            Local time_secs to time:seconds.
            Local attitude_adjustment to pid_apoapsis:update(time_secs, alt:apoapsis) / max(throttle, 1e-3).
            Set attitude_adjustment to clip(attitude_adjustment, -10, 10).
            Set attitude_adjustment to smoothed_attitude_adjustment:update(time_secs, attitude_adjustment).
            Local target_direction to heading(90, attitude_adjustment):vector.
            Local gravitational_acceleration to body:position:normalized * body:mu / body:position:sqrmagnitude.
            Local desired_ang_vel to vcrs(ship:velocity:orbit, gravitational_acceleration) / ship:velocity:orbit:sqrmagnitude.
            Local desired_up to V(0,0,0).
            Local init_rotation to
                direction_rotation_controller(
                    target_direction,
                    desired_up,
                    desired_ang_vel,
                    rotation_kp,
                    rotation_kd).
            Set control:rotation to init_rotation.
            Return alt:periapsis < 70300.
          }.
        }

        When alt:periapsis >= 70300 then {
          Unlock throttle.
          For engine in eng_list {
            If engine:ignition {
              Set engine:thrustlimit to 100.
            }
          }
          Orig_control:controlfrom().
          HUDText("Program finished; returning throttle control.", 5, 2, 15, green, false).
        }
      }
    }
  }
}
