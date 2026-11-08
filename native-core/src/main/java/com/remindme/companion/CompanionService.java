package com.remindme.companion;

import android.app.*;
import android.app.usage.*;
import android.content.*;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.media.*;
import android.os.*;
import android.provider.Settings;
import android.speech.tts.*;
import android.text.method.ScrollingMovementMethod;
import android.view.*;
import android.widget.*;
import java.util.*;
import org.json.*;

/** One foreground scheduler, with a small overlay visible only during reminder visits. */
public class CompanionService extends Service {
  public static volatile boolean running;
  public static CompanionService instance;
  private final Handler h = new Handler(Looper.getMainLooper());
  private WindowManager wm;
  private WindowManager.LayoutParams params;
  private LinearLayout root, bubble;
  private TextView message, name;
  private Button done, snooze;
  private CatView animal;
  private TextToSpeech tts;
  private boolean voiceReady, registered, audioDone = true, waitingTts, dragging, alternate;
  private MediaPlayer player;
  private AudioManager audioManager;
  private AudioFocusRequest focus;
  private final VisitMotion motion = new VisitMotion();
  private final ArrayDeque<Visit> queue = new ArrayDeque<>();
  private Visit active;
  private PetProfile profile;
  private int generation;
  private long voiceDeadline, lastUsage;
  private float catOffset, catY;
  private String foreground = "";
  private final Map<String, Counter> counters = new HashMap<>();

  private static class Visit {
    String text, taskId, petId, kind, key;
    PetProfile override;

    Visit(String text, String taskId, String petId, String kind, String key) {
      this.text = text;
      this.taskId = taskId;
      this.petId = petId;
      this.kind = kind;
      this.key = key;
    }
  }

  private static class Counter {
    UsageSession session;
    String fingerprint;
    long lastNudge;

    Counter(long now, String fingerprint) {
      session = new UsageSession(now);
      this.fingerprint = fingerprint;
    }
  }

  int dp(float n) {
    return Math.round(n * getResources().getDisplayMetrics().density);
  }

  boolean canVisit() {
    return getSystemService(PowerManager.class).isInteractive()
        && !getSystemService(KeyguardManager.class).isKeyguardLocked()
        && !VoiceFiles.recording;
  }

