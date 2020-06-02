@LAZYGLOBAL OFF.

RunOncePath("0:/my_lib/exponential_moving_avg").

Local my_avg to exponential_moving_avg:new(0.2).

Local prev_print_time to round(time:seconds).
Until false {
  Local avg to my_avg:update(time:seconds, 1.0).
  Local current_time to round(time:seconds).
  If (current_time <> prev_print_time) {
    Print avg.
    Set prev_print_time to current_time.
  }.
  Wait 0.
}
