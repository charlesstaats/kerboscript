@LAZYGLOBAL OFF.

Runoncepath("0:/my_lib/basic_control_flow").
Runoncepath("0:/my_lib/clip").
Runoncepath("0:/my_lib/pump_fuel").

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
    Local retv is clip(0.2 * prev_dOdt * interval + prev_output, 0, 1).
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
  Local RAMP_UP_TIME to 3.
  
  Local cf to control_flow:new().

  {
    Local start_time to time:seconds.
    Cf:enqueue_op("ignition").
    Cf:register_op("ignition", {
      If ship:status = "LANDED" {
        Stage.
        Set start_time to time:seconds.
      }
      Return ["throttle", "steering"].
    }).
  }

  {
    Local pid_pressure is pidloop(50.0, 2.0, 50.0, 0, 1).
    Set pid_pressure:setpoint to MAX_DYNAMIC_PRESSURE.
    Local update_eta to define_update_eta().
    Local eng_list to list().
    List engines in eng_list.
    Cf:register_sequence("throttle", [
      {
        Local now to time:seconds.
        If now - start_time < RAMP_UP_TIME {
          Set control:pilotmainthrottle to min(1.0, (now - start_time) / ramp_up_time).
          Return true.
        }
        Set control:pilotmainthrottle to 1.0.
        Return false.
      }, {
        Set control:pilotmainthrottle to pid_pressure:update(time:seconds, ship:Q).
        Return alt:apoapsis < 68000.
      }, {
        Set control:pilotmainthrottle to 0.02.
        Return alt:apoapsis < 70000 and eta:apoapsis > MAX_TIME_TO_APOAPSIS.
      }, {
        Set control:pilotmainthrottle to 0.
        Return false.
      }, {
        Return eta:apaopsis > MAX_TIME_TO_APOAPSIS.
      },
      control_flow:fork("fine_throttle"),
      {
        If min(eta:apoapsis, ship:orbit:period - eta:apoapsis) <= MAX_TIME_TO_APOAPSIS
            or alt:apoapsis - alt:periapsis < 300
            or alt:apoapsis < 70300 {
          Set control:pilotmainthrottle to update_eta().
        } else {
          Set control:pilotmainthrottle to 0.
        }
        Return alt:periapsis < 70300.
      }, {
        Set control:pilotmainthrottle to 0.
        Return false.
      },
      control_flow:merge("fine_throttle"),
      {
        For engine in eng_list {
          If engine:ignition {
            Set engine:thrustlimit to 100.
          }
        }
        Return false.
      }
    ]).

    Cf:register_sequence("fine_throttle", [
      {
        Return control:pilotmainthrottle >= 0.05 or eta:apoapsis >= MAX_TIME_TO_APOAPSIS - 10.
      }, {
        For engine in eng_list {
          If engine:ignition {
            Set engine:thrustlimit to 10.
          }
        }
        Return false.
      }
    ]).
  }
  {
    Local pid_pitch to pidloop(3.2, 16.0, 0.0, -1, 1).
    Local pid_yaw to pidloop(3.2, 6.4, 0.0, -1, 1).
    Local pid_roll to pidloop(0.8, 0.0, 1.2, -1.0, 1.0).

    Local pi_pitch to pidloop(0.5, 0.1, 0.0).
    Local dd_pitch to pidloop(0.4, 0, 0.2, -1.0, 1.0).

    Local PITCH_BIAS to 0.06.
    Local surface_fraction_prograde to 1.0.

    Cf:register_sequence("steering", [
      {
        Local now to time:seconds.
        Local angularvel to ship:angularvel.
        Local facing to ship:facing.
        Local north to ship:north.

        Set control:pitch to pid_pitch:update(now, -vdot(angularvel, facing:starvector)). 
        Set control:yaw to pid_yaw:update(now, vdot(angularvel, facing:upvector)). 
        Set control:roll to pid_roll:update(now, vdot(facing:upvector, north:forevector)).
        Return ship:verticalspeed <= 100.
      }, {
        Set control:pitch to 0.05.
        Set pid_roll to pidloop(0.2, 0.4, 0.2, -1, 1).
        Set pid_yaw to pidloop(2.0, 1.2, 8.0, -1, 1).
        Set pid_pitch to pidloop(4.0, 1.2, 8.0, -1.0, 1.0).
        Set pid_pitch:setpoint to 6 * CONSTANT:DegToRad. 
        Return false.
      }, {
        Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
        Set control:yaw to pid_yaw:update(time:seconds, vdot(ship:facing:forevector, ship:north:forevector)).
        Set control:pitch to pid_pitch:update(time:seconds,
            -vdot(vcrs(ship:srfprograde:forevector, ship:facing:forevector), ship:facing:starvector)).
        Return vang(ship:facing:forevector, ship:up:vector) < TURN_ANGLE.
      }, {
        Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
        Set control:yaw to pid_yaw:update(time:seconds, vdot(ship:facing:forevector, ship:north:forevector)).
        Local desired_changerate_pitch to pi_pitch:update(time:seconds,
            -vdot(vcrs(ship:srfprograde:forevector, ship:facing:forevector),
                  ship:facing:starvector)).
        Set control:pitch to dd_pitch:update(time:seconds, pi_pitch:changerate - desired_changerate_pitch).
        Return vdot(ship:facing:upvector, ship:srfprograde:forevector) < 0.
      }, {
        Set pid_pitch to pidloop(4.0, 1.2, 8.0, -0.5, 0.5).
        Return false.
      }
    ]).
  }

  Until not cf:active() {
    Cf:run_pass().
    Wait 0.
  }
  Orig_control:controlfrom().
  HUDText("Program finished; returning throttle control.", 5, 2, 15, green, false).

  Local pid_pitch to pidloop(3.2, 16.0, 0.0, -1, 1).
  Local pid_yaw to pidloop(3.2, 6.4, 0.0, -1, 1).
  Local pid_roll to pidloop(0.8, 0.0, 1.2, -1.0, 1.0).
  Cf:register_op("steer_initial_climb", {
    If ship:verticalspeed > 100 then {
      Return "start_turn".
    }
    Local now to time:seconds.
    Local angularvel to ship:angularvel.
    Local facing to ship:facing.
    Local north to ship:north.

    Set control:pitch to pid_pitch:update(now, -vdot(angularvel, facing:starvector)). 
    Set control:yaw to pid_yaw:update(now, vdot(angularvel, facing:upvector)). 
    Set control:roll to pid_roll:update(now, vdot(facing:upvector, north:forevector)).
    Return "steer_initial_climb".
  }).

  Cf:register_op("start_turn", {
    Set control:pitch to 0.05.
    Set pid_roll to pidloop(0.2, 0.4, 0.2, -1, 1).
    Set pid_yaw to pidloop(2.0, 1.2, 8.0, -1, 1).
    Set pid_pitch to pidloop(4.0, 1.2, 8.0, -1.0, 1.0).
    Set pid_pitch:setpoint to 6 * CONSTANT:DegToRad. 
    Return "continue_turn".
  }).

  Cf:register_op("continue_turn", {
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Set control:yaw to pid_yaw:update(time:seconds, vdot(ship:facing:forevector, ship:north:forevector)).
    Set control:pitch to pid_pitch:update(time:seconds, -vdot(vcrs(ship:srfprograde:forevector, ship:facing:forevector), ship:facing:starvector)).
    If vang(ship:facing:forevector, ship:up:vector) < TURN_ANGLE {
      Return "continue_turn".
    } else {
      Return "hold_for_prograde".
    }
  }).

  Local pi_pitch to pidloop(0.5, 0.1, 0.0).
  Local dd_pitch to pidloop(0.4, 0, 0.2, -1.0, 1.0).
  Cf:register_op("hold_for_prograde", {
    Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
    Set control:yaw to pid_yaw:update(time:seconds, vdot(ship:facing:forevector, ship:north:forevector)).
    Local desired_changerate_pitch to pi_pitch:update(time:seconds, -vdot(vcrs(ship:srfprograde:forevector, ship:facing:forevector), ship:facing:starvector)).
    Set control:pitch to dd_pitch:update(time:seconds, pi_pitch:changerate - desired_changerate_pitch).
    If vdot(ship:facing:upvector, ship:srfprograde:forevector) < 0 {
      Return "hold_for_prograde".
    } else {
      Return "start_prograde".
    }
  }).

  Local PITCH_BIAS to 0.06.
  Local surface_fraction_prograde to 1.0.
  Cf:register_op("start_prograde", {
    Set pid_pitch to pidloop(4.0, 1.2, 8.0, -0.5, 0.5).
    Return "continue_prograde".
  }).

  Cf:register_op("continue_prograde", {
  }).

  Local pid_pressure is pidloop(50.0, 2.0, 50.0, 0, 1).
  Set pid_pressure:setpoint to MAX_DYNAMIC_PRESSURE.
  Cf:register_op("ascent_throttle", {
    Set control:pilotmainthrottle to pid_pressure:update(time:seconds, ship:Q).
    // TODO: Move to next phase once apoapsis gets high enough.
    Return "ascent_throttle".
  }).



  Local initial_ascent to true.

  Stage.

  On time:seconds {
    If SAS or not initial_ascent { Return false. }
    Set control:pitch to pid_pitch:update(time:seconds, -vdot(ship:angularvel, ship:facing:starvector)). 
    Set control:yaw to pid_yaw:update(time:seconds, vdot(ship:angularvel, ship:facing:upvector)). 
    Set control:roll to pid_roll:update(time:seconds, vdot(ship:facing:upvector, ship:north:forevector)).
    Return true.
  }


  When verticalspeed > 100 then {
    Set initial_ascent to false.
    Set control:pitch to 0.05.
    Local pid_roll is pidloop(0.2, 0.4, 0.2, -1, 1).
    Local pid_yaw is pidloop(2.0, 1.2, 8.0, -1, 1).
    Local pid_pitch is pidloop(4.0, 1.2, 8.0, -1.0, 1.0).
    Set pid_pitch:setpoint to 6 * CONSTANT:DegToRad. 
    On time:seconds {
      Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
      Set control:yaw to pid_yaw:update(time:seconds, vdot(ship:facing:forevector, ship:north:forevector)).
      Set control:pitch to pid_pitch:update(time:seconds, -vdot(vcrs(ship:srfprograde:forevector, ship:facing:forevector), ship:facing:starvector)).
      If vang(ship:facing:forevector, ship:up:vector) < TURN_ANGLE {
        Return true.
      } else {
        Local pi_pitch to pidloop(0.5, 0.1, 0.0).
        Local dd_pitch to pidloop(0.4, 0, 0.2, -1.0, 1.0).
        On time:seconds {
          Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
          Set control:yaw to pid_yaw:update(time:seconds, vdot(ship:facing:forevector, ship:north:forevector)).
          Local desired_changerate_pitch to pi_pitch:update(time:seconds, -vdot(vcrs(ship:srfprograde:forevector, ship:facing:forevector), ship:facing:starvector)).
          Set control:pitch to dd_pitch:update(time:seconds, pi_pitch:changerate - desired_changerate_pitch).
          If vdot(ship:facing:upvector, ship:srfprograde:forevector) < 0 {
            Return true.
          }
          Print "now following prograde".
          Set pid_pitch to pidloop(4.0, 1.2, 8.0, -0.5, 0.5).
          Local PITCH_BIAS to 0.06.
          Local surface_fraction_prograde to 1.0.
          When ship:Q < 0.01 then {
            Set PITCH_BIAS to 0.0.
            Set pid_yaw:ki to 0.0.
            Set pid_pitch:ki to 0.0.
            Set surface_fraction_prograde to 0.0.
          }
          On time:seconds {
            Local prograde to surface_fraction_prograde * ship:velocity:surface:normalized + (1 - surface_fraction_prograde) * ship:velocity:orbit:normalized.
            Local prograde_pitch_angle to CONSTANT:DegToRad * (90 - vang(ship:up:forevector, prograde)).
            Set pid_pitch:setpoint to prograde_pitch_angle.
            Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)). 
            Set control:yaw to pid_yaw:update(time:seconds, vdot(ship:facing:forevector, ship:north:forevector)).
            Set control:pitch to PITCH_BIAS - pid_pitch:update(time:seconds, CONSTANT:DegToRad * (90 - vang(ship:up:forevector, ship:facing:forevector))).  // Because the cockpit's "ceiling" is towards the ground, need to reverse the pitch control.
            Return true.
          }
          Return false.
        }
        Return false.
      }
    }

    When alt:apoapsis >= 68000 then {
      Lock throttle to 0.02.  // Help maintain attitude.

      When alt:apoapsis >= 70000 or eta:apoapsis <= MAX_TIME_TO_APOAPSIS then {
        Lock throttle to 0.

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
          Orig_control:controlfrom().
          HUDText("Program finished; returning throttle control.", 5, 2, 15, green, false).
        }
      }
    }
  }
}
