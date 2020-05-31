settings.outformat = "html";

import three;
import graph3;


real k = 1000;
real v_planet = 9285;  // orbital velocity of kerbin
real v_ship_factor = 1.2;  // initial ship speed is v_planet * v_ship_factor
real r_p_min = 670k;  // 670 km, the radius of kerbin including its atmosphere
real r_p_max = 3000k;  // 3000 km, no particular significance
real mu = 3.5316000e12;  // standard gravitational parameter of kerbin
usersetting();  // Allow user to override the above parameters. (More precisely, run code set by the "user" flag.)

pair delta_v_inf(pair v_incoming, real r_p, real mu, bool deflect_clockwise = false) {
  real v_inf = abs(v_incoming);
  real a = -mu / v_inf^2;  // negative distance from periapsis to the point where the two intercepts cross. "semi-major axis"
  real r_p_over_a = abs(r_p) / a;
  real b_over_a = -sqrt(r_p_over_a * (r_p_over_a - 2));  // b is the impact parameter, a.k.a. the "semi-minor axis"
  real deflection_angle = pi + 2 * atan(b_over_a);
  if (deflect_clockwise) deflection_angle = -deflection_angle;
  pair incoming_dir = dir(v_incoming);
  pair outgoing_dir = expi(deflection_angle) * incoming_dir;
  pair delta_v = v_inf * (outgoing_dir - incoming_dir);
  return delta_v;
}

real delta_abs_v(pair v_ship, pair v_planet, real r_p, real mu, bool deflect_clockwise = false) {
  pair delta_v = delta_v_inf(v_ship - v_planet, r_p, mu, deflect_clockwise);
  pair v_final = v_ship + delta_v;
  return abs(v_final) - abs(v_ship);
}

real max_delta_abs_v = -infinity;
real min_delta_abs_v = infinity;
real delta_abs_v(real r_p, real planet_dir_degrees, bool deflect_clockwise = false) {
  real retv = delta_abs_v(v_ship = (0, v_planet * v_ship_factor),
                     v_planet = v_planet * dir(planet_dir_degrees),
                     r_p = r_p,
                     mu = mu,
                     deflect_clockwise = deflect_clockwise);
  if (retv > max_delta_abs_v) max_delta_abs_v = retv;
  if (retv < min_delta_abs_v) min_delta_abs_v = retv;
  return retv;
}

real min_x = infinity;
real max_x = -infinity;

//triple f(pair w) {
//  real theta = w.y;
//  real r = 2 * r_p_max + w.x;
//  real x = r * Cos(theta);
//  real y = r * Sin(theta);
//
//  real r_p = abs(w.x);
//  bool right_hemi = (Cos(theta) >= 0);
//  bool inner_annulus = (w.x <= 0);
//  bool deflect_clockwise = (right_hemi == inner_annulus);
//  real z = delta_abs_v(r_p, theta, deflect_clockwise);
//  min_x = min(min_x, x);
//  max_x = max(max_x, x);
//  return (x, y, z);
//}

real graph_radius = v_planet * v_ship_factor;

typedef triple func(pair);
func make_f(bool deflect_clockwise) {
  return new triple(pair w) {
    real theta = w.y;
    real r_p = w.x;

    real delta_abs_v = delta_abs_v(r_p, theta, deflect_clockwise);

    real r = graph_radius + delta_abs_v;
    real z = 1e-3 * r_p;
    real x = r * Cos(theta);
    real y = r * Sin(theta);
    return (x, y, z);
  };
}

func f_ccw = make_f(false);
func f_clockwise = make_f(true);

//triple f_ccw(pair w) {
//  real theta = w.y;
//  real r_p = w.x;
//
//  real delta_abs_v = delta_abs_v(r_p, theta, deflect_clockwise=false);
//
//  real r = graph_radius + delta_abs_v;
//  real z = 1e-3 * r_p;
//  real x = r * Cos(theta);
//  real y = r * Sin(theta);
//  return (x, y, z);
//}
//

size(10cm, 10cm);
currentprojection = orthographic((1, 1, 0.0002), up=Z);
material surfacepen = material(diffusepen=gray(0.6),
                               emissivepen=gray(0.3),
			       specularpen=gray(0.1));
//surface inner = surface(f, a=(-r_p_max, 0), b=(-r_p_min, 360), nu=32, Spline);
//surface outer = surface(f, a=(r_p_min, 0), b=(r_p_max, 360), nu=32, Spline);
//surface whole_graph = surface(inner, outer);
surface ccw = surface(f_ccw, a=(r_p_min, 0), b=(r_p_max, 360), nu=32, Spline);
surface clockwise = surface(f_clockwise, a=(r_p_min, 0), b=(r_p_max, 360), nu=32, Spline);
surface whole_graph = surface(ccw, shift(0, 0, 1e-3 * r_p_max) * clockwise);

triple graph_size = max(whole_graph) - min(whole_graph);
triple scale_params = (5 / graph_radius, 5 / graph_radius, 1 / graph_size.z);
transform3 scaling = scale(scale_params.x, scale_params.y, scale_params.z);
transform3 unscaling = scale(1 / scale_params.x, 1 / scale_params.y, 1 / scale_params.z);
whole_graph = scaling * whole_graph;

draw(whole_graph, surfacepen=surfacepen);

real axis_z = interp(min(whole_graph).z, max(whole_graph).z, -0.2);
path3 axis = shift(axis_z * Z) * scale(5, 5, 1) * unitcircle3;
draw(axis);

draw(shift(axis_z * Z) * scale(5, 5, 2) * unitcylinder, surfacepen = emissive(blue + opacity(0.1)));

path3 arrowpath = scale(5, 5, 1) * scale3(0.1) * (O -- Y);
int n = 12;
for (int i = 0; i < n; ++i) {
  triple current_position = relpoint(axis, i / n);
  draw(shift(current_position) * arrowpath, arrow=Arrow3);
}
draw((0, 0, -2) -- (0, 0, 3), p=invisible);
