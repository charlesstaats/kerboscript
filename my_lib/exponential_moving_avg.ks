@LAZYGLOBAL OFF.

Global exponential_moving_avg to lex().

Set exponential_moving_avg["new"] to {
  Parameter DECAY_RATE to 1.0.

  Local PERSISTENCE to 1.0 / DECAY_RATE.
  Local retv to lex().
  
  Local avg to 0.0.
  Local prev_time to -1.
  Local prev_value to 0.

  Set retv["update"] to {
    Parameter time_secs.
    Parameter value.

    Local duration to time_secs - prev_time.
    Local change_avg_toward to (prev_value + value) / 2.
    If duration <= 0 {
      Set prev_value to change_avg_toward.
      Return avg.
    }
    Set avg to (PERSISTENCE * avg + duration * change_avg_toward) / (PERSISTENCE + duration).
    Set prev_value to value.
    Set prev_time to time_secs.
    Return avg.
  }.

  Set retv["get"] to {
    Return avg.
  }.

  Return retv.
}.
