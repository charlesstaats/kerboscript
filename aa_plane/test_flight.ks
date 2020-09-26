@LAZYGLOBAL OFF.

RunOncePath("0:/KSLib/library/lib_location_constants").
RunOncePath("0:/my_lib/basic_control_flow").
RunOncePath("0:/my_lib/clip").

Brakes on.
Wait 10.
Local neutral_pitch to arcsin(ship:up:vector * ship:facing:vector).
Local runway_altitude to ship:altitude.
Local aa to addons:aa.

Local MAX_BEARING to 60.
Local function moderated_bearing {
  Parameter bearing.
  Until bearing <= 180 {
    Set bearing to bearing - 360.
  }.
  Until bearing > -180 {
    Set bearing to bearing + 360.
  }.
  If bearing > MAX_BEARING {
    Return MAX_BEARING.
  } else if bearing < -MAX_BEARING {
    Return -MAX_BEARING.
  }
  Return bearing.
}.

Local function dir2heading {
  Parameter direction to ship:srfprograde:vector.
  Local east to heading(90, 0):vector.
  Return arctan2(direction * east, direction * ship:north:vector).
}.

Brakes off.
Lock steering to heading(location_constants:kerbin:runway_09_overrun:heading, neutral_pitch).
Lock throttle to 1.0.
Stage.

Wait until ship:airspeed > 95.

Lock steering to heading(90, 15).

Local bounds to ship:bounds.
Wait until bounds:bottomaltradar > 5.

Gear off.
Unlock steering.
Aa:director on.
Set aa:direction to heading(90, 5):vector.
Aa:moderateG on.
Set aa:maxG to 2.0.
Unlock throttle.
Set aa:speed to 250.
Aa:speedcontrol on.

Wait until ship:altitude >= 2400.
Aa:director off.
Aa:cruise on.
Set aa:heading to 90.
Set aa:altitude to 2500.

Wait until location_constants:reverse_runway_start:position:mag > 60_000.
KUniverse:TimeWarp:CancelWarp().
Print "turning around".
Aa:cruise off.
Aa:director on.
Aa:wingleveler off.

Local landing_location to location_constants:kerbin:runway_27_start.
Local runway_end to location_constants:kerbin:runway_27_end.

Local cf to control_flow:new().

Cf:register_and_enqueue_seq("steering", list({
    Local my_heading to dir2heading().
    Local dest_heading to landing_location:heading.//my_heading + moderated_bearing(landing_location:heading - my_heading).
    Local intended_heading to
        dir2heading(location_constants:kerbin:runway_27_end:position - landing_location:position).
    If abs(my_heading - intended_heading) < 30 {
      Set intended_heading to intended_heading + 3 * (dest_heading - intended_heading).
    }.
    Set intended_heading to my_heading + moderated_bearing(intended_heading - my_heading).
    Local horiz_distance to vxcl(ship:up:vector, landing_location:position):mag.
    Local vert_distance to runway_altitude - ship:altitude.
    Local intended_pitch to arctan2(vert_distance, horiz_distance).
    Set aa:direction to heading(intended_heading, intended_pitch):vector.
    Return horiz_distance > 3000 and ship:altitude > runway_altitude + 200.
  }, {
    Aa:director off.
    Aa:cruise on.
    Set aa:heading to runway_end:heading.
    Set aa:altitude to runway_altitude + 6.
    Gear on.
  }, {
    Set aa:heading to runway_end:heading.
//    Return landing_location:position * ship:facing:vector > 0.  
//  },
//  {
//    Set aa:vertspeed to -1.0.  
//    Set aa:heading to runway_end:heading.
//  },
//  {
//    Set aa:heading to runway_end:heading.
    Return ship:status <> "LANDED".  
  }, {
    Print "landed".
    Aa:cruise off.
    Brakes on.
    Local landing_time to time:seconds.
    Local init_pitch to arcsin(ship:facing:vector * ship:up:vector).
//    Local desired_pitch to {
//      Local t to clip((time:seconds - landing_time) / 3, 0, 1).
//      Return (1 - t) * init_pitch + t * neutral_pitch.
//    }.
//    Lock steering to heading(runway_end:heading, desired_pitch()).  
    Lock steering to heading(runway_end:heading, 0).//neutral_pitch).
  })
).

Cf:register_and_enqueue_seq("speed", list({
    Return landing_location:position:mag > 14000.
  }, 
  {
    KUniverse:TimeWarp:CancelWarp().
    Set aa:speed to 70.  
    Aa:speedcontrol on.
    Gear on.
  },
  {
    Return landing_location:position * ship:facing:vector > 0.  
  },
  {
    Set aa:speed to 50.
  },
  {
    Return ship:status <> "LANDED".  
  }, {
    Aa:cruise off.
    Brakes on.  
    Lock throttle to 0.
  }, {
    Return ship:velocity:surface:mag > 0.01.  
  })
).

Until not cf:active() {
  Cf:run_pass().
  Wait 0.
}.

Unlock steering.
Unlock throttle.
Print "Script finished.".
