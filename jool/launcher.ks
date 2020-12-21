@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/clip").
RunOncePath("0:/my_lib/controller.ks").

Local function define_update_eta {
  Local pid_eta is pidloop(0, 0, 1.0).
  Local prev_output is 0.
  Local prev_dOdt is 0.
  Local prev_time is 0.
  Return {
    Local current_time is time:seconds.
    If prev_time = 0 { Set prev_time to current_time. }
    If prev_time = current_time { Return prev_output. }
    Local interval is current_time - prev_time.
    Set prev_time to current_time.
    Local adjusted_apoapsis to eta:apoapsis.
    If adjusted_apoapsis > ship:orbit:period / 2 {
      Set adjusted_apoapsis to adjusted_apoapsis - ship:orbit:period.
    }
    Local dOdt is pid_eta:update(current_time, adjusted_apoapsis) - 0.2.
    Local retv is clip(prev_dOdt * interval + prev_output, 0, 1).
    Set prev_output to retv.
    Set prev_dOdt to dOdt.
    Return retv.
  }.
}

Local function is_apoapsis_closer {
  Local period is ship:orbit:period.
  Local eta_ap is eta:apoapsis.
  Local ap_dist is min(eta_ap, period - eta_ap).
  Local eta_per is eta:periapsis.
  Local per_dist is min(eta_per, period - eta_per).
  Return ap_dist < per_dist.
}

function Launch {
  Parameter MAX_TIME_TO_APOAPSIS is 20.
  Parameter TURN_ANGLE is 20.

  Local orig_control to ship:controlpart.
  Core:part:parent:controlfrom().

  Local control is ship:control.

  Local MAX_DYNAMIC_PRESSURE is 0.17.

  Local pid_pressure is pidloop(50.0, 2.0, 50.0, 0, 1).
  Set pid_pressure:setpoint to MAX_DYNAMIC_PRESSURE.
  Lock throttle to pid_pressure:update(time:seconds, ship:Q).


  Local pid_pitch is pidloop(3.2, 16.0, 0.0, -1, 1).
  Local pid_yaw is pidloop(3.2, 6.4, 0.0, -1, 1).
  Local pid_roll is pidloop(0.9, 0, 19.2, -1.0, 1.0).
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
      Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
      Local pid_yaw is pidloop(5.0, 0.1, 10.0, -1, 1).
      Local pid_pitch is pidloop(2.5, 1.5, 10.0, -1, 1).
      Set pid_pitch:setpoint to 6 * CONSTANT:DegToRad. 
      On time:seconds {
        Local target_direction to heading(90, 90-TURN_ANGLE):vector.
        Local desired_ang_vel to vcrs(ship:velocity:orbit, body:position) / body:position:sqrmagnitude.
        Local desired_up to V(0,0,0).
        Local init_rotation to
            direction_rotation_controller(
                target_direction,
                desired_up,
                desired_ang_vel,
                rotation_kp,
                rotation_kd).
        Set control:rotation to init_rotation.
        If vang(ship:facing:forevector, ship:up:vector) < TURN_ANGLE {
          Return true.
        } else {
          Print "now maintaining angle".
          On time:seconds {
            Local target_direction to heading(90, 90-TURN_ANGLE):vector.
            Local desired_ang_vel to vcrs(ship:velocity:orbit, body:position) / body:position:sqrmagnitude.
            Local desired_up to V(0,0,0).
            Local init_rotation to
                direction_rotation_controller(
                    target_direction,
                    desired_up,
                    desired_ang_vel,
                    rotation_kp,
                    rotation_kd).
            Set control:rotation to init_rotation.
            If vang(ship:up:vector, ship:srfprograde:vector) < TURN_ANGLE {
              Return true.
            }
            Print "now following prograde".
            On time:seconds {
              Local target_direction to vxcl(ship:north:vector, ship:velocity:surface):normalized.
              Local desired_ang_vel to vcrs(ship:velocity:orbit, body:position) / body:position:sqrmagnitude.
              Local desired_up to V(0,0,0).
              Local init_rotation to
                  direction_rotation_controller(
                      target_direction,
                      desired_up,
                      desired_ang_vel,
                      rotation_kp,
                      rotation_kd).
              Set control:rotation to init_rotation.
              If altitude < 50000 and ship:velocity:surface:mag < 1300 { Return true. }

              Set control:neutralize to true.
              SAS on.
              Local current_time is time:seconds.
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

        When alt:apoapsis >= 68000 then {
          AG1 on.  // Shut down less efficient engines.
          Lock throttle to 0.04.  // Help maintain attitude.

        When eta:apoapsis <= MAX_TIME_TO_APOAPSIS + 5 then {
          Stage.  // payload faring
        }

        When alt:apoapsis >= 70000 or eta:apoapsis <= MAX_TIME_TO_APOAPSIS then {
          Lock throttle to 0.

          Local eng_list is list().
          List engines in eng_list.

          When eta:apoapsis <= MAX_TIME_TO_APOAPSIS then {
            Local update_eta is define_update_eta().
            Lock throttle to choose 1.0
                             if eta:apoapsis > 10 * 60 and alt:periapsis < 70000
                             else choose update_eta()
                             if min(eta:apoapsis, ship:orbit:period - eta:apoapsis) <= MAX_TIME_TO_APOAPSIS
                                or alt:apoapsis - alt:periapsis < 300
                                or alt:apoapsis < 70300
                             else 0.
            When throttle < 0.05 and eta:apoapsis <  MAX_TIME_TO_APOAPSIS - 10 then {
              For engine in eng_list {
                If engine:ignition {
                  Set engine:thrustlimit to 10.
                }
              }
            }
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
}
