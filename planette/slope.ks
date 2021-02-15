@LAZYGLOBAL off.

// Run computation in triplicate and return the mean of the closest two results.
Local function redundant_computation {
  Parameter func.
  Local a1 to func().
  Local a2 to func().
  Local a3 to func().
  Local d12 to (a1 - a2):mag.
  Local d13 to (a1 - a3):mag.
  Local d23 to (a2 - a3):mag.
  Local b1 to a1.
  Local b2 to a2.
  If d13 > d12 and d13 > d23 {
    Set b2 to a3.
  } else if d23 > d12 and d23 > d13 {
    Set b1 to a3.
  }.
  Return (b1 + b2) / 2.
}.

// <DEBUG>
Local body_var to ship:body.
Local z_radius to (body_var:geopositionLatLng(90, 0):position - body_var:position):normalized.
Local x_radius to (body_var:geopositionLatLng(0, 0):position - body_var:position):normalized.
Local y_radius to (body_var:geopositionLatLng(0, 90):position - body_var:position):normalized.

Local function body_coords_to_ship_raw {
  Parameter body_coords.
  Local x_component to x_radius * body_coords:x.
  Local y_component to y_radius * body_coords:y.
  Local z_component to z_radius * body_coords:z.
  Return body_var:position + x_component + y_component + z_component.
}.

Global vecs_in_scope to list().
On round(time:seconds) {
  For vec in vecs_in_scope {
    Vec:show on.
  }.
  Return true.
}.

Local ten_extra_meters to (body_var:radius + 10) / body_var:radius.

// </DEBUG>

function body_coords_position {
  Parameter geo.
  Local lat to geo:lat.
  Local lng to geo:lng.
  Local rad to geo:body:radius + geo:terrainHeight.
  Return rad * V(cos(lng)*cos(lat), sin(lng)*cos(lat), sin(lat)).
}.

Local function slope_from_corners {
  Parameter ne, nw, se, sw.
  Set ne to body_coords_position(ne).
  Set nw to body_coords_position(nw).
  Set se to body_coords_position(se).
  Set sw to body_coords_position(sw).
  Local center_up to ((ne + nw + se + sw)/4):normalized.
  Local center_normal to vcrs((se - nw), (ne - sw)):normalized.
  // <DEBUG>
//  Local vec to vecdraw().
//  Set vec:start to body_coords_to_ship_raw((ne + nw + se + sw) / 4).
//  Set vec:vec to body_coords_to_ship_raw(ten_extra_meters * (ne + nw + se + sw) / 4) - vec:start.
//  Set vec:color to blue.
//  Set vec:show to true.
//  Vecs_in_scope:add(vec).
//  
//  Local vec2 to vecdraw().
//  Set vec2:start to vec:start.
//  Set vec2:vec to body_coords_to_ship_raw(10 * center_normal:normalized + (ne + nw + se + sw)/4) - vec2:start.
//  Set vec2:color to red.
//  Set vec2:show to true.
//  Vecs_in_scope:add(vec2).
  // </DEBUG>
  Local slope_direction to vxcl(center_up, center_normal).
  Return vang(center_up, center_normal).
}.

Local function shift_geo_by {
  Parameter geocoords.
  Parameter north.
  Parameter east.

  Local geo_body to geocoords:body.
  Local body_radius to geo_body:radius.

  Local delta_lat to (north / body_radius) * constant:radToDeg.
  Local cross_section_radius to cos(geocoords:lat) * body_radius.
  Local delta_lng to (east / cross_section_radius) * constant:radToDeg.

  Return geo_body:geopositionLatLng(geocoords:lat + delta_lat, geocoords:lng + delta_lng).
}.

