package com.remindme.companion;

/** Pure movement state machine: enter, stop and speak, then continue off screen. */
public final class VisitMotion {
  public enum Phase {
    IDLE,
    ENTERING,
    TALKING,
    EXITING
  }

  public Phase phase = Phase.IDLE;
  public double x;
  public boolean fromLeft;
  private double width, petWidth, target, speed;
  private long last, talkStarted, hold;

  public void start(
      double width,
      double petWidth,
      double target,
      boolean left,
      double speed,
      long holdMillis,
      long now) {
    this.width = width;
    this.petWidth = petWidth;
    this.target = target;
    fromLeft = left;
    this.speed = speed;
    hold = holdMillis;
    last = now;
    x = left ? -petWidth : width;
    phase = Phase.ENTERING;
  }

  public void tick(long now, boolean audioFinished) {
    double step = Math.max(0, now - last) / 1000.0 * speed;
    last = now;
    int direction = fromLeft ? 1 : -1;
    if (phase == Phase.ENTERING) {
      x += direction * step;
      if ((fromLeft && x >= target) || (!fromLeft && x <= target)) {
        x = target;
        phase = Phase.TALKING;
        talkStarted = now;
      }
    } else if (phase == Phase.TALKING) {
      if (now - talkStarted >= hold && audioFinished) phase = Phase.EXITING;
    } else if (phase == Phase.EXITING) {
      x += direction * step;
      if ((fromLeft && x >= width) || (!fromLeft && x + petWidth <= 0)) phase = Phase.IDLE;
    }
  }

  public void exit() {
    if (phase != Phase.IDLE) phase = Phase.EXITING;
  }

  public void cancel() {
    phase = Phase.IDLE;
  }
}
