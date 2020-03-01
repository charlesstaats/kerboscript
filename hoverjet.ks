//set period to 20.0.
//set scalar to 0.1.
SET pid1 TO PIDLOOP(1.0, 0.1, 0.0, 0.0, 1.0).
SET pid2 TO PIDLOOP(1.0, 0.0, 10.0, 0.0, 1.0).
LOCK THROTTLE TO 0.8 * pid1:UPDATE(TIME:SECONDS, ALT:RADAR - 50.0) 
  + 0.2 * pid2:update(time:seconds, ship:verticalspeed).
WAIT 100.
PRINT "Descending.".
pid1:RESET().
pid2:RESET().
LOCK THROTTLE TO 0.1 * pid1:UPDATE(TIME:SECONDS, alt:radar - 2.0)
  + 0.9 * pid2:update(time:seconds, SHIP:VERTICALSPEED + 2.0).
when Ship:VerticalSpeed < -1.0 then lock Steering to Ship:SrfRetrograde.
Wait Until Alt:Radar < 4.0.
