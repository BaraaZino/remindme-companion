package com.remindme.companion;

import android.content.*;
import java.util.*;
import org.json.*;

public final class Store {
  public static android.content.SharedPreferences prefs(Context c) {
    return c.getSharedPreferences("companion", 0);
  }

  public static class Task {
    public String id = UUID.randomUUID().toString(), title, list = "Personal";
    public String companionId = "mochi";
    public long due, lastReminderAt, reminderFrom, snoozeUntil, calendarId, calendarEventId;
    public int dailyDays;
    public List<Integer> reminderOffsets = new ArrayList<>();
    public String calendarError = "";

    public long nextReminder() {
      if (done) return Long.MAX_VALUE;
      long next =
          ReminderPlan.next(
              due,
              dailyDays,
              reminderOffsets,
              Math.max(lastReminderAt, reminded ? due : 0),
              reminderFrom);
      return snoozeUntil > 0 ? Math.min(next, snoozeUntil) : next;
    }

    public boolean done, reminded;

    public Task(String t, long d, String l) {
      title = t;
      due = d;
      list = l;
    }

    JSONObject json() throws JSONException {
      return new JSONObject()
          .put("id", id)
          .put("title", title)
          .put("list", list)
          .put("companionId", companionId)
          .put("due", due)
          .put("done", done)
          .put("reminded", reminded)
          .put("dailyDays", dailyDays)
          .put("reminderOffsets", new JSONArray(reminderOffsets))
          .put("lastReminderAt", lastReminderAt)
          .put("reminderFrom", reminderFrom)
          .put("snoozeUntil", snoozeUntil)
          .put("calendarId", calendarId)
          .put("calendarEventId", calendarEventId)
          .put("calendarError", calendarError);
    }
  }

  public static synchronized ArrayList<Task> tasks(Context c) {
    ArrayList<Task> out = new ArrayList<>();
    try {
      JSONArray a = new JSONArray(prefs(c).getString("tasks", "[]"));
      for (int i = 0; i < a.length(); i++) {
        JSONObject o = a.getJSONObject(i);
        Task t = new Task(o.getString("title"), o.optLong("due"), o.optString("list", "Personal"));
        t.id = o.getString("id");
        t.companionId = o.optString("companionId", "mochi");
        t.done = o.optBoolean("done");
        t.reminded = o.optBoolean("reminded");
        t.dailyDays = Math.max(0, Math.min(30, o.optInt("dailyDays")));
        JSONArray offsets = o.optJSONArray("reminderOffsets");
        if (offsets != null)
          for (int j = 0; j < offsets.length(); j++) {
            int minutes = offsets.optInt(j, -1);
            if (minutes >= 0 && minutes <= 43200) t.reminderOffsets.add(minutes);
          }
        t.lastReminderAt = o.optLong("lastReminderAt");
        t.reminderFrom = o.optLong("reminderFrom");
        t.snoozeUntil = o.optLong("snoozeUntil");
        t.calendarId = o.optLong("calendarId");
        t.calendarEventId = o.optLong("calendarEventId");
        t.calendarError = o.optString("calendarError", "");
        out.add(t);
      }
    } catch (JSONException ignored) {
    }
    return out;
  }

  public static synchronized void save(Context c, List<Task> tasks) {
    JSONArray a = new JSONArray();
    try {
      for (Task t : tasks) a.put(t.json());
    } catch (JSONException e) {
      throw new IllegalStateException(e);
    }
    prefs(c).edit().putString("tasks", a.toString()).apply();
    ReminderReceiver.schedule(c);
    TaskWidgetProvider.refresh(c);
  }

  public static synchronized void complete(Context c, String id) {
    setCompleted(c, id, true);
  }

  public static synchronized void remove(Context c, String id) {
    ArrayList<Task> a = tasks(c);
    for (Task t : a) if (t.id.equals(id)) CalendarSync.remove(c, t);
    a.removeIf(t -> t.id.equals(id));
    save(c, a);
    c.getSystemService(android.app.NotificationManager.class).cancel(id.hashCode());
  }

  public static synchronized void setCompleted(Context c, String id, boolean done) {
    ArrayList<Task> a = tasks(c);
    for (Task t : a)
      if (t.id.equals(id)) {
        t.done = done;
        t.snoozeUntil = 0;
        if (!done) {
          t.reminded = false;
          t.reminderFrom = System.currentTimeMillis();
        }
        CalendarSync.sync(c, t);
      }
    save(c, a);
    if (done) c.getSystemService(android.app.NotificationManager.class).cancel(id.hashCode());
  }

  public static synchronized void upsert(Context c, Task task) {
    if (!PetProfile.exists(c, task.companionId)) task.companionId = PetProfile.defaultId(c);
    ArrayList<Task> a = tasks(c);
    boolean found = false;
    for (Task existing : a)
      if (existing.id.equals(task.id)) {
        found = true;
        task.done = existing.done;
        task.calendarEventId = existing.calendarEventId;
        if (task.due == existing.due
            && task.dailyDays == existing.dailyDays
            && task.reminderOffsets.equals(existing.reminderOffsets)) {
          task.reminded |= existing.reminded;
          task.lastReminderAt = existing.lastReminderAt;
          task.reminderFrom = existing.reminderFrom;
          task.snoozeUntil = existing.snoozeUntil;
        } else {
          task.reminded = false;
          task.lastReminderAt = 0;
          task.reminderFrom = System.currentTimeMillis();
          task.snoozeUntil = 0;
        }
        if (task.calendarId != existing.calendarId) {
          if (task.calendarId != 0 && task.due > 0) CalendarSync.writable(c, task.calendarId);
          CalendarSync.remove(c, existing);
          task.calendarEventId = 0;
        }
      }
    if (!found) task.reminderFrom = System.currentTimeMillis();
    CalendarSync.sync(c, task);
    a.removeIf(t -> t.id.equals(task.id));
    a.add(task);
    save(c, a);
  }

  public static synchronized void snooze(Context c, String id) {
    ArrayList<Task> a = tasks(c);
    for (Task t : a)
      if (t.id.equals(id)) {
        t.snoozeUntil = System.currentTimeMillis() + 10 * 60_000;
      }
    save(c, a);
  }

  public static synchronized Task claimDue(Context c) {
    ArrayList<Task> a = tasks(c);
    Task match = null;
    long now = System.currentTimeMillis();
    for (Task t : a)
      if (t.nextReminder() <= now && (match == null || t.nextReminder() < match.nextReminder()))
        match = t;
    if (match != null) {
      match.lastReminderAt = now;
      match.snoozeUntil = 0;
      match.reminded = match.due <= now;
      save(c, a);
    }
    return match;
  }
}