  private final BroadcastReceiver dueReceiver =
      new BroadcastReceiver() {
        public void onReceive(Context c, Intent i) {
          for (Store.Task t : Store.tasks(c))
            if (t.id.equals(i.getStringExtra("id")) && !t.done) {
              enqueueTask(t);
              break;
            }
        }
      };

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
    Notification n =
        new Notification.Builder(this, "pet")
            .setSmallIcon(R.drawable.ic_cat)
            .setContentTitle("Companion visits are enabled")
            .setContentText("Pets visit for tasks and app timers, then leave.")
            .setContentIntent(ReminderReceiver.open(this))
            .setOngoing(true)
            .addAction(new Notification.Action.Builder(null, "Pause visits", pause).build())
            .build();
    startForeground(7, n);
    if (!Settings.canDrawOverlays(this)) {
      stopSelf();
      return;
    }
    wm = getSystemService(WindowManager.class);
    audioManager = getSystemService(AudioManager.class);
    root = new LinearLayout(this);
    root.setOrientation(1);
    root.setGravity(Gravity.CENTER_HORIZONTAL);
    root.setPadding(dp(4), dp(4), dp(4), dp(4));
    bubble = new LinearLayout(this);
    bubble.setOrientation(1);
    bubble.setPadding(dp(14), dp(10), dp(14), dp(8));
    name = new TextView(this);
    name.setTextSize(11);
    bubble.addView(name);
    message = new TextView(this);
    message.setMovementMethod(new ScrollingMovementMethod());
    message.setMaxHeight(
        Math.max(dp(120), getResources().getDisplayMetrics().heightPixels - dp(360)));
    bubble.addView(message);
    LinearLayout actions = new LinearLayout(this);
    done = new Button(this);
    done.setText("Done ✓");
    done.setAllCaps(false);
    snooze = new Button(this);
    snooze.setText("10m later");
    snooze.setAllCaps(false);
    actions.addView(done, new LinearLayout.LayoutParams(0, dp(46), 1));
    actions.addView(snooze, new LinearLayout.LayoutParams(0, dp(46), 1));
    bubble.addView(actions);
    TextView close = new TextView(this);
    close.setText("Dismiss visit  ×");
    close.setTextColor(0xFF42634D);
    close.setPadding(0, dp(6), 0, dp(6));
    close.setOnClickListener(v -> leave());
    bubble.addView(close);
    root.addView(bubble, new LinearLayout.LayoutParams(-1, -2));
    bubble.setVisibility(View.GONE);
    animal = new CatView(this);
    root.addView(animal, new LinearLayout.LayoutParams(dp(88), dp(88)));
    params =
        new WindowManager.LayoutParams(
            dp(96),
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT);
    params.gravity = Gravity.TOP | Gravity.LEFT;
    root.setVisibility(View.GONE);
    try {
      wm.addView(root, params);
    } catch (RuntimeException e) {
      stopSelf();
      return;
    }
    running = true;
    done.setOnClickListener(
        v -> {
          if (active != null && active.taskId != null) Store.complete(this, active.taskId);
          leave();
        });
    snooze.setOnClickListener(
        v -> {
          if (active != null && active.taskId != null) Store.snooze(this, active.taskId);
          leave();
        });
    animal.setOnTouchListener(
        new View.OnTouchListener() {
          float x, y;
          int startY;
          double startX;
          long down;
          boolean moved;

          public boolean onTouch(View v, MotionEvent e) {
            if (active == null) return false;
            switch (e.getActionMasked()) {
              case MotionEvent.ACTION_DOWN:
                dragging = true;
                x = e.getRawX();
                y = e.getRawY();
                startX = motion.x;
                startY = params.y;
                down = SystemClock.elapsedRealtime();
                moved = false;
                return true;
              case MotionEvent.ACTION_MOVE:
                if (motion.phase == VisitMotion.Phase.TALKING) {
                  float dx = e.getRawX() - x, dy = e.getRawY() - y;
                  if (Math.abs(dx) + Math.abs(dy) > dp(8)) moved = true;
                  motion.x =
                      Math.max(
                          catOffset,
                          Math.min(
                              startX + dx,
                              getResources().getDisplayMetrics().widthPixels
                                  - params.width
                                  + catOffset));
                  params.x = (int) (motion.x - catOffset);
                  params.y =
                      Math.max(
                          dp(28),
                          Math.min(
                              startY + (int) dy,
                              getResources().getDisplayMetrics().heightPixels
                                  - root.getHeight()
                                  - dp(28)));
                  update();
                }
                return true;
              case MotionEvent.ACTION_UP:
              case MotionEvent.ACTION_CANCEL:
                dragging = false;
                if (!moved && SystemClock.elapsedRealtime() - down > 650) leave();
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
              if (waitingTts) {
                if (voiceReady) speakText();
                else audioDone = true;
              }
            });
    tts.setOnUtteranceProgressListener(
        new UtteranceProgressListener() {
          public void onStart(String id) {}

          public void onDone(String id) {
            h.post(
                () -> {
                  if (id.equals("visit-" + generation)) audioDone = true;
                });
          }

          public void onError(String id) {
            onDone(id);
          }
        });
    h.post(tick);
  }

  private void enqueueTask(Store.Task t) {
    PetProfile p = PetProfile.resolve(this, t.companionId);
    enqueue(new Visit("A little reminder: " + t.title, t.id, p.id, "task", "task-" + t.id));
  }

  private void enqueue(Visit v) {
    if (active != null && active.key.equals(v.key)) return;
    for (Visit waiting : queue) if (waiting.key.equals(v.key)) return;
    queue.add(v);
    beginNext();
  }

  private void beginNext() {
    if (!running || active != null || !canVisit() || queue.isEmpty()) return;
    Visit v = queue.poll();
    if (v.taskId != null) {
      boolean pending = false;
      for (Store.Task task : Store.tasks(this))
        if (task.id.equals(v.taskId) && !task.done) pending = true;
      if (!pending) {
        beginNext();
        return;
      }
    }
    active = v;
    profile = v.override != null ? v.override : PetProfile.resolve(this, v.petId);
    generation++;
    audioDone = !profile.voiceEnabled;
    waitingTts = false;
    animal.setProfile(profile);
    animal.walking = true;
    animal.talking = false;
    animal.setLayoutParams(new LinearLayout.LayoutParams(dp(profile.size), dp(profile.size)));
    root.setAlpha(profile.opacity);
    bubble.setVisibility(View.GONE);
    params.width = dp(profile.size + 8);
    catOffset = dp(4);
    int width = getResources().getDisplayMetrics().widthPixels,
        height = getResources().getDisplayMetrics().heightPixels;
    double target =
        (width - dp(profile.size))
            * ("left".equals(profile.position) ? .2 : "right".equals(profile.position) ? .8 : .5);
    float bubbleWidth = Math.min(dp(300), width - dp(24)),
        offset = (bubbleWidth - dp(profile.size)) / 2;
    target = Math.max(offset + dp(8), Math.min(target, width - bubbleWidth - dp(8) + offset));
    catY =
        Math.min(
            height - dp(profile.size + 80),
            Math.max(
                dp(220),
                height
                        * ("top".equals(profile.vertical)
                            ? .3f
                            : "middle".equals(profile.vertical) ? .55f : .8f)
                    - dp(profile.size)));
    params.y = (int) catY;
    boolean fromLeft =
        "left".equals(profile.entry)
            || ("alternate".equals(profile.entry) && (alternate = !alternate));
    motion.start(
        width,
        dp(profile.size),
        target,
        fromLeft,
        dp(profile.speed),
        (long) (profile.holdSeconds * 1000),
        SystemClock.elapsedRealtime());
    animal.faceRight = fromLeft;
    root.setVisibility(View.VISIBLE);
    position();
    h.removeCallbacks(frame);
    h.post(frame);
  }

  private void showBubble() {
    if (active == null) return;
    GradientDrawable bg = new GradientDrawable();
    bg.setColor(profile.bubbleColor);
    bg.setCornerRadius(dp(profile.radius));
    bg.setStroke(dp(1), 0xFFD8DDCF);
    bubble.setBackground(bg);
    message.setMaxHeight((int) Math.max(dp(72), catY - dp(170)));
    message.setText(active.text);
    message.setTextColor(profile.textColor);
    message.setTextSize(profile.fontSize);
    name.setText(profile.name);
    name.setTextColor(profile.textColor);
    Typeface face;
    String file =
        "mono".equals(profile.font)
            ? "RobotoMono"
            : "serif".equals(profile.font) ? "Lora" : "Nunito";
    try {
      face = Typeface.createFromAsset(getAssets(), "flutter_assets/assets/fonts/" + file + ".ttf");
    } catch (RuntimeException e) {
      face =
          Typeface.create(
              "mono".equals(profile.font)
                  ? "monospace"
                  : "serif".equals(profile.font) ? "serif" : "sans-serif",
              Typeface.NORMAL);
    }
    message.setTypeface(face);
    done.setVisibility(active.taskId == null ? View.GONE : View.VISIBLE);
    snooze.setVisibility(active.taskId == null ? View.GONE : View.VISIBLE);
    params.width = Math.min(dp(300), getResources().getDisplayMetrics().widthPixels - dp(24));
    catOffset = (params.width - dp(profile.size)) / 2f;
    bubble.setVisibility(View.VISIBLE);
    root.measure(
        View.MeasureSpec.makeMeasureSpec(params.width, View.MeasureSpec.EXACTLY),
        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED));
    int bubbleHeight = root.getMeasuredHeight() - dp(profile.size) - dp(8);
    params.y =
        (int)
            Math.max(
                dp(28),
                Math.min(
                    catY - bubbleHeight,
                    getResources().getDisplayMetrics().heightPixels
                        - root.getMeasuredHeight()
                        - dp(28)));
    animal.walking = false;
    animal.talking = true;
    voiceDeadline = SystemClock.elapsedRealtime() + 75000;
    playVoice();
  }

