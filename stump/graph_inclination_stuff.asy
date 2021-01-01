settings.outformat = "pdf";
size(200, 200, keepAspect=false);

import math;
import graph;

string filename = "inclination_log.csv";
file in = input(filename).line().csv();
string[] header;
real[][] data;
int time_index = 0, inclination_error_index = 1;
header = in;
data = in;
data = transpose(data);
data[time_index] -= data[time_index][0];


draw(graph(x=data[time_index], y=data[inclination_error_index]));
xaxis(ticks=Ticks);
yaxis(ticks=Ticks);
