package com.remindme.companion;

import android.app.*;
import android.content.*;
import android.content.pm.*;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
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

  @Override
  public void configureFlutterEngine(FlutterEngine engine) {
    super.configureFlutterEngine(engine);
    ReminderReceiver.channels(this);
    new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "remindme/companion")
        .setMethodCallHandler(
            (call, result) -> {
              try {
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
                        task.put("due", t.due);
                        task.put("done", t.done);
                        task.put("reminded", t.reminded);
                        tasks.add(task);
                      }
                      state.put("tasks", tasks);
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
                      ArrayList<Store.Task> tasks = new ArrayList<>();
                      Map<String, Store.Task> current = new HashMap<>();
                      for (Store.Task existing : Store.tasks(this))
                        current.put(existing.id, existing);
                      for (Object item : (List<?>) state.get("tasks")) {
                        Map<?, ?> map = (Map<?, ?>) item;
                        Store.Task t =
                            new Store.Task(
                                (String) map.get("title"),
                                ((Number) map.get("due")).longValue(),
                                (String) map.get("list"));
                        t.id = (String) map.get("id");
                        t.done = Boolean.TRUE.equals(map.get("done"));
                        t.reminded = Boolean.TRUE.equals(map.get("reminded"));
                        Store.Task existing = current.get(t.id);
                        if (existing != null && existing.due == t.due && existing.done == t.done)
                          t.reminded |= existing.reminded;
                        tasks.add(t);
                      }
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
                      Store.save(this, tasks);
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
                    if (!CompanionService.running) {
                      result.error("paused", "Wake Mochi first, then try a reminder.", null);
                      break;
                    }
                    startService(new Intent(this, CompanionService.class).setAction("PREVIEW"));
                    result.success(null);
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
