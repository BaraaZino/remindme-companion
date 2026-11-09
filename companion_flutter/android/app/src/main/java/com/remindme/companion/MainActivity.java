package com.remindme.companion;

import android.app.*;
import android.appwidget.AppWidgetManager;
import android.content.*;
import android.content.pm.*;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import java.util.*;
import org.json.*;

/** The Flutter interface shares the original Android task store and pet service. */
public class MainActivity extends FlutterActivity {
  public static boolean hasUsage(Context c) {
    AppOpsManager a = c.getSystemService(AppOpsManager.class);
    return a.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), c.getPackageName())
        == AppOpsManager.MODE_ALLOWED;
  }

  Map<String, Object> permissions() {
    Map<String, Object> out = new HashMap<>();
    out.put("running", Store.prefs(this).getBoolean("visitsEnabled", false));
    out.put(
        "exact",
        Build.VERSION.SDK_INT < 31
            || getSystemService(AlarmManager.class).canScheduleExactAlarms());
    out.put("usage", hasUsage(this));
    out.put("notifications", getSystemService(NotificationManager.class).areNotificationsEnabled());
    return out;
  }

  @Override
  protected void onResume() {
    super.onResume();
    ReminderReceiver.schedule(this);
    if (Store.prefs(this).getBoolean("visitsEnabled", false) && !CompanionService.running)
      startForegroundService(new Intent(this, CompanionService.class));
  }

  private android.content.SharedPreferences.OnSharedPreferenceChangeListener taskListener;
  private VoiceCapture voices;
  private InAppSpeech speech;
  private BroadcastReceiver visitReceiver;
  private MethodChannel.Result calendarPermission;

  @Override
  protected void onPause() {
    if (voices != null) voices.stopPlayer();
    if (speech != null) speech.stop();
    super.onPause();
  }

  @Override
  protected void onActivityResult(int request, int result, Intent data) {
    super.onActivityResult(request, result, data);
    if (voices != null) voices.activityResult(request, result, data);
  }

  @Override
  public void onRequestPermissionsResult(int request, String[] permissions, int[] grants) {
    super.onRequestPermissionsResult(request, permissions, grants);
    if (voices != null) voices.permissionResult(request, grants);
    if (request == 710 && calendarPermission != null) {
      MethodChannel.Result pending = calendarPermission;
      calendarPermission = null;
      pending.success(CalendarSync.allowed(this));
    }
  }

  @Override
  protected void onStop() {
    if (voices != null) {
      voices.finish();
      voices.stopPlayer();
    }
    super.onStop();
  }

  private List<Map<String, Object>> taskSnapshot() {
    List<Map<String, Object>> tasks = new ArrayList<>();
    for (Store.Task task : Store.tasks(this)) {
      try {
        tasks.add((Map<String, Object>) PetProfile.decode(task.json()));
      } catch (JSONException e) {
        throw new IllegalStateException(e);
      }
    }
    return tasks;
  }

  @Override
  public void onDestroy() {
    if (taskListener != null)
      Store.prefs(this).unregisterOnSharedPreferenceChangeListener(taskListener);
    if (voices != null) voices.dispose();
    if (speech != null) speech.dispose();
    if (visitReceiver != null) unregisterReceiver(visitReceiver);
    if (calendarPermission != null) {
      calendarPermission.success(false);
      calendarPermission = null;
    }
    super.onDestroy();
  }

  @Override
  public void configureFlutterEngine(FlutterEngine engine) {
    super.configureFlutterEngine(engine);
    ReminderReceiver.channels(this);
    voices = new VoiceCapture(this);
    speech = new InAppSpeech(this);
    new EventChannel(engine.getDartExecutor().getBinaryMessenger(), "remindme/visits")
        .setStreamHandler(
            new EventChannel.StreamHandler() {
              public void onListen(Object args, EventChannel.EventSink sink) {
                if (visitReceiver != null) unregisterReceiver(visitReceiver);
                visitReceiver =
                    new BroadcastReceiver() {
                      public void onReceive(Context c, Intent i) {
                        Map<String, Object> event = new HashMap<>();
                        String taskId = i.getStringExtra("id");
                        if (taskId != null) {
                          for (Store.Task task : Store.tasks(c))
                            if (task.id.equals(taskId) && !task.done) {
                              event.put("taskId", task.id);
                              event.put("petId", task.companionId);
                              event.put("kind", "task");
                              event.put("text", "A little reminder: " + task.title);
                            }
                        } else {
                          event.put("petId", i.getStringExtra("petId"));
                          event.put("kind", "timer");
                          event.put("text", i.getStringExtra("text"));
                        }
                        if (!event.isEmpty()) sink.success(event);
                      }
                    };
                IntentFilter filter = new IntentFilter("com.remindme.companion.DUE");
                filter.addAction("com.remindme.companion.VISIT");
                if (Build.VERSION.SDK_INT >= 33)
                  registerReceiver(visitReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
                else registerReceiver(visitReceiver, filter);
              }

              public void onCancel(Object args) {
                if (visitReceiver != null) unregisterReceiver(visitReceiver);
                visitReceiver = null;
              }
            });
    new EventChannel(engine.getDartExecutor().getBinaryMessenger(), "remindme/tasks")
        .setStreamHandler(
            new EventChannel.StreamHandler() {
              public void onListen(Object args, EventChannel.EventSink sink) {
                if (taskListener != null)
                  Store.prefs(MainActivity.this)
                      .unregisterOnSharedPreferenceChangeListener(taskListener);
                taskListener =
                    (prefs, key) -> {
                      if ("tasks".equals(key)) sink.success(taskSnapshot());
                    };
                Store.prefs(MainActivity.this)
                    .registerOnSharedPreferenceChangeListener(taskListener);
              }

              public void onCancel(Object args) {
                if (taskListener != null)
                  Store.prefs(MainActivity.this)
                      .unregisterOnSharedPreferenceChangeListener(taskListener);
                taskListener = null;
              }
            });
    new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "remindme/companion")
        .setMethodCallHandler(
            (call, result) -> {
              try {
                if (voices.handle(call.method, call.arguments, result)) return;
                switch (call.method) {
                  case "permissions":
                    result.success(permissions());
                    break;
                  case "loadState":
                    {
                      Map<String, Object> state = permissions();
                      state.put("tasks", taskSnapshot());
                      state.put("companions", PetProfile.decode(PetProfile.companions(this)));
                      state.put("defaultCompanion", PetProfile.defaultId(this));
                      state.put("timers", PetProfile.decode(PetProfile.timerJson(this)));
                      state.put("nudges", Store.prefs(this).getBoolean("nudges", false));
                      state.put("speech", Store.prefs(this).getBoolean("speech", false));
                      state.put("minutes", Store.prefs(this).getInt("minutes", 20));
                      state.put(
                          "watched",
                          new ArrayList<>(
                              Store.prefs(this).getStringSet("watched", Collections.emptySet())));
                      result.success(state);
                      break;
                    }
                  case "saveState":
                    {
                      Map<?, ?> state = (Map<?, ?>) call.arguments;
                      HashSet<String> watched = new HashSet<>();
                      for (Object name : (List<?>) state.get("watched")) watched.add((String) name);
                      Store.prefs(this)
                          .edit()
                          .putBoolean("nudges", Boolean.TRUE.equals(state.get("nudges")))
                          .putBoolean("speech", Boolean.TRUE.equals(state.get("speech")))
                          .putInt(
                              "minutes",
                              Math.max(
                                  5, Math.min(120, ((Number) state.get("minutes")).intValue())))
                          .putStringSet("watched", watched)
                          .apply();
                      if (state.containsKey("companions")) {
                        JSONArray profiles = new JSONArray((List<?>) state.get("companions"));
                        if (profiles.length() == 0)
                          throw new IllegalArgumentException("Keep at least one companion.");
                        String selected = (String) state.get("defaultCompanion");
                        Store.prefs(this)
                            .edit()
                            .putString("companions", profiles.toString())
                            .putString("defaultCompanion", selected)
                            .putString(
                                "timers", new JSONArray((List<?>) state.get("timers")).toString())
                            .apply();
                        ArrayList<Store.Task> existing = Store.tasks(this);
                        boolean changed = false;
                        for (Store.Task t : existing)
                          if (!PetProfile.exists(this, t.companionId)) {
                            t.companionId = PetProfile.defaultId(this);
                            changed = true;
                          }
                        if (changed) Store.save(this, existing);
                        else TaskWidgetProvider.refresh(this);
                      }
                      result.success(null);
                      break;
                    }
                  case "upsertTask":
                    {
                      Map<?, ?> map = (Map<?, ?>) call.arguments;
                      Store.Task t =
                          new Store.Task(
                              (String) map.get("title"),
                              ((Number) map.get("due")).longValue(),
                              (String) map.get("list"));
                      t.id = (String) map.get("id");
                      t.companionId =
                          map.containsKey("companionId")
                              ? (String) map.get("companionId")
                              : PetProfile.defaultId(this);
                      t.reminded = Boolean.TRUE.equals(map.get("reminded"));
                      if (map.get("dailyDays") instanceof Number)
                        t.dailyDays =
                            Math.max(0, Math.min(30, ((Number) map.get("dailyDays")).intValue()));
                      if (map.get("calendarId") instanceof Number)
                        t.calendarId = ((Number) map.get("calendarId")).longValue();
                      if (map.get("reminderOffsets") instanceof List)
                        for (Object offset : (List<?>) map.get("reminderOffsets")) {
                          int value = ((Number) offset).intValue();
                          if (value >= 0 && value <= 43200) t.reminderOffsets.add(value);
                        }
                      Store.upsert(this, t);
                      result.success(taskSnapshot());
                      break;
                    }
                  case "completeTask":
                    {
                      Map<?, ?> map = (Map<?, ?>) call.arguments;
                      Store.setCompleted(
                          this, (String) map.get("id"), Boolean.TRUE.equals(map.get("done")));
                      result.success(taskSnapshot());
                      break;
                    }
                  case "deleteTask":
                    {
                      Store.remove(this, (String) call.arguments);
                      result.success(taskSnapshot());
                      break;
                    }
                  case "pinWidget":
                    {
                      AppWidgetManager widgets = AppWidgetManager.getInstance(this);
                      if (!widgets.isRequestPinAppWidgetSupported()) {
                        result.error(
                            "widget",
                            "Long-press an empty space on your home screen, choose Widgets, and"
                                + " find RemindMe tasks.",
                            null);
                        break;
                      }
                      widgets.requestPinAppWidget(
                          new ComponentName(this, TaskWidgetProvider.class), null, null);
                      result.success(null);
                      break;
                    }
                  case "exactPermission":
                    if (Build.VERSION.SDK_INT >= 31)
                      startActivity(
                          new Intent(
                              Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                              Uri.parse("package:" + getPackageName())));
                    result.success(null);
                    break;
                  case "usagePermission":
                    startActivity(new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS));
                    result.success(null);
                    break;
                  case "notificationPermission":
                    if (Build.VERSION.SDK_INT >= 33
                        && checkSelfPermission("android.permission.POST_NOTIFICATIONS")
                            != PackageManager.PERMISSION_GRANTED)
                      requestPermissions(new String[] {"android.permission.POST_NOTIFICATIONS"}, 1);
                    else
                      startActivity(
                          new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                              .putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName()));
                    result.success(null);
                    break;
                  case "start":
                    Store.prefs(this).edit().putBoolean("visitsEnabled", true).apply();
                    startForegroundService(new Intent(this, CompanionService.class));
                    result.success(null);
                    break;
                  case "stop":
                    Store.prefs(this).edit().putBoolean("visitsEnabled", false).apply();
                    stopService(new Intent(this, CompanionService.class));
                    if (speech != null) speech.stop();
                    result.success(null);
                    break;
                  case "say":
                    speech.say((Map<?, ?>) call.arguments, result);
                    break;
                  case "stopSpeech":
                    speech.stop();
                    result.success(null);
                    break;
                  case "snoozeTask":
                    Store.snooze(this, (String) call.arguments);
                    result.success(taskSnapshot());
                    break;
                  case "calendarPermission":
                    if (CalendarSync.allowed(this)) result.success(true);
                    else if (calendarPermission != null)
                      result.error("busy", "Calendar permission is already being requested.", null);
                    else {
                      calendarPermission = result;
                      requestPermissions(
                          new String[] {
                            android.Manifest.permission.READ_CALENDAR,
                            android.Manifest.permission.WRITE_CALENDAR
                          },
                          710);
                    }
                    break;
                  case "calendars":
                    result.success(CalendarSync.calendars(this));
                    break;
                  case "apps":
                    {
                      List<ResolveInfo> found =
                          getPackageManager()
                              .queryIntentActivities(
                                  new Intent(Intent.ACTION_MAIN)
                                      .addCategory(Intent.CATEGORY_LAUNCHER),
                                  0);
                      TreeMap<String, Map<String, String>> apps = new TreeMap<>();
                      for (ResolveInfo r : found)
                        if (!r.activityInfo.packageName.equals(getPackageName())) {
                          Map<String, String> app = new HashMap<>();
                          String name = r.loadLabel(getPackageManager()).toString();
                          app.put("name", name);
                          app.put("package", r.activityInfo.packageName);
                          apps.put(name + "\n" + r.activityInfo.packageName, app);
                        }
                      result.success(new ArrayList<>(apps.values()));
                      break;
                    }
                  default:
                    result.notImplemented();
                }
              } catch (Exception e) {
                result.error("android", "Could not complete this action: " + e.getMessage(), null);
              }
            });
  }
}
