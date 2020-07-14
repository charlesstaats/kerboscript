@LAZYGLOBAL OFF.

// "proportional-future controller"
Global function pf_controller {
  Parameter proportional.
  Parameter future_secs. // how many secs in the future based on linear projection
  Parameter min_out is "".
  Parameter max_out is 0.
  If min_out:isType("scalar") {
    Return pidloop(proportional, 0, proportional * future_secs, min_out, max_out).
  } else {
    Return pidloop(proportional, 0, proportional * future_secs).
  }.
}

