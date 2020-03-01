local function clip {
  Parameter t, low is -1.0, high is 1.0.

  Return min(high, max(low, t)).
}

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
    Local dOdt is pid_eta:update(current_time, eta:apoapsis) - 0.2.
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

  Local control is ship:control.
  Local pid_pressure is pidloop(100.0, 0.0, 100.0, 0, 1).
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
      Local pid_pitch is pidloop(10.0, 20.0, 10.0, -1, 1).
      Local pid_yaw is pidloop(2.5, 1.5, 10.0, -1, 1).
      Set pid_yaw:setpoint to 0.07. 
      On time:seconds {
        If SAS return false.
        Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
        Set control:pitch to pid_pitch:update(time:seconds, -vdot(ship:angularvel, ship:facing:starvector)).
        Set control:yaw to pid_yaw:update(time:seconds, vdot(vcrs(ship:srfprograde:forevector, ship:facing:forevector), ship:facing:topvector)).
        Return true.
      }
      When vang(ship:facing:forevector, ship:up:vector) >= 22 then {
        Set control:neutralize to true.
        SAS on.
        Local tmp_time is time:seconds.
        When time:seconds >= tmp_time + 5 then {
          Set SASMode to "PROGRADE".
        }
      }

      When alt:apoapsis >= 67500 then {
        AG1 on.  // Disable inefficient engines.
        Lock throttle to 0.

        When eta:apoapsis <= 53 then {
          Stage.  // Deploy fairing.
        }
        When eta:apoapsis <= 50 then {
          Local update_eta is define_update_eta().
          Lock throttle to update_eta().
        }

        When alt:periapsis >= 70000 or (alt:apoapsis >= 70000 and not is_apoapsis_closer()) then {
          Unlock throttle.
          HUDText("Program finished; returning throttle control.", 5, 2, 15, green, false).
        }
      }
    }
  }
}