Global function descent_heading {
  Parameter geocoords.
  Parameter radius to 30.

  Local ne to shift_geo_by(geocoords, radius, radius).
  Local se to shift_geo_by(geocoords, -radius, radius).
  Local sw to shift_geo_by(geocoords, -radius, -radius).
  Local nw to shift_geo_by(geocoords, radius, -radius).

  Print ne.
  Print se.
  Print nw.
  Print sw.


  Local ne_vec to body_coords_position(ne).
  Local nw_vec to body_coords_position(nw).
  Local se_vec to body_coords_position(se).
  Local sw_vec to body_coords_position(sw).
  Local center_normal to vcrs((se_vec - nw_vec), (ne_vec - sw_vec)):normalized.
  Local normal_dot_east to center_normal * (ne_vec:normalized - nw_vec:normalized + se_vec:normalized - sw_vec:normalized):normalized.
  Local normal_dot_north to center_normal * (ne_vec:normalized + nw_vec:normalized - se_vec:normalized - sw_vec:normalized):normalized. 
  Local retv to arctan2(normal_dot_east, normal_dot_north).
  // <DEBUG>
//  Local vec to vecdraw().
//  Set vec:start to body_coords_to_ship_raw((ne_vec + nw_vec + se_vec + sw_vec) / 4).
//  Set vec:vec to body_coords_to_ship_raw(ten_extra_meters * (ne_vec + nw_vec + se_vec + sw_vec) / 4) - vec:start.
//  Set vec:color to blue.
//  Set vec:show to true.
//
//  Local vec2 to vecdraw().
//  Set vec2:start to vec:start.
//  Set vec2:vec to body_coords_to_ship_raw(10 * center_normal:normalized + (ne_vec + nw_vec + se_vec + sw_vec)/4) - vec2:start.
//  Set vec2:color to red.
//  Set vec2:show to true.
//
//  Local vec3 to vecdraw().
//  Set vec3:start to vec:start + vec:vec.
//  Set vec3:vec to 10 * heading(retv, 0):vector.
//  Vec3:show on.
//
//  Local vec_square to vecdraw().
//  Set vec_square:start to body_coords_to_ship_raw(ne_vec).
//  Set vec_square:vec to body_coords_to_ship_raw(nw_vec) - vec_square:start.
//  Set vec_square:color to yellow.
//  Print vec_square:vec:mag.
//  Print vec_square:start * ship:up:vector.
//  Print (vec_square:vec + vec_square:start) * ship:up:vector.
//  Vec_square:show on.
  // </DEBUG>
  Return retv.
}.

Local function interp {
  Parameter a, b, t.
  Return (1 - t) * a + t * b.
}.

function matrix_surrounding_geoposition {
  Local parameter geocoords.
  Local parameter radius.
  Local parameter num_coords.

  Local local_north to redundant_computation({ Return
      (kerbin:geopositionLatLng(geocoords:lat + 0.1, geocoords:lng):altitudePosition(0)
       - kerbin:geopositionLatLng(geocoords:lat - 0.1, geocoords:lng):altitudePosition(0)
      ):normalized.
  }).
  Local local_east to redundant_computation({ Return
      (kerbin:geopositionLatLng(geocoords:lat, geocoords:lng + 0.1):altitudePosition(0)
       - kerbin:geopositionLatLng(geocoords:lat, geocoords:lng - 0.1):altitudePosition(0)
      ):normalized.
  }).

  Local matrix to list().
  Local geocoords_pos to geocoords:position.
  Local ne to kerbin:geopositionOf(geocoords_pos + radius * local_north + radius * local_east).
  Local sw to kerbin:geopositionOf(geocoords_pos - radius * local_north - radius * local_east).
  Local ne_lat to ne:lat.
  Local ne_lng to ne:lng.
  Local sw_lat to sw:lat.
  Local sw_lng to sw:lng.
  Until ne_lng > sw_lng {
    Set ne_lng to ne_lng + 360.
  }.

  For i in range(num_coords + 1) {
    Local current_row to list().
    For j in range(num_coords + 1) {
      Current_row:add(kerbin:geopositionLatLng(interp(ne_lat, sw_lat, i/num_coords), interp(ne_lng, sw_lng, j/num_coords))).
    }.
    Matrix:add(current_row).
  }.

//  From {Local delta_n to -radius.} until delta_n > radius step {Set delta_n to delta_n + 15.} do {
//    Local current_row to list().
//    From {local delta_e to -radius.} until delta_e > radius step {set delta_e to delta_e + 15.} do {
//      Current_row:add(kerbin:geopositionOf(geocoords_pos + delta_n * local_north + delta_e * local_east)).
//    }.
//    Matrix:add(current_row).
//  }.
  Return matrix.
}.

