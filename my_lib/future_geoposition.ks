@lazyGlobal off.

Function geoCoordsAtTime {
  Parameter spot.
  Parameter time_secs.

  Local coord_body to spot:body.
  Local future_lng to spot:lng.
  Local delta_t to time_secs - time:seconds.
  Local angular_velocity_degrees to constant:RadToDeg * coord_body:angularvel.
  Local rotation_speed to angular_velocity_degrees:mag.
  If coord_body:north:vector * angular_velocity_degrees > 0 {
    Set rotation_speed to -rotation_speed.
  }.
  Local present_lng to future_lng - delta_t * rotation_speed.
  Until present_lng <= 180 {
    Set present_lng to present_lng - 360.
  }.
  Until present_lng > -180 {
    Set present_lng to present_lng + 360.
  }.
  Return coord_body:geoPositionLatLng(spot:lat, present_lng).
}.

Local function last_item {
  Parameter enum_collection.
  Local iter to enum_collection:reverseIterator.
  Iter:next().
  Return iter:value.
}.

Local future_position_vec to vecdraw().
Set future_position_vec:wiping to false.
Until not hasNode {
  Local node to last_item(allNodes).
  Local intended_time to node:eta + time:seconds.
  Local intended_orbit to node:orbit.
  Local intended_position to positionAt(ship, intended_time).
  Local future_coords to intended_orbit:body:geoPositionOf(intended_position).
  Local current_coords to geoCoordsAtTime(future_coords, intended_time).    
  Set future_position_vec:start to current_coords:altitudePosition(10_000).
  Set future_position_vec:vec to current_coords:position - future_position_vec:start.
  Set future_position_vec:show to true.
  Wait 0.
}.

Set future_position_vec:show to false.
