@LAZYGLOBAL OFF.

Parameter SHRINK.

RunOncePath("0:/KSLib/library/lib_navigation.ks").
Runoncepath("0:/my_lib/basic_control_flow").
RunOncePath("0:/my_lib/clip").
RunOncePath("0:/my_lib/controller").
RunOncePath("0:/my_lib/fake_rcs").


Local rotation_kp to 1.0.
Local rotation_kd to rotation_kp * 4.0.
Local zero_vec to V(0,0,0).
Local control to ship:control.

Local APSIS to choose ship:orbit:periapsis if SHRINK else ship:orbit:apoapsis.

Local function other_apsis {
  Return choose ship:orbit:apoapsis if SHRINK else ship:orbit:periapsis.
}.

Local function eta_near_apsis {
  Return choose eta:periapsis if SHRINK else eta:apoapsis.
}.

Local function eta_other_apsis {
  Return choose eta:apoapsis if SHRINK else eta:periapsis.
}.

Local function reference_frame_angular_velocity {
  Return vcrs(ship:velocity:orbit, body:position) / body:position:sqrmagnitude.
}.

Local function gravitational_acceleration {
  Return body:position:normalized * body:mu / body:position:sqrmagnitude.
}.

Local function srfprograde_angular_velocity {
  Return vcrs(ship:velocity:surface, gravitational_acceleration()) / ship:velocity:surface:sqrmagnitude
    + reference_frame_angular_velocity().
}.

Local function prograde_angular_velocity {
  Return vcrs(ship:velocity:orbit, gravitational_acceleration()) / ship:velocity:orbit:sqrmagnitude.
}.

Local function steer_before_node {
  If not hasNode { Return false. }.
  SAS off.
  Local target_direction to nextNode:burnvector.
  Local factor to choose 1.0 if RCS else (1 / (1e-3 + control:pilotmainthrottle)).
  Set control:rotation to
       factor * direction_rotation_controller(
          target_direction,
          zero_vec,
          zero_vec,
          rotation_kp,
          rotation_kd).
  Return control:pilotmainthrottle < 0.01.
}.

Local function adjusted_eta {
  Parameter raw_eta_seconds.
  Local period_var to ship:orbit:period.
  If raw_eta_seconds > period_var / 2 {
    Return raw_eta_seconds - period_var.
  }.
  Return raw_eta_seconds.
}.


Local pid_eta_near_apsis to pf_controller(0.4, 6).
Local max_attitude_adjustment to 10.
If SHRINK {
  Set pid_eta_near_apsis:setpoint to -1.
  Set max_attitude_adjustment to 80.
}.
Local function steer_after_node {
  Local apsis_eta to adjusted_eta(eta_near_apsis()).
  Local attitude_adjustment to pid_eta_near_apsis:update(time:seconds, apsis_eta).
  Set attitude_adjustment to clip(attitude_adjustment, -max_attitude_adjustment, max_attitude_adjustment).
  //If SHRINK { Set attitude_adjustment to -attitude_adjustment. }.
  Local desired_direction to vxcl(ship:up:vector, nextNode:burnVector).
  Set desired_direction to
      angleAxis(attitude_adjustment, vcrs(ship:prograde:vector, ship:up:vector)) * desired_direction.
  Local factor to choose 1.0 if RCS else (1 / (1e-3 + control:pilotmainthrottle)).
  Set control:rotation to factor * direction_rotation_controller(
      desired_direction,
      zero_vec,
      prograde_angular_velocity(),
      rotation_kp,
      rotation_kd).
  Return abs(apsis_eta) < 5 * 60.
}.

Local body_radius to body:radius.
Local surface_gravity to body:mu / body_radius^2.
Local function potential {
  Parameter alt_meters to ship:altitude.
  Return surface_gravity * body_radius * (1 - body_radius / (alt_meters + body_radius)).
}.
Local function specific_energy {
  Parameter speed to ship:velocity:orbit:mag.
  Parameter alt_meters to ship:altitude.
  Local kinetic to speed * speed / 2.
  Return kinetic + potential(alt_meters).
}.
Local function speed_at_altitude {
  Parameter desired_altitude.
  Parameter current_speed to ship:velocity:orbit:mag.
  Parameter current_altitude to ship:altitude.
  Local invariant_specific_energy to specific_energy(current_speed, current_altitude).
  Local desired_potential to potential(desired_altitude).
  Local desired_kinetic to invariant_specific_energy - desired_potential.
  Return sqrt(2 * desired_kinetic).
}.
Local function orbital_velocity_at_altitude {
  Parameter desired_altitude.
  Return sqrt(body:mu / (body_radius + desired_altitude)).
}.


Local burn_time to 0.

Local node_main_sequence to list(
  {
    Set control:pilotmainthrottle to 0.
    RCS off.  // Turn off RCS to ensure we can correctly compute specific impulse, hence burn time.
    For mastadon_engine in ship:partsdubbedpattern("KE-1") {
      Mastadon_engine:activate().
      Set mastadon_engine:thrustlimit to 100.
    }.
  },
  {
    Local delta_v to orbital_velocity_at_altitude(APSIS) - speed_at_altitude(APSIS).
    Local circularization_node to  node(time:seconds + eta_near_apsis(), 0, 0, delta_v).
    Add circularization_node.
    Set burn_time to getBurnTime(abs(delta_v)).
    If burn_time < 10 {
      For mastadon_engine in ship:partsdubbedpattern("KE-1") {
        Set mastadon_engine:thrustlimit to 100 * burn_time / 10.
      }.
      Set burn_time to getBurnTime(abs(delta_v)).
    }.
    Print burn_time.
    RCS on.
  },
  Control_flow:fork("steering",  list(steer_before_node@, steer_after_node@)),
  {
    Return nextNode:eta > burn_time / 2.
  },
  {
    Print "throttling up".
    RCS off.
    Set control:pilotmainthrottle to 1.0.
  },
  {
    Return abs(other_apsis() - APSIS) > 10_000.
  },
  {
    Set control:pilotmainthrottle to 0.1.
  },
  {
    Return abs(adjusted_eta(eta_near_apsis())) < 5 * 60.
  },
  Control_flow:merge("steering"),
  {
    Set control:pilotmainthrottle to 0.0.
    Remove allNodes[0].
  }
).

Local cf to control_flow:new().

Cf:background:register_and_enqueue_seq("rcs", list(
  {
    FakeRCS:find_engines().
    FakeRCS:refresh_control().
    FakeRCS:adjust().
  },
  {
    FakeRCS:adjust().
    Return true.
  })
).

Cf:register_and_enqueue_seq("node_and_throttle", node_main_sequence).

Until not cf:active() {
  Cf:run_pass().
  Wait 0.
}.
Control:neutralize on.
Wait 0.
HUDText("Program finished; returning control.", 5, 2, 15, green, true).
