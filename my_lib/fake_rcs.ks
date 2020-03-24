@LAZYGLOBAL OFF.

Runpath("0:/my_lib/clip").

Global FakeRCS is lex().

Set FakeRCS["engage"] to {
  Local control is ship:control.

  Local fake_rcs is ship:partsdubbed("fakeRCS").
  Local function set_fake_rcs {
    If RCS {
      Local translation to control:translation.
      Local yaw is control:yaw.
      Local pitch is control:pitch.
      Local facing is ship:facing.
      For engine in fake_rcs {
        If not engine:ignition { Engine:activate(). }
        Local steering_relevance is vdot(engine:facing:forevector,
            yaw*facing:starvector + pitch*facing:upvector).
        If vdot(engine:position - ship:position, ship:facing:forevector) < 0 {
          Set steering_relevance to -steering_relevance.
        }
        Local translation_relevance is vdot(engine:facing:forevector,
            translation:x*facing:starvector + translation:y*facing:upvector + translation:z*facing:forevector).
        Local power is clip(steering_relevance + translation_relevance, 0, 1).
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
