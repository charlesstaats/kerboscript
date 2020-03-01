settings.outformat = "png";
unitsize(1cm);
import graph;

real a = 5;
real b = -7;

real v0squared(real theta) {
  return -(1/2) * 9.81 * a^2 / (b * cos(theta) - a * sin(theta) * cos(theta));
}

draw(graph(v0squared, 0, pi / 3));
real b4a = b / (4a);
real proposed_theta = asin(b4a + sqrt(1/2 + b4a^2));
dot((proposed_theta, v0squared(proposed_theta)));
