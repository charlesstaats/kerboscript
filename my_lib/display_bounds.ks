// Copied from https://ksp-kos.github.io/KOS/tutorials/display_bounds.html#display-bounds

function vector_tostring_rounded {
  // Same thing that vector:tostring() normally
  // does, but with more rounding so the display
  // doesn't get so big:
  parameter vec.

  return "V(" +
    round(vec:x,2) + ", " +
    round(vec:y,2) + ", " +
    round(vec:z,2) + ")".
}

local arrows is LIST().
function draw_abs_to_box {
  // Draws the vectors from origin TO the 2 opposite corners of the box:

  parameter B.

  // Wipe any old arrow draws off the screen.
  for arrow in arrows { set arrow:show to false. }
  wait 0.

  arrows:CLEAR().
  arrows:ADD(Vecdraw(
    {return V(0,0,0).}, {return B:ABSMIN.}, RGB(1,0,0.75), "ABSMIN", 1, true)).
  arrows:ADD(Vecdraw(
    {return V(0,0,0).}, {return B:ABSMAX.}, RGB(1,0,0.75), "ABSMAX", 1, true)).
}

local edges is LIST().
function draw_box {
  // Draws a bounds box as a set of 12 non-pointy
  // vecdraws along the box edges:
  parameter B.

  // Wipe any old edge draws off the screen.
  for edge in edges { set edge:show to false. }
  wait 0.

  // These need to calculate using relative coords to find all the box edges:
  local rel_x_size is B:RELMAX:X - B:RELMIN:X.
  local rel_y_size is B:RELMAX:Y - B:RELMIN:Y.
  local rel_z_size is B:RELMAX:Z - B:RELMIN:Z.

  edges:CLEAR().

  // The 4 edges parallel to the relative X axis:
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMIN:X, B:RELMIN:Y, B:RELMIN:Z).},
    {return B:FACING * V(rel_x_size, 0, 0).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMIN:X, B:RELMIN:Y, B:RELMAX:Z).},
    {return B:FACING * V(rel_x_size, 0, 0).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMIN:X, B:RELMAX:Y, B:RELMAX:Z).},
    {return B:FACING * V(rel_x_size, 0, 0).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMIN:X, B:RELMAX:Y, B:RELMIN:Z).},
    {return B:FACING * V(rel_x_size, 0, 0).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).

  // The 4 edges parallel to the relative Y axis:
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMIN:X, B:RELMIN:Y, B:RELMIN:Z).},
    {return B:FACING * V(0, rel_y_size, 0).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMIN:X, B:RELMIN:Y, B:RELMAX:Z).},
    {return B:FACING * V(0, rel_y_size, 0).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMAX:X, B:RELMIN:Y, B:RELMAX:Z).},
    {return B:FACING * V(0, rel_y_size, 0).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMAX:X, B:RELMIN:Y, B:RELMIN:Z).},
    {return B:FACING * V(0, rel_y_size, 0).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).

  // The 4 edges parallel to the relative Z axis:
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMIN:X, B:RELMIN:Y, B:RELMIN:Z).},
    {return B:FACING * V(0, 0, rel_z_size).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMIN:X, B:RELMAX:Y, B:RELMIN:Z).},
    {return B:FACING * V(0, 0, rel_z_size).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMAX:X, B:RELMAX:Y, B:RELMIN:Z).},
    {return B:FACING * V(0, 0, rel_z_size).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).
  edges:ADD(Vecdraw(
    {return B:ABSORIGIN + B:FACING * V(B:RELMAX:X, B:RELMIN:Y, B:RELMIN:Z).},
    {return B:FACING * V(0, 0, rel_z_size).},
    RGBA(1,0,1,0.75), "", 1, true, 0.02, false, false)).
}
