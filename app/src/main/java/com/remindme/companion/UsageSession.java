package com.remindme.companion;

import java.util.Set;

/** Counts only time spent in chosen apps; brief activity transitions do not split a session. */
public final class UsageSession {
  private String current = "";
  private long cursor, pausedAt;
  private long elapsed;

  public UsageSession(long start) {
    cursor = start;
  }

  public long elapsed() {
    return elapsed;
  }

  public void reset(long now) {
    current = "";
    cursor = now;
    pausedAt = 0;
    elapsed = 0;
  }

  public void advance(long time, Set<String> watched) {
    long at = Math.max(cursor, time);
    if (watched.contains(current)) elapsed += at - cursor;
    else if (!current.isEmpty() || (pausedAt > 0 && at - pausedAt > 1500)) elapsed = 0;
    cursor = at;
  }

  public void resume(String name, long time, Set<String> watched) {
    advance(time, watched);
    current = name;
    pausedAt = 0;
    if (!watched.contains(name)) elapsed = 0;
  }

  public void pause(String name, long time, Set<String> watched) {
    advance(time, watched);
    if (current.equals(name)) {
      current = "";
      pausedAt = cursor;
    }
  }
}
