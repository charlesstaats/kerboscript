@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/controller").

Local rotation_kp to 100.0.
Local rotation_kd to 4.0 * rotation_kp.
Until not hasNode {
  Local target_direction to nextNode:burnvector.
  Local factor to (1 / max(0.1, ship:control:pilotmainthrottle)).
  Set ship:control:rotation to
     factor * direction_rotation_controller(
        target_direction,
        -ship:up:vector,
        V(0,0,0),
        rotation_kp,
        rotation_kd).
  Wait 0.
}.

Ship:control:neutralize on.
