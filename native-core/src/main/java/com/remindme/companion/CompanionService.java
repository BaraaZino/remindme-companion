package com.remindme.companion;

import android.app.*;
import android.app.usage.*;
import android.content.*;
import android.os.*;
import java.util.*;

/** Background timing only. Companions are rendered exclusively inside Flutter. */
public class CompanionService extends Service {
  public static volatile boolean running;
  public static CompanionService instance;
  private final Handler h = new Handler(Looper.getMainLooper());
  private long lastUsage;
  private String foreground = "";
  private final Map<String, Counter> counters = new HashMap<>();

  private static class Counter {
    UsageSession session;
    String fingerprint;
    long lastNudge;

    Counter(long now, String fingerprint) {
      session = new UsageSession(now);
      this.fingerprint = fingerprint;
    }
  }

  // Recording now suspends the Flutter visit controller, not an Android overlay.
  public void deferForRecording() {}

  @Override
  public void onCreate() {
    super.onCreate();
    instance = this;
    ReminderReceiver.channels(this);
    PendingIntent pause =
        PendingIntent.getService(
            this,
            1,
            new Intent(this, CompanionService.class).setAction("STOP"),
            PendingIntent.FLAG_IMMUTABLE);
    startForeground(
        7,
        new Notification.Builder(this, "pet")
            .setSmallIcon(R.drawable.ic_cat)
            .setContentTitle("RemindMe app timers are active")
            .setContentText("Reminders use notifications. Pets appear only inside RemindMe.")
            .setContentIntent(ReminderReceiver.open(this))
            .setOngoing(true)
            .addAction(new Notification.Action.Builder(null, "Pause", pause).build())
            .build());
    running = true;
    h.post(tick);
  }

  private final Runnable tick =
      new Runnable() {
        public void run() {
          if (!running) return;
          for (int count = 0; count < 100; count++) {
            Store.Task task = Store.claimDue(CompanionService.this);
            if (task == null) break;
            ReminderReceiver.notifyTask(CompanionService.this, task);
            sendBroadcast(
                new Intent("com.remindme.companion.DUE")
                    .setPackage(getPackageName())
                    .putExtra("id", task.id));
          }
          usage();
          h.postDelayed(this, 5000);
        }
      };

  private void usage() {
    long now = System.currentTimeMillis();
    if (!getSystemService(PowerManager.class).isInteractive() || !MainActivity.hasUsage(this)) {
      counters.clear();
      lastUsage = now;
      foreground = "";
      return;
    }
    try {
      boolean initial = lastUsage == 0;
      long from = initial ? now - 60000 : lastUsage;
      UsageEvents events = getSystemService(UsageStatsManager.class).queryEvents(from, now);
      ArrayList<UsageEvents.Event> changes = new ArrayList<>();
      while (events != null && events.hasNextEvent()) {
        UsageEvents.Event e = new UsageEvents.Event();
        events.getNextEvent(e);
        changes.add(e);
      }
      Set<String> ids = new HashSet<>();
      for (PetProfile.Rule rule : PetProfile.rules(this)) {
        if (!rule.enabled || rule.apps.isEmpty()) continue;
        ids.add(rule.id);
        Counter counter = counters.get(rule.id);
        boolean fresh = counter == null || !counter.fingerprint.equals(rule.fingerprint());
        if (fresh) {
          counter = new Counter(now, rule.fingerprint());
          counter.session.resume(foreground, now, rule.apps);
          counters.put(rule.id, counter);
        }
        for (UsageEvents.Event e : changes) {
          long at = (initial || fresh) ? now : Math.min(now, e.getTimeStamp());
          int type = e.getEventType();
          if (type == UsageEvents.Event.ACTIVITY_RESUMED)
            counter.session.resume(e.getPackageName(), at, rule.apps);
          else if (type == UsageEvents.Event.ACTIVITY_PAUSED)
            counter.session.pause(e.getPackageName(), at, rule.apps);
          else if (type == UsageEvents.Event.SCREEN_NON_INTERACTIVE
              || type == UsageEvents.Event.KEYGUARD_SHOWN) counter.session.reset(at);
        }
        counter.session.advance(now, rule.apps);
        long used = counter.session.elapsed(), limit = rule.minutes * 60000L;
        if (used == 0) counter.lastNudge = 0;
        if (used >= limit && (counter.lastNudge == 0 || now - counter.lastNudge >= limit)) {
          counter.lastNudge = now;
          String text =
              "We’ve spent "
                  + used / 60000
                  + " minutes in "
                  + rule.name
                  + ". A stretch, or one small step?";
          ReminderReceiver.channels(this);
          getSystemService(NotificationManager.class)
              .notify(
                  ("timer-" + rule.id).hashCode(),
                  new Notification.Builder(this, "tasks")
                      .setSmallIcon(R.drawable.ic_cat)
                      .setContentTitle(
                          PetProfile.resolve(this, rule.companionId).name + " suggests a break")
                      .setContentText(text)
                      .setContentIntent(ReminderReceiver.open(this))
                      .setAutoCancel(true)
                      .build());
          sendBroadcast(
              new Intent("com.remindme.companion.VISIT")
                  .setPackage(getPackageName())
                  .putExtra("kind", "timer")
                  .putExtra("text", text)
                  .putExtra("petId", rule.companionId));
        }
      }
      counters.keySet().retainAll(ids);
      for (UsageEvents.Event e : changes) {
        if (e.getEventType() == UsageEvents.Event.ACTIVITY_RESUMED) foreground = e.getPackageName();
        else if (e.getEventType() == UsageEvents.Event.ACTIVITY_PAUSED
            && foreground.equals(e.getPackageName())) foreground = "";
      }
      lastUsage = now;
    } catch (RuntimeException e) {
      lastUsage = now;
      counters.clear();
    }
  }

  @Override
  public int onStartCommand(Intent intent, int flags, int id) {
    if (intent != null && "STOP".equals(intent.getAction())) {
      Store.prefs(this).edit().putBoolean("visitsEnabled", false).apply();
      stopSelf();
    }
    return START_NOT_STICKY;
  }

  @Override
  public void onDestroy() {
    running = false;
    instance = null;
    h.removeCallbacksAndMessages(null);
    super.onDestroy();
  }

  @Override
  public IBinder onBind(Intent i) {
    return null;
  }
}
