@LAZYGLOBAL off.

Local function slope_from_corners {
  Parameter ne, nw, se, sw.
  Local center_up to ((ne + nw + se + sw)/4 - kerbin:position):normalized.
  Return vang(center_up, vcrs((ne -sw), (se - nw))).
}.

Local function matrix_surrounding_geoposition {
  Local parameter geocoords.

  Local local_north to
      (kerbin:geopositionLatLng(geocoords:lat + 0.1, geocoords:lng):altitudePosition(0)
       - kerbin:geopositionLatLng(geocoords:lat - 0.1, geocoords:lng):altitudePosition(0)
      ):normalized.
  Local local_east to
      (kerbin:geopositionLatLng(geocoords:lat, geocoords:lng + 0.1):altitudePosition(0)
       - kerbin:geopositionLatLng(geocoords:lat, geocoords:lng - 0.1):altitudePosition(0)
      ):normalized.

  Local matrix to list().
  Local geocoords_pos to geocoords:position.

  From {Local delta_n to -100.} until delta_n > 100 step {Set delta_n to delta_n + 10.} do {
    Local current_row to list().
    From {local delta_e to -100.} until delta_e > 100 step {set delta_e to delta_e + 10.} do {
      Current_row:add(kerbin:geopositionOf(geocoords_pos + delta_n * local_north + delta_e * local_east)).
    }.
    Matrix:add(current_row).
  }.
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
    } until i = geocoord_matrix:length - 1 step {
      Set i to i + 1.
      If i + 1 < geocoord_matrix:length {
        Set input_row to next_input_row.
        Set next_input_row to geocoord_matrix[i + 1].
      }.
    } do
  {
    Local slopes_row to list().
    From {local j to 0.} until j = input_row:length - 1 step {set j to j + 1.} do {
      Local ne to next_input_row[j + 1]:position.
      Local nw to next_input_row[j]:position.
      Local se to input_row[j + 1]:position.
      Local sw to input_row[j]:position.
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
  Local slopes to matrix_contract_max(slopes, maxi, maxj).
  Set maxi to maxi - 1.
  Set maxj to maxj - 1.
  Local best_point to argmin_matrix(slopes, maxi, maxj).
  Local best_i to best_point[0] + 1.  // Add 1 because of the two contractions.
  Local best_j to best_point[1] + 1.  // Add 1 because of the two contractions.
  Local best_slope to best_point[2].
  Print "expected slope: " + best_slope.
  Return geocoord_matrix[best_i][best_j].
}.
