@LAZYGLOBAL OFF.

Runpath("0:/my_lib/clip").

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
  Local LOG_INFO to false.
  If LOG_INFO {
    Local log_file is "0:/midget/inclination_log.csv".
    Log "time,facing_dot_north" to log_file.
    When verticalspeed > 100 then {
      Local next_log_time is time:seconds.
      When time:seconds >= next_log_time then {
        Set next_log_time to next_log_time + 0.1.

        Local logentry is time:seconds + "," +
                          vdot(ship:facing:forevector, ship:north:forevector).
        Log logentry to log_file.
        Return true.
      }
    }
  }

  Local control is ship:control.

  Local pid_pressure is pidloop(50.0, 2.0, 50.0, 0, 1).
  Set pid_pressure:setpoint to 0.16.
  Lock throttle to pid_pressure:update(time:seconds, ship:Q).

  SAS on.

  Stage.

  When verticalspeed > 2.5 then {
    Gear off.

    When verticalspeed > 100 then {
      SAS off.
      Set control:yaw to 0.05.
      Local pid_roll is pidloop(10.0, 20.0, 10.0, -1, 1).
      Local pid_pitch is pidloop(7.2, 6.0, 2.16, -1, 1).
      Local pid_yaw is pidloop(1.0, 0.6, 2.0, -1, 1).
      Set pid_yaw:setpoint to 6 * CONSTANT:DegToRad. 
      On time:seconds {
        If SAS return false.
        Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
        Set control:pitch to pid_pitch:update(time:seconds, -vdot(ship:north:forevector, ship:facing:forevector)).
        Set control:yaw to pid_yaw:update(time:seconds, vdot(vcrs(ship:srfprograde:forevector, ship:facing:forevector), ship:facing:topvector)).
        Return true.
      }
      When vang(ship:facing:forevector, ship:up:vector) >= 17 then {
        Set control:neutralize to true.
        SAS on.
        Local tmp_time is time:seconds.
        When time:seconds >= tmp_time + 5 then {
          Set SASMode to "PROGRADE".
        }
      

        Local MAX_TIME_TO_APOAPSIS to 30.
        When alt:apoapsis >= 70000 then {

          Lock throttle to 0.

          When eta:apoapsis <= MAX_TIME_TO_APOAPSIS + 10 then {
            Stage.  // Deploy fairing.
          }
          Local eng_list is list().
          List engines in eng_list.
          When eta:apoapsis <= MAX_TIME_TO_APOAPSIS then {
            Local update_eta is define_update_eta().
            Lock throttle to choose update_eta()
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
            HUDText("Program finished; returning throttle control.", 5, 2, 15, green, false).
          }
        }
      }
    }
  }
}
