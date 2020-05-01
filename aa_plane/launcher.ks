@LAZYGLOBAL OFF.

Local starting_ag3 to AG3.

Local function more_flaps {
  Toggle AG10.
}

Local function less_flaps {
  Toggle AG9.
}

Local neutral_angle to vang(ship:up:forevector, ship:facing:upvector).
Lock steering to heading(90, neutral_angle).
Lock throttle to 1.0.
Stage.

Wait until ship:velocity:surface:mag > 60.
More_flaps().

Wait until ship:velocity:surface:mag > 85.
More_flaps().
Lock steering to heading(90, 15).

Wait until ship:status = "FLYING".

Unlock steering.
Local aa to addons:aa.
Set aa:altitude to 1000.
Set aa:heading to 90.
Aa:cruise on.

Wait until alt:radar > 100.
Less_flaps().
Gear off.
Wait until alt:radar > 300.
Less_flaps().
Wait until ship:velocity:surface:mag > 450.
Set aa:altitude to 20000.

Wait until AG3 <> starting_ag3.
