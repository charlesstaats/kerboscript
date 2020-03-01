@LAZYGLOBAL OFF.

function clip {
  Parameter t, low is -1.0, high is 1.0.

  Return min(high, max(low, t)).
}

Local pitch_rate to 1.0.

Local yaw_rate to 1.0.
Local yaw_remembered to 0.0.
Local pid_yaw is pidloop(0.2, 0.2, 0.2, -0.2, 0.2).
Local roll_rate to 2.0.
Local roll_remembered to 0.0.
Local pid_roll is pidloop(0.2, 0.2, 0.2, -0.2, 0.2).

Local control to ship:control.
Local last_time to time:seconds.

On time:seconds {
  Local interval to time:seconds - last_time.
  Set last_time to time:seconds.
  If SAS or altitude > 40000 {
    Set control:neutralize to true.  // Don't conflict with SAS.
  } Else {
    If control:pilotpitch <> 0 {
      Set control:pitch to clip(control:pitch + control:pilotpitch * pitch_rate * interval).
    }


    If control:pilotroll = 0 {
      Set control:roll to pid_roll:update(time:seconds, -vdot(ship:angularvel, ship:facing:forevector)).
      If roll_remembered > 0 {
        Set roll_remembered to max(0, roll_remembered - roll_rate * interval).
      } else {
        Set roll_remembered to min(0, roll_remembered + roll_rate * interval).
      }
    } else {
      Set roll_remembered to clip(roll_remembered + control:pilotroll * roll_rate * interval).
      Set control:roll to roll_remembered.
      Pid_roll:reset().
    }
    
    If control:pilotyaw = 0 {
      Set control:yaw to pid_yaw:update(time:seconds, -vdot(ship:angularvel, ship:facing:upvector)).
      If yaw_remembered > 0 {
        Set yaw_remembered to max(0, yaw_remembered - yaw_rate * interval).
      } else {
        Set yaw_remembered to min(0, yaw_remembered + yaw_rate * interval).
      }
    } else {
      Set yaw_remembered to clip(yaw_remembered + control:pilotyaw * yaw_rate * interval).
      Set control:yaw to yaw_remembered.
      Pid_yaw:reset().
    }
  }
  Return true.
}

On (altitude > 40000) {
  If altitude > 40000 {
    HUDText("Disabling plane control.", 5, 1, 15, yellow, false).
  } else {
    HUDText("Enabling plane control.", 5, 1, 15, yellow, false).
  }
}

Wait until false.
