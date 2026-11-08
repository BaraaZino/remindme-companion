package com.remindme.companion;

import android.app.*;
import android.app.usage.*;
import android.content.*;
import android.content.pm.*;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import android.view.*;
import android.widget.*;
import java.text.DateFormat;
import java.util.*;

public class MainActivity extends Activity {
  final int BG = 0xFFF6F5EF, GREEN = 0xFF315D50, INK = 0xFF253D35, MUTED = 0xFF737D72;
  LinearLayout page, body;
  String tab = "Today";

  int dp(float n) {
    return (int) (n * getResources().getDisplayMetrics().density + .5f);
  }

  @Override
  public void onCreate(Bundle b) {
    super.onCreate(b);
    getWindow().setStatusBarColor(BG);
    ReminderReceiver.channels(this);
    if (Build.VERSION.SDK_INT >= 33
        && checkSelfPermission("android.permission.POST_NOTIFICATIONS")
            != PackageManager.PERMISSION_GRANTED)
      requestPermissions(new String[] {"android.permission.POST_NOTIFICATIONS"}, 1);
  }

  @Override
  public void onResume() {
    super.onResume();
    render();
  }

  TextView text(String s, int size, int color) {
    TextView v = new TextView(this);
    v.setText(s);
    v.setTextSize(size);
    v.setTextColor(color);
    v.setPadding(0, dp(4), 0, dp(4));
    return v;
  }

  GradientDrawable bg(int color, int radius) {
    GradientDrawable g = new GradientDrawable();
    g.setColor(color);
    g.setCornerRadius(dp(radius));
    return g;
  }

  LinearLayout col() {
    LinearLayout l = new LinearLayout(this);
    l.setOrientation(1);
    return l;
  }

  void space(LinearLayout l, int h) {
    Space s = new Space(this);
    l.addView(s, new LinearLayout.LayoutParams(1, dp(h)));
  }

  Button button(String label, Runnable run) {
    Button b = new Button(this);
    b.setText(label);
    b.setAllCaps(false);
    b.setTextColor(GREEN);
    b.setTextSize(14);
    b.setBackground(bg(0xFFE5EBDD, 16));
    b.setPadding(dp(14), dp(8), dp(14), dp(8));
    b.setOnClickListener(v -> run.run());
    return b;
  }

