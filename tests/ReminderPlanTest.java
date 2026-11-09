import com.remindme.companion.ReminderPlan;
import java.util.*;

public final class ReminderPlanTest {
  static void check(boolean condition, String message) {
    if (!condition) throw new AssertionError(message);
  }

  static long at(int month, int day, int hour) {
    Calendar c = Calendar.getInstance();
    c.clear();
    c.set(2026, month - 1, day, hour, 0);
    return c.getTimeInMillis();
  }

  public static void main(String[] args) {
    TimeZone original = TimeZone.getDefault();
    try {
      TimeZone.setDefault(TimeZone.getTimeZone("UTC"));
      long due = at(11, 20, 18);
      List<Integer> offsets = Arrays.asList(180, 60, 60, 0);
      List<Long> times = ReminderPlan.times(due, 3, offsets);
      check(times.size() == 6, "Three daily, two final, one deadline; duplicates removed");
      check(times.get(0) == due - 3 * 86400000L, "Starts three days before");
      check(times.get(3) == due - 3 * 3600000L, "Three hour reminder");
      check(times.get(4) == due - 3600000L, "One hour reminder");
      check(times.get(5) == due, "Always includes deadline");
      check(
          ReminderPlan.next(due, 3, offsets, times.get(0), 0) == times.get(1),
          "Does not repeat delivered reminder");
      check(
          ReminderPlan.next(due, 3, offsets, 0, due - 7200000L) == due - 3600000L,
          "New plans skip past slots");
      check(ReminderPlan.next(due, 3, offsets, due, 0) == Long.MAX_VALUE, "Finished plan stops");
      check(
          ReminderPlan.times(due, 0, Collections.emptyList()).equals(Arrays.asList(due)),
          "Legacy deadline reminder preserved");
      check(ReminderPlan.times(0, 3, offsets).isEmpty(), "Undated tasks have no reminders");
      TimeZone.setDefault(TimeZone.getTimeZone("America/New_York"));
      due = at(11, 2, 10);
      times = ReminderPlan.times(due, 3, Collections.emptyList());
      for (long time : times) {
        Calendar c = Calendar.getInstance();
        c.setTimeInMillis(time);
        check(
            c.get(Calendar.HOUR_OF_DAY) == 10, "Daily clock time survives daylight-saving changes");
      }
      check(
          times.get(2) - times.get(1) == 25 * 3600000L,
          "Uses local calendar days, not fixed 24-hour subtraction");
      System.out.println(
          "Passed daily/final reminders, deduplication, migration, no replay, and DST checks.");
    } finally {
      TimeZone.setDefault(original);
    }
  }
}
