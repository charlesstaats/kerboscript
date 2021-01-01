@LAZYGLOBAL OFF.

function clip {
  Parameter t, low is -1.0, high is 1.0.
 
  Return min(high, max(low, t)).
}

function clip_vector_by_scalars {
  Parameter vec, low, high.
  Return V(
           clip(vec:x, low, high),
           clip(vec:y, low, high),
           clip(vec:z, low, high)
          ).
}.

