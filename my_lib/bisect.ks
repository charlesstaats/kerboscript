@LAZYGLOBAL OFF.

// Finds the greatest lower bound of the parameter within the range.
// Returns start - 1 if no item within the range is a lower bound on the item.
Local function _index_of_leq {
  Parameter item, sorted_list, start, end.
  
  If sorted_list[end] <= item {
    Return end.
  }
  If item < sorted_list[start] {
    Return start - 1.
  }
  If end - start <= 1 {  // base case
    Return start.  // We already know end is not a lower bound but start is.
  }

  Local mid is round((end + start) / 2).
  If sorted_list[mid] <= item {
    Return _index_of_leq(item, sorted_list, mid, end).
  } else {
    Return _index_of_leq(item, sorted_list, start, mid).
  }  
}

Function index_of_leq {
  Parameter item, sorted_list.
  Return _index_of_leq(item, sorted_list, 0, sorted_list:length - 1).
}

Function interpolate {
  Parameter xval, sorted_x, ylist.
  If sorted_x:length <> ylist:length { Print 0 / 0. }.
  Local max_index is sorted_x:length - 1.
  Local index0 is index_of_leq(xval, sorted_x).
  If index0 < 0 { Return ylist[0]. }.
  If index0 = sorted_x:length - 1 { Return ylist[max_index]. }.
  Local index1 is index0 + 1.
  Local frac is (xval - sorted_x[index0]) / (sorted_x[index1] - sorted_x[index0]).
  Return ylist[index0] + frac * (ylist[index1] - ylist[index0]).
}
