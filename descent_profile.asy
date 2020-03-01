settings.outformat = "pdf";
size(200, 200, keepAspect=false);

import math;
import graph;

string filename = "descent_log.csv";
file in = input(filename).line().csv();
string[] header;
real[][] data;
int time_index = 0, alt_index = 1, phase_index = 2, airspeed_index = 3;
header = in;
data = in;

// Make the "phase angle" bit continuous
real small_angle(real a, real b) {
  return log(dir(b) / dir(a)).y * 180 / pi;
}
real prev_angle = nan;
for (real[] datapoint : data) {
  if (!isnan(prev_angle)) {
    datapoint[phase_index] = prev_angle + small_angle(prev_angle, datapoint[phase_index]); 
  }
  prev_angle = datapoint[phase_index];
}

real end_phase = data[data.length - 1][phase_index];

for (real[] datapoint: data) {
  datapoint[phase_index] -= end_phase;
}

real KERBIN_RADIUS = 600 * 1000;
real G_STD = 9.80665;

int ergy_index = 4;

// Energy_over_mass vs altitude
for (real[] datapoint : data) {
  real altitude = datapoint[alt_index];
  real speed = datapoint[airspeed_index];
  real kinetic = speed * speed / 2;
  real potential = G_STD * KERBIN_RADIUS * (1 - KERBIN_RADIUS / (altitude + KERBIN_RADIUS));
  real energy_over_mass = kinetic + potential;
  datapoint.push(energy_over_mass);
}

file outfile = output('descent_profile_light.csv');
write(outfile, "time,altitude,phase,airspeed,ergy", suffix=endl);
for (real[] datapoint : data) {
  for (int i = 0; i < datapoint.length; ++i) {
    write(outfile, datapoint[i], suffix=(i + 1 == datapoint.length ? endl : comma));
  }
}

close(outfile);

//// Want: leastsquares approximations for altitude vs phase_angle and ergy vs phase_angle.
//// "Solve" (approximate) Ax = b, where A is matrix of values of the basis functions (like
//// Vandermonde) and b is the desired value.
//
//int num_atan_basis_vecs = 16;
//
//real basisvec(int i, real t) {
//  if (i == 0) return 1;
//  return atan(t / i);
//}
//
//real[][] A;
//real[] b;
//for (real[] datapoint : data) {
//  real input = datapoint[phase_index];
//  real output = datapoint[ergy_index];
//
//  b.push(output);
//  real[] coeffs;
//  for (int i = 0; i < num_atan_basis_vecs; ++i) {
//    coeffs.push(basisvec(i, input));
//  }
//  A.push(coeffs);
//}
//
//real[] ergy_coeffs = leastsquares(A, b);
//real estimated_ergy(real phase_angle) {
//  real retv = 0;
//  for (int i = 0; i < num_atan_basis_vecs; ++i) {
//    retv += ergy_coeffs[i] * basisvec(i, phase_angle);
//  }
//  return retv;
//} 
//
//real[] x;
//real[] y;
//real[] y_approx;
//for (int i = 0; i < data.length; ++i) {
//  real phase_angle = data[i][phase_index];
//  x.push(phase_angle);
//  y.push(data[i][ergy_index]);
//  y_approx.push(estimated_ergy(phase_angle));
//}
//
//draw(graph(x, y), black);
//draw(graph(x, y_approx), blue);