  private void hideBubble() {
    if (profile == null) return;
    int y = params.y + Math.max(0, root.getHeight() - dp(profile.size) - dp(8));
    bubble.setVisibility(View.GONE);
    params.width = dp(profile.size + 8);
    params.y = Math.min(y, getResources().getDisplayMetrics().heightPixels - dp(profile.size + 32));
    catOffset = dp(4);
    animal.talking = false;
    animal.walking = true;
  }

  private void position() {
    params.x = (int) (motion.x - catOffset);
    if (motion.phase == VisitMotion.Phase.TALKING)
      params.x =
          Math.max(
              dp(8),
              Math.min(
                  params.x, getResources().getDisplayMetrics().widthPixels - params.width - dp(8)));
    update();
    animal.invalidate();
  }

  private void update() {
    if (running)
      try {
        wm.updateViewLayout(root, params);
      } catch (RuntimeException e) {
        stopSelf();
      }
  }

  private void leave() {
    if (active == null) return;
    stopAudio();
    hideBubble();
    motion.exit();
  }

  public void deferForRecording() {
    if (active != null) {
      Visit v = active;
      stopAudio();
      motion.cancel();
      root.setVisibility(View.GONE);
      active = null;
      queue.addFirst(v);
      h.removeCallbacks(frame);
    }
  }

