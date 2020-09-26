@LAZYGLOBAL OFF.

Local camera to addons:camera:flightcamera.

Local south_launchpad to vessel("South Launchpad").
Local camera_geo to Kerbin:geopositionOf(south_launchpad:position + 200 * (13 * -south_launchpad:north:starvector + 6 * -south_launchpad:north:vector)).

Set camera:mode to "FREE".
On camera:mode {
  Set camera:mode to "FREE".
  Return true.
}.

Local bounds to ship:bounds.
Local size to (bounds:furthestCorner(ship:up:vector) - bounds:furthestCorner(-ship:up:vector)):mag.

//Set camera:target to ship.
Set camera:fov to 5.0.


Local shrinking to false.

Local function relative_size {
  Local size_radians to size / camera:distance.
  Return size_radians * constant:RadToDeg.
}.


Until false {
  Local desired_position to camera_geo:altitudePosition(100).
  Set camera:position to desired_position.  // Problem: setting heading, pitch, and distance overrides this.
  Set camera:distance to desired_position:mag.
  //Set camera:heading to camera_geo:heading.
  //Set camera:pitch to 0.
  Local arc to relative_size().
  If camera:fov > 2.0 * arc {
    Shrinking on.
  } else if camera:fov < 1.0 * arc {
    Shrinking off.
  }.
  If shrinking {
    Set camera:fov to 0.99 * camera:fov.
  }.
  Wait 0.
}.

