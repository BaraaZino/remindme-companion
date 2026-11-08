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
    out.put("running", CompanionService.running);
    out.put("overlay", Settings.canDrawOverlays(this));
    out.put("usage", hasUsage(this));
    out.put("notifications", getSystemService(NotificationManager.class).areNotificationsEnabled());
    return out;
  }

  private android.content.SharedPreferences.OnSharedPreferenceChangeListener taskListener;
  private VoiceCapture voices;

  @Override
  protected void onActivityResult(int request, int result, Intent data) {
    super.onActivityResult(request, result, data);
    if (voices != null) voices.activityResult(request, result, data);
  }

  @Override
  public void onRequestPermissionsResult(int request, String[] permissions, int[] grants) {
    super.onRequestPermissionsResult(request, permissions, grants);
    if (voices != null) voices.permissionResult(request, grants);
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
    for (Store.Task t : Store.tasks(this)) {
      Map<String, Object> map = new HashMap<>();
      map.put("id", t.id);
      map.put("title", t.title);
      map.put("list", t.list);
      map.put("companionId", t.companionId);
      map.put("due", t.due);
      map.put("done", t.done);
      map.put("reminded", t.reminded);
      tasks.add(map);
    }
    return tasks;
  }

  @Override
  public void onDestroy() {
    if (taskListener != null)
      Store.prefs(this).unregisterOnSharedPreferenceChangeListener(taskListener);
    if (voices != null) voices.dispose();
    super.onDestroy();
  }

  @Override
  public void configureFlutterEngine(FlutterEngine engine) {
    super.configureFlutterEngine(engine);
    ReminderReceiver.channels(this);
    voices = new VoiceCapture(this);
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
                      List<Map<String, Object>> tasks = new ArrayList<>();
                      for (Store.Task t : Store.tasks(this)) {
                        Map<String, Object> task = new HashMap<>();
                        task.put("id", t.id);
                        task.put("title", t.title);
                        task.put("list", t.list);
                        task.put("companionId", t.companionId);
                        task.put("due", t.due);
                        task.put("done", t.done);
                        task.put("reminded", t.reminded);
                        tasks.add(task);
                      }
                      state.put("tasks", tasks);
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
                  case "overlayPermission":
                    startActivity(
                        new Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
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
                    if (!Settings.canDrawOverlays(this)) {
                      result.error(
                          "overlay",
                          "Allow the floating pet first, then return and tap Wake Mochi.",
                          null);
                      break;
                    }
                    startForegroundService(new Intent(this, CompanionService.class));
                    new Handler(getMainLooper()).postDelayed(() -> result.success(null), 300);
                    break;
                  case "stop":
                    stopService(new Intent(this, CompanionService.class));
                    new Handler(getMainLooper()).postDelayed(() -> result.success(null), 200);
                    break;
                  case "preview":
                    {
                      if (!Settings.canDrawOverlays(this)) {
                        result.error(
                            "overlay",
                            "Allow the floating-pet permission in Companions first, then try the"
                                + " visit again.",
                            null);
                        break;
                      }
                      Intent preview =
                          new Intent(this, CompanionService.class).setAction("PREVIEW");
                      if (call.arguments instanceof Map) {
                        Map<?, ?> args = (Map<?, ?>) call.arguments;
                        if (args.get("profile") instanceof Map)
                          preview.putExtra(
                              "profile",
                              new JSONObject((Map<?, ?>) args.get("profile")).toString());
                        preview.putExtra("kind", (String) args.get("kind"));
                        preview.putExtra("text", (String) args.get("text"));
                      }
                      startForegroundService(preview);
                      new Handler(getMainLooper()).postDelayed(() -> result.success(null), 250);
                      break;
                    }
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
