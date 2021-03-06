@LAZYGLOBAL OFF.

Global lib_smoothing to lex().

Set lib_smoothing["exponential_moving_avg"] to {
  Parameter PERSISTENCE to 1.0.

  Local retv to lex().
  
  Local avg to 0.0.
  Local prev_time to -1.
  Local prev_value to 0.

  Set retv["update"] to {
    Parameter time_secs.
    Parameter value.

    If prev_time < 0 {
      Set avg to value.
      Set prev_time to time_secs.
      Set prev_value to value.
      Return avg.
    }.
    Local duration to time_secs - prev_time.
    Local change_avg_toward to (prev_value + value) / 2.
    If duration <= 0 {
      Set prev_value to change_avg_toward.
      Return avg.
    }.
    Set avg to (PERSISTENCE * avg + duration * change_avg_toward) / (PERSISTENCE + duration).
    Set prev_value to value.
    Set prev_time to time_secs.
    Return avg.
  }.

  Set retv["get"] to {
    Return avg.
  }.

  Set retv["reset"] to {
    Parameter new_avg.
    Parameter new_persistence to PERSISTENCE.
    Set avg to new_avg.
    Set PERSISTENCE to new_persistence.
    Set prev_time to -1.
    Set prev_value to new_avg.
  }.

  Set retv["prev_time"] to { Return prev_time. }.

  Return retv.

}.

Set lib_smoothing["rate_limited"] to {
  Parameter position.
  Parameter default_rate is 1.0.

  Local mag to choose { Parameter v. Return v:mag. } if position:hassuffix("mag") else { Parameter v. Return abs(v). }.
  Local retv to lex().
  
  Local prev_time to -1.
  
  Set retv["update"] to {
    Parameter time_secs.
    Parameter value.
    Parameter max_rate is 0.0.

    If max_rate <= 0 { Set max_rate to default_rate. }.

    Local duration to time_secs - prev_time.
    If prev_time < 0 or duration <= 0 {
      Set prev_time to time_secs.
      Return position.
    }.
    Set prev_time to time_secs.
    Local delta to value - position.
    Local abs_delta to mag(delta).
    Local allowed_abs_change to max_rate * duration.
    If abs_delta > allowed_abs_change {
      Set delta to delta * (allowed_abs_change / abs_delta).
    }
    Set position to position + delta.
    Return position.
  }.

  Set retv["get"] to {
    Return position.
  }.

  Set retv["reset"] to {
    Parameter starting_position.
    Set position to starting_position.
    Set prev_time to -1.
  }.

  Return retv.
}.

Set lib_smoothing["compose"] to {
  Parameter outer, inner.

  Local retv to lex().
  Set retv["update"] to {
    Parameter time_secs.
    Parameter val.

    Local mid to inner:update(time_secs, val).
    Return outer:update(time_secs, mid).
  }.
  Return retv.
}.
