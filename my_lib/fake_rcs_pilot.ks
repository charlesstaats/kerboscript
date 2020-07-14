@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/clip").

Global FakeRCS to lex().

Local fake_rcs to list().

Set FakeRCS["find_engines"] to {
  Set fake_rcs to ship:partsdubbed("fakeRCS").
}.

Local control to ship:control.

Local function set_fake_rcs {
  If RCS {
    Local translation to control:pilottranslation.
    Local yaw to control:pilotyaw.
    Local pitch to control:pilotpitch.
    Local facing to ship:facing.
    For engine in fake_rcs {
      If not engine:ignition { Engine:activate(). }.
      Local steering_relevance to vdot(engine:facing:forevector,
          yaw*facing:starvector + pitch*facing:upvector).
      If vdot(engine:position - ship:position, ship:facing:forevector) < 0 {
        Set steering_relevance to -steering_relevance.
      }.
      Local translation_relevance to vdot(engine:facing:forevector,
          translation:x*facing:starvector + translation:y*facing:upvector + translation:z*facing:forevector).
      Local power to clip(steering_relevance + translation_relevance, 0, 1).
      Set engine:thrustlimit to 100 * power.
    }.
  } else {
    For engine in fake_rcs {
      If engine:ignition {
        Set engine:thrustlimit to 0.
        Engine:shutdown().
      }.
    }.
  }.
}.

Set FakeRCS["adjust"] to set_fake_rcs@.

Set FakeRCS["refresh_control"] to {
  Set control to ship:control.
}.

Set FakeRCS["engage"] to {
  FakeRCS:find_engines().
  Set control to ship:control.

  On time:seconds {
    Set_fake_rcs().
    Return true.
  }.
}.
