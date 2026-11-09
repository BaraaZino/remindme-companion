package com.remindme.companion;

import android.Manifest;
import android.content.*;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.provider.CalendarContract;
import java.util.*;

/** One-way links to events created by this app; never imports or edits unrelated events. */
public final class CalendarSync {
  public static boolean allowed(Context c) {
    return c.checkSelfPermission(Manifest.permission.READ_CALENDAR)
            == PackageManager.PERMISSION_GRANTED
        && c.checkSelfPermission(Manifest.permission.WRITE_CALENDAR)
            == PackageManager.PERMISSION_GRANTED;
  }

  public static List<Map<String, Object>> calendars(Context c) {
    if (!allowed(c)) throw new SecurityException("Allow calendar access first.");
    List<Map<String, Object>> result = new ArrayList<>();
    try (Cursor rows =
        c.getContentResolver()
            .query(
                CalendarContract.Calendars.CONTENT_URI,
                new String[] {"_id", "calendar_displayName", "account_name"},
                "calendar_access_level >= ? AND sync_events = 1",
                new String[] {Integer.toString(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR)},
                "calendar_displayName ASC")) {
      while (rows != null && rows.moveToNext()) {
        Map<String, Object> item = new HashMap<>();
        item.put("id", rows.getLong(0));
        item.put("name", rows.getString(1));
        item.put("account", rows.getString(2));
        result.add(item);
      }
    }
    return result;
  }

  static void writable(Context c, long id) {
    if (!allowed(c))
      throw new SecurityException("Calendar permission is off. Reconnect your calendar.");
    for (Map<String, Object> item : calendars(c))
      if (((Number) item.get("id")).longValue() == id) return;
    throw new IllegalStateException(
        "This calendar is unavailable or read-only. Choose another calendar.");
  }

  public static void sync(Context c, Store.Task task) {
    if (task.calendarId == 0 || task.due <= 0) {
      try {
        remove(c, task);
        task.calendarError = "";
      } catch (RuntimeException e) {
        task.calendarError = e.getMessage();
      }
      return;
    }
    try {
      writable(c, task.calendarId);
      ContentValues values = new ContentValues();
      values.put(CalendarContract.Events.CALENDAR_ID, task.calendarId);
      values.put(CalendarContract.Events.TITLE, (task.done ? "✓ " : "") + task.title);
      values.put(
          CalendarContract.Events.DESCRIPTION,
          "RemindMe task\nGroup: "
              + task.list
              + "\nReminders are managed by RemindMe.\nRemindMe ID: "
              + task.id);
      values.put(CalendarContract.Events.DTSTART, task.due);
      values.put(CalendarContract.Events.DTEND, task.due + 15 * 60000L);
      values.put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().getID());
      values.put(CalendarContract.Events.AVAILABILITY, CalendarContract.Events.AVAILABILITY_FREE);
      values.put(CalendarContract.Events.HAS_ALARM, 0);
      ContentResolver resolver = c.getContentResolver();
      int updated =
          task.calendarEventId == 0
              ? 0
              : resolver.update(
                  ContentUris.withAppendedId(
                      CalendarContract.Events.CONTENT_URI, task.calendarEventId),
                  values,
                  CalendarContract.Events.DELETED + " = 0",
                  null);
      if (updated == 0) {
        Uri created = resolver.insert(CalendarContract.Events.CONTENT_URI, values);
        if (created == null)
          throw new IllegalStateException("The calendar could not save this event.");
        task.calendarEventId = ContentUris.parseId(created);
      }
      task.calendarError = "";
    } catch (RuntimeException e) {
      task.calendarError =
          e.getMessage() == null
              ? "Calendar update failed. Save the task to retry."
              : e.getMessage();
    }
  }

  public static void remove(Context c, Store.Task task) {
    if (task.calendarEventId == 0) return;
    if (!allowed(c))
      throw new SecurityException("Allow calendar access to remove the linked event.");
    c.getContentResolver()
        .delete(
            ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, task.calendarEventId),
            null,
            null);
    task.calendarEventId = 0;
  }
}
