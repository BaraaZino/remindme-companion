package com.remindme.companion;

import android.app.*;
import android.content.*;

public class ReminderReceiver extends BroadcastReceiver {
  public static void channels(Context c) {
    NotificationManager n = c.getSystemService(NotificationManager.class);
    n.createNotificationChannel(
        new NotificationChannel("tasks", "Task reminders", NotificationManager.IMPORTANCE_HIGH));
    n.createNotificationChannel(
        new NotificationChannel("pet", "Companion controls", NotificationManager.IMPORTANCE_LOW));
  }

  static PendingIntent open(Context c) {
    return PendingIntent.getActivity(
        c,
        0,
        new Intent(c, MainActivity.class),
        PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
  }

  public static void notifyTask(Context c, Store.Task t) {
    channels(c);
    Notification n =
        new Notification.Builder(c, "tasks")
            .setSmallIcon(com.remindme.companion.R.drawable.ic_cat)
            .setContentTitle(PetProfile.resolve(c, t.companionId).name + " has a little reminder")
            .setContentText(t.title)
            .setStyle(new Notification.BigTextStyle().bigText(t.title))
            .setContentIntent(open(c))
            .setAutoCancel(true)
            .build();
    c.getSystemService(NotificationManager.class).notify(t.id.hashCode(), n);
  }

  public static void schedule(Context c) {
    long next = Long.MAX_VALUE;
    for (Store.Task t : Store.tasks(c)) next = Math.min(next, t.nextReminder());
    AlarmManager a = c.getSystemService(AlarmManager.class);
    PendingIntent p =
        PendingIntent.getBroadcast(
            c,
            0,
            new Intent(c, ReminderReceiver.class).setAction("REMIND"),
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    a.cancel(p);
    if (next != Long.MAX_VALUE) {
      long time = Math.max(next, System.currentTimeMillis() + 1000);
      try {
        if (android.os.Build.VERSION.SDK_INT < 31 || a.canScheduleExactAlarms()) {
          a.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, p);
          return;
        }
      } catch (SecurityException ignored) {
      }
      a.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, p);
    }
  }

  @Override
  public void onReceive(Context c, Intent i) {
    if (!Intent.ACTION_BOOT_COMPLETED.equals(i.getAction())) {
      for (int count = 0; count < 100; count++) {
        Store.Task t = Store.claimDue(c);
        if (t == null) break;
        notifyTask(c, t);
        c.sendBroadcast(
            new Intent("com.remindme.companion.DUE")
                .setPackage(c.getPackageName())
                .putExtra("id", t.id));
      }
    }
    schedule(c);
  }
}
