Cd("0:/tailsitter").
If core:tag = "aim_up" {
  Runpath("aim_up").
} else if core:tag = "hover_throttle" {
  Runpath("hover_throttle").
}
