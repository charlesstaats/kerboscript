@LAZYGLOBAL OFF.

RunOncePath("0:/KSLib/library/lib_location_constants").
RunOncePath("0:/my_lib/basic_control_flow").
RunOncePath("0:/my_lib/clip").

Local aa to addons:aa.
Local runway_altitude to 73.
Local landing_location to location_constants:kerbin:runway_27_start.
Local runway_end to location_constants:kerbin:runway_27_end.


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


Local cf to control_flow:new().
Unlock throttle.

Cf:register_and_enqueue_seq("steering", list({
    Aa:director on.
    Aa:moderateG on.
    Set aa:maxG to 2.0.
    Local my_heading to dir2heading().
    Local dest_heading to landing_location:heading.//my_heading + moderated_bearing(landing_location:heading - my_heading).
    Local intended_heading to
        dir2heading(location_constants:kerbin:runway_27_end:position - landing_location:position).
    Set intended_heading to intended_heading + 3 * moderated_bearing(dest_heading - intended_heading).
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

Cf:register_and_enqueue_seq("speed", list(
  {
    Set aa:speed to 250.
    Aa:speedcontrol on.
  },
  {
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
Set ship:control:pilotmainthrottle to 0.
Print "Script finished.".
