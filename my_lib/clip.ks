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

function clip_vector_euclidean {
  Parameter vec, maxnorm.
  If vec:mag <= maxnorm { Return vec. }.
  Return maxnorm * vec:normalized.
}.

function clip_to_cone {
  Parameter vec, cone_center, angular_radius.

  Local current_angle to vang(vec, cone_center).
  If current_angle <= angular_radius {
    Return vec.
  }.
  Local mag to vec:mag.
  Set vec to vxcl(cone_center, vec).

  Return mag * (cone_center:normalized + tan(angular_radius) * vec:normalized).
}.