  private final Runnable frame =
      new Runnable() {
        public void run() {
          if (!running || active == null) return;
          if (!canVisit()) {
            deferForRecording();
            return;
          }
          VisitMotion.Phase before = motion.phase;
          if (!dragging)
            motion.tick(
                SystemClock.elapsedRealtime(),
                audioDone || SystemClock.elapsedRealtime() > voiceDeadline);
          if (before == VisitMotion.Phase.ENTERING && motion.phase == VisitMotion.Phase.TALKING)
            showBubble();
          if (before == VisitMotion.Phase.TALKING && motion.phase == VisitMotion.Phase.EXITING) {
            stopAudio();
            hideBubble();
          }
          if (motion.phase == VisitMotion.Phase.IDLE) {
            stopAudio();
            root.setVisibility(View.GONE);
            active = null;
            beginNext();
            return;
          }
          position();
          h.postDelayed(this, 32);
        }
      };

  private void playVoice() {
    if (!profile.voiceEnabled) {
      audioDone = true;
      return;
    }
    audioDone = false;
    final int token = generation;
    AudioAttributes attrs =
        new AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build();
    focus =
        new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(attrs)
            .setOnAudioFocusChangeListener(
                change -> {
                  if (change == AudioManager.AUDIOFOCUS_LOSS)
                    h.post(
                        () -> {
                          if (token == generation) stopAudio();
                        });
                })
            .build();
    if (audioManager.requestAudioFocus(focus) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
      audioDone = true;
      return;
    }
    String path = "timer".equals(active.kind) ? profile.timerClip : profile.taskClip;
    if (!path.isEmpty() && VoiceFiles.owned(this, path)) {
      try {
        player = new MediaPlayer();
        player.setAudioAttributes(attrs);
        player.setDataSource(path);
        player.setVolume(profile.volume, profile.volume);
        player.setOnPreparedListener(
            p -> {
              if (token == generation
                  && active != null
                  && motion.phase == VisitMotion.Phase.TALKING
                  && player == p) p.start();
            });
        player.setOnCompletionListener(
            p -> {
              if (token == generation && motion.phase == VisitMotion.Phase.TALKING && player == p) {
                releasePlayer();
                if (profile.readText) speakText();
                else audioDone = true;
              }
            });
        player.setOnErrorListener(
            (p, w, e) -> {
              if (token == generation && motion.phase == VisitMotion.Phase.TALKING && player == p) {
                releasePlayer();
                speakText();
              }
              return true;
            });
        player.prepareAsync();
        return;
      } catch (Exception e) {
        releasePlayer();
      }
    }
    speakText();
  }

