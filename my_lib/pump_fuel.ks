@LAZYGLOBAL OFF.

Runpath("0:/KSLib/library/lib_enum").

Function parts_with_resources {
  Parameter resource_name_list.  // strings
  
  Local parts_list is list().
  List parts in parts_list.

  Return Enum:select(parts_list, {
    Parameter part.
    Local retv is Enum:all(resource_name_list, {
      Parameter resource_name.
      Return Enum:any(part:resources, {
        Parameter part_resource.
        Return part_resource:name = resource_name.
      }).
    }).
    Return retv.
  }).
}

Function rocket_fuel_tanks {
  Return parts_with_resources(list("liquidfuel", "oxidizer")).
}

Function tank_empty {
  Parameter tank.

  Return Enum:all(tank:resources, {
    Parameter resource.
    If resource:amount > 0.001 and (resource:name = "liquidfuel" or resource:name = "oxidizer") {
      Return false.
    }
    Return true.
  }).
}

Function all_fuel_to_tank {
  Parameter index.
  Parameter restrict_to_pattern is "".


  Local tanks is rocket_fuel_tanks().
  Set tanks to Enum:select(tanks, { Parameter part. Return part:name:matchespattern(restrict_to_pattern). }).
  If index < 0 { Set index to tanks:length + index. }
  Local recipient_tank is list(tanks[index]).
  Tanks:remove(index).
  Local retv is lexicon().
  Set retv["activate" ] to {
    Local transfer_fuel is transferall("liquidfuel", tanks, recipient_tank).
    Transfer_fuel:active on.
    Local transfer_oxy is transferall("oxidizer", tanks, recipient_tank).
    Transfer_oxy:active on.
  }.
  Set retv["done"] to {
    Return Enum:all(tanks, {
      Parameter tank.
      Return Enum:all(tank:resources, {
        Parameter resource.
        If resource:amount > 0.001 and (resource:name = "liquidfuel" or resource:name = "oxidizer") {
          Return false.
        }
        Return true.
      }).
    }) or Enum:all(recipient_tank[0]:resources, {
      Parameter resource.
      If resource:amount < resource:capacity - 0.001 and
          (resource:name = "liquidfuel" or resource:name = "oxidizer") {
        Return false.
      }
      Return true.
    }).
  }.
  Return retv.   

}

Function all_fuel_to_last_tank {
  Parameter restrict_to_pattern is "".
  
  Return all_fuel_to_tank(-1, restrict_to_pattern).
}

Function all_fuel_to_first_tank {
  Parameter restrict_to_pattern is "".

  Return all_fuel_to_tank(0, restrict_to_pattern).
}
//Local transfer_order is all_fuel_to_last_tank().
//Transfer_order:activate().
//Wait until transfer_order:done().
