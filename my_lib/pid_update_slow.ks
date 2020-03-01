@LAZYGLOBAL OFF.

Runpath("0:/my_lib/clip").

Global function slow_updater {
  Parameter pid.
  Parameter update_rate.
  Parameter min_value.
  Parameter max_value.
  Parameter initial_value is 0.

  Local prev_output is initial_value.
  Local prev_dOdt is 0.
  Return {
    Parameter input.

    Local current_time is time:seconds.
    Local prev_time is pid:lastsampletime.
    If prev_time = 0 { Set prev_time to current_time. }.
    If prev_time = current_time { Return prev_output. }.
    Local interval is current_time - prev_time.
    Local prev_dOdt is pid:output.
    Local dOdt is pid:update(current_time, input).
    Local retv is clip((prev_dOdt + dOdt) * 0.5 * interval + prev_output, min_value, max_value).
    Set prev_output to retv.
    Return retv.
  }.
}
