@LAZYGLOBAL OFF.

Runpath("0:/my_lib/clip").

Global FakeRCS is lex().

Set FakeRCS["engage"] to {
  Local control is ship:control.

  Local fake_rcs is ship:partsdubbed("fakeRCS").
  Local function set_fake_rcs {
    If RCS {
      For engine in fake_rcs {
        If not engine:ignition { Engine:activate(). }
        Local steering_relevance is vdot(engine:facing:forevector,
            control:yaw*ship:facing:starvector + control:pitch*ship:facing:upvector).
        Local power is clip(steering_relevance, 0, 1).
        Set engine:thrustlimit to 100 * power.
      }
    } else {
      For engine in fake_rcs {
        If engine:ignition {
          Set engine:thrustlimit to 0.
          Engine:shutdown().
        }
      }
    }
  }

  On time:seconds {
    Set_fake_rcs().
    Return true.
  }
}.
