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
    public long due;
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
          .put("reminded", reminded);
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
    a.removeIf(t -> t.id.equals(id));
    save(c, a);
    c.getSystemService(android.app.NotificationManager.class).cancel(id.hashCode());
  }

  public static synchronized void setCompleted(Context c, String id, boolean done) {
    ArrayList<Task> a = tasks(c);
    for (Task t : a)
      if (t.id.equals(id)) {
        t.done = done;
        if (!done) t.reminded = false;
      }
    save(c, a);
    if (done) c.getSystemService(android.app.NotificationManager.class).cancel(id.hashCode());
  }

  public static synchronized void upsert(Context c, Task task) {
    if (!PetProfile.exists(c, task.companionId)) task.companionId = PetProfile.defaultId(c);
    ArrayList<Task> a = tasks(c);
    for (Task existing : a)
      if (existing.id.equals(task.id)) {
        task.done = existing.done;
        if (task.due == existing.due) task.reminded |= existing.reminded;
      }
    a.removeIf(t -> t.id.equals(task.id));
    a.add(task);
    save(c, a);
  }

  public static synchronized void snooze(Context c, String id) {
    ArrayList<Task> a = tasks(c);
    for (Task t : a)
      if (t.id.equals(id)) {
        t.due = System.currentTimeMillis() + 10 * 60_000;
        t.reminded = false;
      }
    save(c, a);
  }

  public static synchronized Task claimDue(Context c) {
    ArrayList<Task> a = tasks(c);
    Task match = null;
    long now = System.currentTimeMillis();
    for (Task t : a)
      if (!t.done
          && !t.reminded
          && t.due > 0
          && t.due <= now
          && (match == null || t.due < match.due)) match = t;
    if (match != null) {
      match.reminded = true;
      save(c, a);
    }
    return match;
  }
}