function slope_matrix {
  Parameter geocoord_matrix.
  Local slopes to list().

  From
    {
      Local i to 0.
      Local input_row to geocoord_matrix[0].
      Local next_input_row to geocoord_matrix[1]. 
    } until i + 1 = geocoord_matrix:length step {
      Set i to i + 1.
      If i + 1 < geocoord_matrix:length {
        Set input_row to next_input_row.
        Set next_input_row to geocoord_matrix[i + 1].
      }.
    } do
  {
    Local slopes_row to list().
    From {local j to 0.} until j = input_row:length - 1 step {set j to j + 1.} do {
      Local ne to next_input_row[j + 1].
      Local nw to next_input_row[j].
      Local se to input_row[j + 1].
      Local sw to input_row[j].
      Slopes_row:add(slope_from_corners(ne, nw, se, sw)).
    }.
    Slopes:add(slopes_row).
  }.
  Return slopes.
}.

Local function matrix_contract_max {
  // Contract the matrix, reducing the length and width by 1.
  Parameter matrix, maxi, maxj.
  Local retv to list().
  From {local i to 0.} until i > maxi-1 step {set i to i + 1.} do {
    Local row to list().
    From {local j to 0.} until j > maxj-1 step {set j to j + 1.} do {
      Local val to matrix[i][j].
      Set val to max(val, matrix[i][j+1]).
      Set val to max(val, matrix[i+1][j]).
      Set val to max(val, matrix[i+1][j+1]).
      Row:add(val).
    }.
    Retv:add(row).
  }.
  Return retv.
}.

Local function argmin_matrix {
  Parameter matrix, maxi, maxj.
  Local ret_i to 0.
  Local ret_j to 0.
  Local min_so_far to 1e30.  // since infinity would cause an error
  From {local i to 0.} until i > maxi step {set i to i + 1.} do {
    Local row to matrix[i].
    From {local j to 0.} until j > maxj step {set j to j + 1.} do {
      If row[j] < min_so_far {
        Set ret_i to i.
        Set ret_j to j.
        Set min_so_far to row[j].
      }.
    }.
  }.
  Return list(ret_i, ret_j, min_so_far).
}.

Global function flattest_location_near {
  Parameter center. 
  Local geocoord_matrix to matrix_surrounding_geoposition(center, 300, 10). 
  Local maxi to geocoord_matrix:length - 1.
  Local maxj to geocoord_matrix[0]:length - 1.
  Local slopes to slope_matrix(geocoord_matrix).
  Set maxi to maxi - 1.
  Set maxj to maxj - 1.
  Local slopes_contracted to matrix_contract_max(slopes, maxi, maxj).
  Set maxi to maxi - 1.
  Set maxj to maxj - 1.
  Local best_point to argmin_matrix(slopes_contracted, maxi, maxj).
  Local best_i to best_point[0] + 1.  // Add 1 because of the two contractions.
  Local best_j to best_point[1] + 1.  // Add 1 because of the two contractions.
  Local best_slope to best_point[2].
  Print "expected slope: " + best_slope.
  Print "checking: slopes computed near there: " + list(slopes[best_i][best_j], slopes[best_i][best_j - 1],
      slopes[best_i - 1][best_j - 1], slopes[best_i - 1][best_j]).
  Return geocoord_matrix[best_i][best_j].
}.