  private void speakText() {
    if (active == null || !profile.voiceEnabled) {
      audioDone = true;
      return;
    }
    if (!voiceReady) {
      waitingTts = true;
      return;
    }
    waitingTts = false;
    tts.setAudioAttributes(
        new AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build());
    tts.setSpeechRate(profile.rate);
    tts.setPitch(profile.pitch);
    Bundle options = new Bundle();
    options.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, profile.volume);
    if (tts.speak(active.text, TextToSpeech.QUEUE_FLUSH, options, "visit-" + generation)
        == TextToSpeech.ERROR) audioDone = true;
  }

  private void releasePlayer() {
    if (player != null) {
      player.release();
      player = null;
    }
  }

  private void stopAudio() {
    waitingTts = false;
    audioDone = true;
    releasePlayer();
    if (tts != null) tts.stop();
    if (focus != null) {
      audioManager.abandonAudioFocusRequest(focus);
      focus = null;
    }
  }

  private final Runnable tick =
      new Runnable() {
        public void run() {
          if (!running) return;
          if (!Settings.canDrawOverlays(CompanionService.this)) {
            stopSelf();
            return;
          }
          Store.Task t = Store.claimDue(CompanionService.this);
          if (t != null) {
            ReminderReceiver.notifyTask(CompanionService.this, t);
            enqueueTask(t);
          }
          usage();
          beginNext();
          h.postDelayed(this, 5000);
        }
      };

  private void usage() {
    long now = System.currentTimeMillis();
    if (!canVisit() || !MainActivity.hasUsage(this)) {
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
          enqueue(
              new Visit(
                  "We’ve spent "
                      + used / 60000
                      + " minutes in "
                      + rule.name
                      + ". A stretch, or one small step?",
                  null,
                  rule.companionId,
                  "timer",
                  "timer-" + rule.id));
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
  public int onStartCommand(Intent i, int flags, int id) {
    if (i != null && "STOP".equals(i.getAction())) stopSelf();
    else if (running && i != null && "PREVIEW".equals(i.getAction())) {
      PetProfile p = PetProfile.resolve(this, PetProfile.defaultId(this));
      try {
        if (i.hasExtra("profile")) p = PetProfile.from(new JSONObject(i.getStringExtra("profile")));
      } catch (JSONException ignored) {
      }
      String kind = i.getStringExtra("kind");
      if (kind == null) kind = "task";
      String text = i.getStringExtra("text");
      if (text == null)
        text = "Hi, I’m " + p.name + ". A little step is waiting. Let’s make room for it.";
      Visit v = new Visit(text, null, p.id, kind, "preview-" + SystemClock.elapsedRealtime());
      v.override = p;
      enqueue(v);
    }
    return START_NOT_STICKY;
  }

  @Override
  public void onDestroy() {
    running = false;
    instance = null;
    h.removeCallbacksAndMessages(null);
    stopAudio();
    if (registered) unregisterReceiver(dueReceiver);
    if (root != null && wm != null)
      try {
        wm.removeView(root);
      } catch (RuntimeException ignored) {
      }
    if (tts != null) tts.shutdown();
    super.onDestroy();
  }

  @Override
  public IBinder onBind(Intent i) {
    return null;
  }
}
