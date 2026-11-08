package com.remindme.companion;

import android.app.*;
import android.app.usage.*;
import android.content.*;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.*;
import android.provider.Settings;
import android.speech.tts.TextToSpeech;
import android.view.*;
import android.widget.*;
import java.util.*;

public class CompanionService extends Service {
  public static volatile boolean running;
  private final Handler h = new Handler();
  WindowManager wm;
  WindowManager.LayoutParams params;
  LinearLayout root, bubble;
  TextView message;
  Button done, snooze;
  CatView cat;
  TextToSpeech tts;
  boolean voiceReady, dragging;
  int direction = 1;
  long bubbleUntil, lastInteraction, lastUsage, lastNudge;
  String activeTask;
  boolean registered;
  long bubbleStarted;
  UsageSession session;

  int dp(float v) {
    return (int) (v * getResources().getDisplayMetrics().density + .5f);
  }

  BroadcastReceiver dueReceiver =
      new BroadcastReceiver() {
        public void onReceive(Context c, Intent i) {
          String id = i.getStringExtra("id");
          for (Store.Task t : Store.tasks(c))
            if (t.id.equals(id) && !t.done) {
              show("A small step is waiting: " + t.title, t.id);
              break;
            }
        }
      };

  @Override
  public void onCreate() {
    super.onCreate();
    ReminderReceiver.channels(this);
    Intent stop = new Intent(this, CompanionService.class).setAction("STOP");
    PendingIntent pause = PendingIntent.getService(this, 1, stop, PendingIntent.FLAG_IMMUTABLE);
    Notification n =
        new Notification.Builder(this, "pet")
            .setSmallIcon(R.drawable.ic_cat)
            .setContentTitle("Mochi is keeping you company")
            .setContentText("Tap to open tasks · Pause to hide the cat")
            .setContentIntent(ReminderReceiver.open(this))
            .setOngoing(true)
            .addAction(new Notification.Action.Builder(null, "Pause", pause).build())
            .build();
    startForeground(7, n);
    if (!Settings.canDrawOverlays(this)) {
      stopSelf();
      return;
    }
    wm = getSystemService(WindowManager.class);
    root = new LinearLayout(this);
    root.setOrientation(1);
    root.setPadding(dp(4), dp(4), dp(4), dp(4));
    bubble = new LinearLayout(this);
    bubble.setOrientation(1);
    bubble.setPadding(dp(14), dp(12), dp(14), dp(10));
    GradientDrawable bg = new GradientDrawable();
    bg.setColor(0xFFFFFCF3);
    bg.setCornerRadius(dp(18));
    bg.setStroke(dp(1), 0xFFD8DDCF);
    bubble.setBackground(bg);
    message = new TextView(this);
    message.setTextColor(0xFF253D35);
    message.setTextSize(15);
    bubble.addView(message);
    LinearLayout actions = new LinearLayout(this);
    done = new Button(this);
    done.setText("Done ✓");
    done.setAllCaps(false);
    snooze = new Button(this);
    snooze.setText("10m later");
    snooze.setAllCaps(false);
    actions.addView(done, new LinearLayout.LayoutParams(0, dp(44), 1));
    actions.addView(snooze, new LinearLayout.LayoutParams(0, dp(44), 1));
    bubble.addView(actions);
    TextView close = new TextView(this);
    close.setText("Dismiss  ×");
    close.setTextColor(0xFF315D50);
    close.setPadding(0, dp(6), 0, dp(6));
    close.setOnClickListener(v -> hideBubble());
    bubble.addView(close);
    root.addView(bubble, new LinearLayout.LayoutParams(dp(248), -2));
    bubble.setVisibility(View.GONE);
    cat = new CatView(this);
    root.addView(cat, new LinearLayout.LayoutParams(dp(88), dp(84)));
    params =
        new WindowManager.LayoutParams(
            dp(256),
            dp(300),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT);
    params.gravity = Gravity.TOP | Gravity.LEFT;
    params.x = dp(20);
    params.y = Math.max(dp(60), getResources().getDisplayMetrics().heightPixels - dp(350));
    params.height = WindowManager.LayoutParams.WRAP_CONTENT;
    try {
      wm.addView(root, params);
    } catch (RuntimeException e) {
      stopSelf();
      return;
    }
    running = true;
    lastInteraction = System.currentTimeMillis();
    done.setOnClickListener(
        v -> {
          if (activeTask != null) {
            Store.complete(this, activeTask);
            show("Look at you go! One small step done.", null);
          }
        });
    snooze.setOnClickListener(
        v -> {
          if (activeTask != null) Store.snooze(this, activeTask);
          hideBubble();
        });
    cat.setOnTouchListener(
        new View.OnTouchListener() {
          float startX, startY;
          int x, y;
          long down;
          boolean moved;

          public boolean onTouch(View v, android.view.MotionEvent e) {
            switch (e.getActionMasked()) {
              case MotionEvent.ACTION_DOWN:
                dragging = true;
                startX = e.getRawX();
                startY = e.getRawY();
                x = params.x;
                y = params.y;
                down = System.currentTimeMillis();
                moved = false;
                return true;
              case MotionEvent.ACTION_MOVE:
                float dx = e.getRawX() - startX, dy = e.getRawY() - startY;
                if (Math.abs(dx) + Math.abs(dy) > dp(8)) moved = true;
                params.x = x + (int) dx;
                params.y = y + (int) dy;
                clamp();
                update();
                return true;
              case MotionEvent.ACTION_UP:
              case MotionEvent.ACTION_CANCEL:
                dragging = false;
                lastInteraction = System.currentTimeMillis();
                if (!moved && e.getActionMasked() == MotionEvent.ACTION_UP) {
                  if (System.currentTimeMillis() - down > 650) stopSelf();
                  else nextTask();
                }
                return true;
            }
            return false;
          }
        });
    IntentFilter filter = new IntentFilter("com.remindme.companion.DUE");
    if (Build.VERSION.SDK_INT >= 33)
      registerReceiver(dueReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
    else registerReceiver(dueReceiver, filter);
    registered = true;
    tts =
        new TextToSpeech(
            this,
            status -> {
              voiceReady = status == TextToSpeech.SUCCESS;
            });
    show("Hi, I'm Mochi! Tap me for your next step. Drag me anywhere; hold to pause.", null);
    h.post(walk);
    h.post(tick);
  }

  void clamp() {
    params.x =
        Math.max(
            0,
            Math.min(
                params.x,
                Math.max(0, getResources().getDisplayMetrics().widthPixels - params.width)));
    params.y =
        Math.max(
            dp(26),
            Math.min(
                params.y,
                Math.max(
                    dp(26),
                    getResources().getDisplayMetrics().heightPixels - root.getHeight() - dp(32))));
  }

  void update() {
    if (running)
      try {
        wm.updateViewLayout(root, params);
      } catch (IllegalArgumentException ignored) {
      }
  }

  void hideBubble() {
    bubbleUntil = 0;
    bubble.setVisibility(View.GONE);
    activeTask = null;
    params.width = dp(96);
    clamp();
    update();
  }

  void show(String s, String task) {
    activeTask = task;
    params.width = dp(256);
    message.setText(s);
    done.setVisibility(task == null ? View.GONE : View.VISIBLE);
    snooze.setVisibility(task == null ? View.GONE : View.VISIBLE);
    bubble.setVisibility(View.VISIBLE);
    bubbleStarted = System.currentTimeMillis();
    bubbleUntil = bubbleStarted + 25_000;
    root.post(
        () -> {
          clamp();
          update();
        });
    if (voiceReady && Store.prefs(this).getBoolean("speech", false))
      tts.speak(s, TextToSpeech.QUEUE_FLUSH, null, "mochi");
  }

  void nextTask() {
    Store.Task next = null;
    for (Store.Task t : Store.tasks(this))
      if (!t.done && (next == null || (t.due > 0 && (next.due == 0 || t.due < next.due)))) next = t;
    if (next == null) show("All clear! Take a breath. You've earned a little rest.", null);
    else show("Your next small step: " + next.title, next.id);
  }

  Runnable walk =
      new Runnable() {
        public void run() {
          if (!running) return;
          boolean interactive = getSystemService(PowerManager.class).isInteractive();
          cat.walking = interactive && !dragging && bubble.getVisibility() != View.VISIBLE;
          if (cat.walking && System.currentTimeMillis() - lastInteraction > 2500) {
            params.x += direction * dp(1);
            int max = Math.max(0, getResources().getDisplayMetrics().widthPixels - params.width);
            if (params.x >= max) {
              params.x = max;
              direction = -1;
            }
            if (params.x <= 0) {
              params.x = 0;
              direction = 1;
            }
            cat.faceRight = direction > 0;
            update();
            cat.invalidate();
          }
          if (bubbleUntil > 0 && System.currentTimeMillis() > bubbleUntil) hideBubble();
          h.postDelayed(this, interactive ? 90 : 1000);
        }
      };
  Runnable tick =
      new Runnable() {
        public void run() {
          if (!running) return;
          Store.Task t = Store.claimDue(CompanionService.this);
          if (t != null) {
            ReminderReceiver.notifyTask(CompanionService.this, t);
            show("A little reminder: " + t.title, t.id);
          }
          usage();
          h.postDelayed(this, 5000);
        }
      };

  void usage() {
    long now = System.currentTimeMillis();
    boolean unlocked =
        getSystemService(PowerManager.class).isInteractive()
            && !getSystemService(KeyguardManager.class).isKeyguardLocked();
    if (!Store.prefs(this).getBoolean("nudges", false)
        || !MainActivity.hasUsage(this)
        || !unlocked) {
      session = null;
      lastNudge = 0;
      lastUsage = now;
      return;
    }
    try {
      UsageStatsManager manager = getSystemService(UsageStatsManager.class);
      boolean starting = session == null;
      long from = starting ? now - 60_000 : lastUsage;
      if (starting) session = new UsageSession(now);
      UsageEvents events = manager.queryEvents(from, now);
      UsageEvents.Event event = new UsageEvents.Event();
      Set<String> watched = Store.prefs(this).getStringSet("watched", Collections.emptySet());
      while (events != null && events.hasNextEvent()) {
        events.getNextEvent(event);
        long at = starting ? now : Math.min(now, event.getTimeStamp());
        int type = event.getEventType();
        if (type == UsageEvents.Event.ACTIVITY_RESUMED)
          session.resume(event.getPackageName(), at, watched);
        else if (type == UsageEvents.Event.ACTIVITY_PAUSED)
          session.pause(event.getPackageName(), at, watched);
        else if (type == UsageEvents.Event.SCREEN_NON_INTERACTIVE
            || type == UsageEvents.Event.KEYGUARD_SHOWN) session.reset(at);
      }
      session.advance(now, watched);
      lastUsage = now;
      long used = session.elapsed();
      if (used == 0) lastNudge = 0;
      long limit = Store.prefs(this).getInt("minutes", 20) * 60_000L;
      if (used >= limit
          && (lastNudge == 0 || now - lastNudge >= limit)
          && bubble.getVisibility() != View.VISIBLE) {
        lastNudge = now;
        show(
            "We've spent "
                + (used / 60_000)
                + " minutes here. How about a stretch, or one small task?",
            null);
      }
    } catch (RuntimeException ignored) {
      lastUsage = now;
      session = null;
    }
  }

  @Override
  public int onStartCommand(Intent i, int flags, int id) {
    if (i != null && "STOP".equals(i.getAction())) stopSelf();
    else if (running && i != null && "PREVIEW".equals(i.getAction()))
      show("Hey, a little check-in! Ready for one small step?", null);
    return START_NOT_STICKY;
  }

  @Override
  public void onDestroy() {
    running = false;
    h.removeCallbacksAndMessages(null);
    if (registered) unregisterReceiver(dueReceiver);
    if (root != null && wm != null)
      try {
        wm.removeView(root);
      } catch (IllegalArgumentException ignored) {
      }
    if (tts != null) {
      tts.stop();
      tts.shutdown();
    }
    super.onDestroy();
  }

  @Override
  public IBinder onBind(Intent i) {
    return null;
  }
}
