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

Local function body_coords_position {
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
  Return vang(center_up, vcrs((se - nw), (ne - sw))).
}.

Local function interp {
  Parameter a, b, t.
  Return (1 - t) * a + t * b.
}.

Local function matrix_surrounding_geoposition {
  Local parameter geocoords.

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
  Local ne to kerbin:geopositionOf(geocoords_pos + 300 * local_north + 300 * local_east).
  Local sw to kerbin:geopositionOf(geocoords_pos - 300 * local_north - 300 * local_east).
  Local ne_lat to ne:lat.
  Local ne_lng to ne:lng.
  Local sw_lat to sw:lat.
  Local sw_lng to sw:lng.
  Until ne_lng > sw_lng {
    Set ne_lng to ne_lng + 360.
  }.

  Local n to 100.
  For i in range(n + 1) {
    Local current_row to list().
    For j in range(n + 1) {
      Current_row:add(kerbin:geopositionLatLng(interp(ne_lat, sw_lat, i/n), interp(ne_lng, sw_lng, j/n))).
    }.
    Matrix:add(current_row).
  }.

//  From {Local delta_n to -300.} until delta_n > 300 step {Set delta_n to delta_n + 15.} do {
//    Local current_row to list().
//    From {local delta_e to -300.} until delta_e > 300 step {set delta_e to delta_e + 15.} do {
//      Current_row:add(kerbin:geopositionOf(geocoords_pos + delta_n * local_north + delta_e * local_east)).
//    }.
//    Matrix:add(current_row).
//  }.
  Return matrix.
}.

Local function slope_matrix {
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
  Local geocoord_matrix to matrix_surrounding_geoposition(center). 
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
  Print "checking: slopes computed near there: " + list(slopes[best_i][best_j], slopes[best_i][best_j + 1],
      slopes[best_i + 1][best_j + 1], slopes[best_i + 1][best_j]).
  Return geocoord_matrix[best_i][best_j].
}.