  LinearLayout card(LinearLayout parent, int color) {
    LinearLayout l = col();
    l.setPadding(dp(18), dp(16), dp(18), dp(16));
    l.setBackground(bg(color, 24));
    LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-1, -2);
    p.bottomMargin = dp(14);
    parent.addView(l, p);
    return l;
  }

  void render() {
    ScrollView scroll = new ScrollView(this);
    scroll.setFillViewport(true);
    scroll.setBackgroundColor(BG);
    page = col();
    page.setPadding(dp(22), dp(24), dp(22), dp(36));
    scroll.addView(page);
    setContentView(scroll);
    page.setOnApplyWindowInsetsListener(
        (v, insets) -> {
          v.setPadding(
              dp(22),
              dp(14) + insets.getSystemWindowInsetTop(),
              dp(22),
              dp(24) + insets.getSystemWindowInsetBottom());
          return insets;
        });
    page.requestApplyInsets();
    TextView brand = text("remindme  /  companion", 13, GREEN);
    brand.setLetterSpacing(.08f);
    page.addView(brand);
    space(page, 16);
    TextView title = text("A little company.\nA little more done.", 30, INK);
    title.setTypeface(null, Typeface.BOLD);
    page.addView(title);
    page.addView(text("Small steps, with Mochi by your side.", 15, MUTED));
    space(page, 20);
    LinearLayout hero = card(page, 0xFFDCE8D5);
    LinearLayout row = new LinearLayout(this);
    hero.addView(row);
    LinearLayout copy = col();
    row.addView(copy, new LinearLayout.LayoutParams(0, -2, 1));
    copy.addView(text("MEET YOUR COMPANION", 11, GREEN));
    TextView name = text("Mochi", 26, INK);
    name.setTypeface(null, 1);
    copy.addView(name);
    copy.addView(
        text(
            CompanionService.running ? "On a tiny adventure with you." : "Ready when you are.",
            13,
            GREEN));
    CatView cat = new CatView(this);
    row.addView(cat, new LinearLayout.LayoutParams(dp(96), dp(96)));
    space(hero, 12);
    hero.addView(
        button(
            CompanionService.running ? "Pause companion" : "Let Mochi walk with me",
            () -> {
              if (CompanionService.running) {
                stopService(new Intent(this, CompanionService.class));
                new Handler().postDelayed(this::render, 200);
              } else if (!Settings.canDrawOverlays(this)) {
                new AlertDialog.Builder(this)
                    .setTitle("Give Mochi room to roam")
                    .setMessage(
                        "Allow RemindMe to appear on top of other apps. Then come back and tap the"
                            + " start button again. Only the pet and its reminder bubbles appear"
                            + " over your screen.")
                    .setPositiveButton(
                        "Open permission",
                        (d, w) ->
                            startActivity(
                                new Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:" + getPackageName()))))
                    .setNegativeButton("Later", null)
                    .show();
              } else {
                try {
                  startForegroundService(new Intent(this, CompanionService.class));
                  new Handler().postDelayed(this::render, 300);
                } catch (Exception e) {
                  Toast.makeText(this, "Couldn't start Mochi. Try again with the app open.", 1)
                      .show();
                }
              }
            }));
    LinearLayout nav = new LinearLayout(this);
    page.addView(nav);
    for (String s : new String[] {"Today", "All tasks", "Companion"}) {
      Button b =
          button(
              s,
              () -> {
                tab = s;
                render();
              });
      if (tab.equals(s)) {
        b.setBackground(bg(GREEN, 16));
        b.setTextColor(Color.WHITE);
      }
      LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(46), 1);
      lp.setMargins(dp(2), 0, dp(2), dp(18));
      nav.addView(b, lp);
    }
    body = col();
    page.addView(body);
    if (tab.equals("Companion")) settings();
    else tasks();
  }

  void tasks() {
    ArrayList<Store.Task> a = Store.tasks(this);
    int left = 0;
    for (Store.Task t : a) if (!t.done) left++;
    body.addView(
        text(tab.equals("Today") ? "Your next small steps" : "Everything, in one place", 21, INK));
    body.addView(text(left + " unfinished · one thing at a time", 13, MUTED));
    space(body, 12);
    body.addView(button("＋  Add a task", () -> edit(null)));
    space(body, 16);
    Calendar end = Calendar.getInstance();
    end.set(Calendar.HOUR_OF_DAY, 23);
    end.set(Calendar.MINUTE, 59);
    end.set(Calendar.SECOND, 59);
    a.sort(
        (x, y) -> {
          if (x.done != y.done) return x.done ? 1 : -1;
          return Long.compare(
              x.due == 0 ? Long.MAX_VALUE : x.due, y.due == 0 ? Long.MAX_VALUE : y.due);
        });
    int shown = 0;
    for (Store.Task t : a) {
      if (tab.equals("Today") && (t.done || t.due > end.getTimeInMillis())) continue;
      shown++;
      LinearLayout c = card(body, Color.WHITE);
      LinearLayout r = new LinearLayout(this);
      c.addView(r);
      CheckBox check = new CheckBox(this);
      check.setContentDescription("Complete " + t.title);
      check.setChecked(t.done);
      r.addView(check);
      LinearLayout content = col();
      r.addView(content, new LinearLayout.LayoutParams(0, -2, 1));
      TextView title = text(t.title, 17, t.done ? MUTED : INK);
      if (t.done) title.setPaintFlags(title.getPaintFlags() | 16);
      content.addView(title);
      content.addView(
          text(
              t.list
                  + "  ·  "
                  + (t.due == 0
                      ? "No reminder"
                      : DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT)
                          .format(new Date(t.due))),
              12,
              MUTED));
      content.setOnClickListener(v -> edit(t));
      check.setOnCheckedChangeListener(
          (v, done) -> {
            ArrayList<Store.Task> fresh = Store.tasks(this);
            for (Store.Task x : fresh)
              if (x.id.equals(t.id)) {
                x.done = done;
                if (!done) x.reminded = false;
              }
            Store.save(this, fresh);
            render();
          });
    }
    if (shown == 0) {
      LinearLayout empty = card(body, Color.WHITE);
      empty.addView(text("Room for a fresh start.", 20, INK));
      empty.addView(text("Add your first small step. Mochi will help you remember it.", 15, MUTED));
    }
  }

  void edit(Store.Task original) {
    LinearLayout form = col();
    form.setPadding(dp(24), dp(8), dp(24), 0);
    EditText title = new EditText(this);
    title.setHint("What would you like to get done?");
    title.setMaxLines(3);
    form.addView(title);
    EditText list = new EditText(this);
    list.setHint("List, e.g. Personal or Work");
    form.addView(list);
    final long[] due = {original == null ? 0 : original.due};
    if (original != null) {
      title.setText(original.title);
      list.setText(original.list);
    }
    TextView info = text("", 14, GREEN);
    form.addView(info);
    Runnable update =
        () ->
            info.setText(
                due[0] == 0
                    ? "No reminder set"
                    : DateFormat.getDateTimeInstance().format(new Date(due[0])));
    update.run();
    form.addView(
        button(
            "Choose reminder date & time",
            () -> {
              Calendar c = Calendar.getInstance();
              if (due[0] > 0) c.setTimeInMillis(due[0]);
              new DatePickerDialog(
                      this,
                      (v, y, m, d) -> {
                        c.set(y, m, d);
                        new TimePickerDialog(
                                this,
                                (tv, h, min) -> {
                                  c.set(Calendar.HOUR_OF_DAY, h);
                                  c.set(Calendar.MINUTE, min);
                                  c.set(Calendar.SECOND, 0);
                                  c.set(Calendar.MILLISECOND, 0);
                                  due[0] = c.getTimeInMillis();
                                  update.run();
                                },
                                c.get(Calendar.HOUR_OF_DAY),
                                c.get(Calendar.MINUTE),
                                android.text.format.DateFormat.is24HourFormat(this))
                            .show();
                      },
                      c.get(Calendar.YEAR),
                      c.get(Calendar.MONTH),
                      c.get(Calendar.DAY_OF_MONTH))
                  .show();
            }));
    form.addView(
        button(
            "Clear reminder",
            () -> {
              due[0] = 0;
              update.run();
            }));
    AlertDialog dialog =
        new AlertDialog.Builder(this)
            .setTitle(original == null ? "A new small step" : "Edit your task")
            .setView(form)
            .setPositiveButton("Save", null)
            .setNegativeButton("Cancel", null)
            .setNeutralButton(
                original == null ? "" : "Delete",
                (d, w) -> {
                  if (original != null) {
                    ArrayList<Store.Task> a = Store.tasks(this);
                    a.removeIf(t -> t.id.equals(original.id));
                    Store.save(this, a);
                    render();
                  }
                })
            .create();
    dialog.setOnShowListener(
        v ->
            dialog
                .getButton(-1)
                .setOnClickListener(
                    b -> {
                      String s = title.getText().toString().trim();
                      if (s.isEmpty()) {
                        title.setError("Give your task a name");
                        return;
                      }
                      if (due[0] > 0 && due[0] < System.currentTimeMillis()) {
                        info.setText("Choose a future time, or clear the reminder.");
                        return;
                      }
                      ArrayList<Store.Task> a = Store.tasks(this);
                      String l = list.getText().toString().trim();
                      Store.Task t = new Store.Task(s, due[0], l.isEmpty() ? "Personal" : l);
                      if (original != null) {
                        t.id = original.id;
                        t.done = original.done;
                        a.removeIf(x -> x.id.equals(t.id));
                      }
                      a.add(t);
                      Store.save(this, a);
                      dialog.dismiss();
                      render();
                    }));
    dialog.show();
  }

  public static boolean hasUsage(Context c) {
    AppOpsManager a = c.getSystemService(AppOpsManager.class);
    return a.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), c.getPackageName())
        == AppOpsManager.MODE_ALLOWED;
  }

  void settings() {
    body.addView(text("A companion, at your pace.", 22, INK));
    space(body, 12);
    LinearLayout setup = card(body, Color.WHITE);
    setup.addView(text("Make room for Mochi", 18, INK));
    setup.addView(
        button(
            Settings.canDrawOverlays(this) ? "Floating pet allowed · manage" : "Allow floating pet",
            () ->
                startActivity(
                    new Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:" + getPackageName())))));
    space(setup, 8);
    setup.addView(
        button(
            getSystemService(NotificationManager.class).areNotificationsEnabled()
                ? "Task notifications allowed · manage"
                : "Allow task notifications",
            () ->
                startActivity(
                    new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName()))));
    LinearLayout c = card(body, Color.WHITE);
    c.addView(text("Phone-use nudges", 18, INK));
    c.addView(
        text(
            "Mochi counts continuous time across the apps you choose. Locking your phone or leaving"
                + " those apps resets the timer. Nothing is uploaded.",
            14,
            MUTED));
    Switch nudges = new Switch(this);
    nudges.setText("Enable gentle nudges");
    nudges.setChecked(Store.prefs(this).getBoolean("nudges", false));
    c.addView(nudges);
    nudges.setOnCheckedChangeListener(
        (v, b) -> Store.prefs(this).edit().putBoolean("nudges", b).apply());
    c.addView(
        button(
            hasUsage(this) ? "Usage access granted · manage" : "Allow app-usage access",
            () -> startActivity(new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))));
    space(c, 10);
    int minutes = Store.prefs(this).getInt("minutes", 20);
    TextView duration = text("Nudge me after " + minutes + " minutes", 15, INK);
    c.addView(duration);
    SeekBar seek = new SeekBar(this);
    seek.setMax(115);
    seek.setProgress(minutes - 5);
    c.addView(seek);
    seek.setOnSeekBarChangeListener(
        new SeekBar.OnSeekBarChangeListener() {
          public void onProgressChanged(SeekBar s, int p, boolean user) {
            duration.setText("Nudge me after " + (p + 5) + " minutes");
            if (user) Store.prefs(MainActivity.this).edit().putInt("minutes", p + 5).apply();
          }

          public void onStartTrackingTouch(SeekBar s) {}

          public void onStopTrackingTouch(SeekBar s) {}
        });
    c.addView(button("Choose apps to watch", this::chooseApps));
    c.addView(
        text(
            Store.prefs(this).getStringSet("watched", Collections.emptySet()).size()
                + " apps selected",
            12,
            MUTED));
    LinearLayout voice = card(body, Color.WHITE);
    Switch speech = new Switch(this);
    speech.setText("Read reminders aloud");
    speech.setChecked(Store.prefs(this).getBoolean("speech", false));
    speech.setOnCheckedChangeListener(
        (v, b) -> Store.prefs(this).edit().putBoolean("speech", b).apply());
    voice.addView(speech);
    voice.addView(text("Uses your phone’s text-to-speech voice. Off by default.", 13, MUTED));
    voice.addView(
        button(
            "Preview a pet reminder",
            () -> {
              if (CompanionService.running)
                startService(new Intent(this, CompanionService.class).setAction("PREVIEW"));
              else Toast.makeText(this, "Start Mochi first, then try a preview.", 0).show();
            }));
    LinearLayout help = card(body, 0xFFECEAE0);
    help.addView(text("Living with Mochi", 18, INK));
    help.addView(
        text(
            "Tap the cat for your next task. Drag to move it. Hold it to pause. You can also pause"
                + " from the persistent notification.\n\n"
                + "Dated tasks also send notifications while the pet is paused. Android may delay"
                + " reminders during battery saving. Start Mochi again after restarting your"
                + " phone.\n\n"
                + "Your tasks and selected apps stay on this device. The app has no internet"
                + " permission.",
            14,
            MUTED));
  }

  void chooseApps() {
    new Thread(
            () -> {
              Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
              List<ResolveInfo> found = getPackageManager().queryIntentActivities(intent, 0);
              TreeMap<String, String> apps = new TreeMap<>();
              for (ResolveInfo r : found)
                if (!r.activityInfo.packageName.equals(getPackageName()))
                  apps.put(
                      r.loadLabel(getPackageManager()).toString()
                          + "\n"
                          + r.activityInfo.packageName,
                      r.activityInfo.packageName);
              String[] labels = apps.keySet().toArray(new String[0]),
                  packages = apps.values().toArray(new String[0]);
              Set<String> selected =
                  new HashSet<>(Store.prefs(this).getStringSet("watched", Collections.emptySet()));
              boolean[] checked = new boolean[labels.length];
              for (int i = 0; i < labels.length; i++) checked[i] = selected.contains(packages[i]);
              runOnUiThread(
                  () ->
                      new AlertDialog.Builder(this)
                          .setTitle("Which apps need a gentle nudge?")
                          .setMultiChoiceItems(
                              labels,
                              checked,
                              (d, w, b) -> {
                                if (b) selected.add(packages[w]);
                                else selected.remove(packages[w]);
                              })
                          .setPositiveButton(
                              "Save",
                              (d, w) -> {
                                Store.prefs(this).edit().putStringSet("watched", selected).apply();
                                render();
                              })
                          .setNegativeButton("Cancel", null)
                          .show());
            })
        .start();
  }
}
