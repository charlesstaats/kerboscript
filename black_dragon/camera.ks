@LAZYGLOBAL OFF.

Local camera to addons:camera:flightcamera.

Local stand to vessel("camera stand").
Set ship:loadDistance:landed:unload to 20_000.
Set stand:loadDistance:landed:unload to 20_000.

Set camera:mode to "FREE".
On camera:mode {
  Set camera:mode to "FREE".
  Return true.
}.

Local bounds to ship:bounds.
Local size to (bounds:furthestCorner(ship:up:vector) - bounds:furthestCorner(-ship:up:vector)):mag.

Set camera:target to stand.
Set camera:position to 1.01 * stand:position.
Set camera:fov to 10.0.


Local shrinking to false.

Local function relative_size {
  Local size_radians to size / camera:position:mag.
  Return size_radians * constant:RadToDeg.
}.


Until false {
  Local desired_distance to stand:position:mag + 1.
  Set camera:position to desired_distance * stand:position:normalized.  // Problem: setting heading, pitch, and distance overrides this.
  Local arc to relative_size().
  If camera:fov > 2.0 * arc {
    Shrinking on.
  } else if camera:fov < 1.0 * arc {
    Shrinking off.
  }.
  If shrinking {
    Set camera:fov to 0.96 * camera:fov.
  }.
  Wait 0.
}.

