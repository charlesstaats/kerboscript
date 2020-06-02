@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/lib_smoothing").

Local time_rounded to round(time:seconds).

//Local exp_moving_avg to lib_smoothing:exponential_moving_avg(2.0).
//Exp_moving_avg:update(time:seconds, V(0, 0, 0)).
//Wait 0.
//
//When true then {
//  Exp_moving_avg:update(time:seconds, V(0, -1, 2)).
//  If time_rounded <> round(time:seconds) {
//    Print exp_moving_avg:get().
//    Set time_rounded to round(time:seconds).
//  }.
//  Return true.
//}.
//

Local rate_limited to lib_smoothing:rate_limited(V(-1,2,7), 1.2).
When true then {
  Rate_limited:update(time:seconds, V(10, 10, 0)).
  If time_rounded <> round(time:seconds) {
    Print rate_limited:get().
    Set time_rounded to round(time:seconds).
  }.

  Return true.
}

Wait until false.
