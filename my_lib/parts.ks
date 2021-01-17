@LazyGlobal off.

Global function all_parts_with_root {
  Parameter root_part.
  Local descendants to list(root_part).
  Local children to root_part:children.
  For child_part in children {
    For greatchild_part in all_parts_with_root(child_part) {
      Descendants:add(greatchild_part).
    }.
  }.
  Return descendants.
}.

//Local all_parts to all_parts_with_root(ship:rootPart).
//Print "number of parts counted: " + all_parts:length.
//Print "true number of parts: " + ship:parts:length.

Global function dry_mass_with_root {
  Parameter root_part.
  Local total_dry_mass to root_part:dryMass.
  Local children to root_part:children.
  For child_part in children {
    Set total_dry_mass to total_dry_mass + dry_mass_with_root(child_part).
  }.
  Return total_dry_mass.
}.

Global function mass_with_root {
  Parameter root_part.
  Local total_mass to root_part:mass.
  Local children to root_part:children.
  For child_part in children {
    Set total_mass to total_mass + mass_with_root(child_part).
  }.
  Return total_mass.
}.
