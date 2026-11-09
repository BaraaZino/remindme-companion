package com.remindme.companion;

import java.util.*;

/** Pure reminder timing: daily at the deadline's local clock time, plus final offsets. */
public final class ReminderPlan {
  public static List<Long> times(long due, int days, List<Integer> offsets) {
    TreeSet<Long> result = new TreeSet<>();
    if (due <= 0) return new ArrayList<>();
    for (int day = 1; day <= Math.min(30, Math.max(0, days)); day++) {
      Calendar date = Calendar.getInstance();
      date.setTimeInMillis(due);
      date.add(Calendar.DAY_OF_YEAR, -day);
      result.add(date.getTimeInMillis());
    }
    for (int minutes : offsets)
      if (minutes >= 0 && minutes <= 43200) result.add(due - minutes * 60000L);
    result.add(due);
    return new ArrayList<>(result);
  }

  public static long next(long due, int days, List<Integer> offsets, long last, long from) {
    for (long time : times(due, days, offsets)) if (time > last && time >= from) return time;
    return Long.MAX_VALUE;
  }
}
