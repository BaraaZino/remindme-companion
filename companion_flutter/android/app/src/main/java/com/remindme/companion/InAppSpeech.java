package com.remindme.companion;

import android.app.Activity;
import android.media.*;
import android.os.*;
import android.speech.tts.*;
import io.flutter.plugin.common.MethodChannel;
import java.util.*;

/** Audio for foreground Flutter visits, canceled whenever the activity is paused. */
final class InAppSpeech {
  private final Activity activity;
  private final Handler handler = new Handler(Looper.getMainLooper());
  private TextToSpeech tts;
  private MediaPlayer player;
  private MethodChannel.Result pending;
  private Runnable ready, timeout;
  private boolean initialized, available;
  private int generation;

  InAppSpeech(Activity activity) {
    this.activity = activity;
    tts =
        new TextToSpeech(
            activity,
            status ->
                handler.post(
                    () -> {
                      initialized = true;
                      available = status == TextToSpeech.SUCCESS;
                      if (ready != null) {
                        Runnable next = ready;
                        ready = null;
                        next.run();
                      }
                    }));
    tts.setOnUtteranceProgressListener(
        new UtteranceProgressListener() {
          public void onStart(String id) {}

          public void onDone(String id) {
            finish(id, null);
          }

          public void onError(String id) {
            finish(id, "The system voice could not read this reminder.");
          }
        });
  }

  private void finish(String id, String error) {
    handler.post(
        () -> {
          if (id.equals("in-app-" + generation)) complete(error);
        });
  }

  void stop() {
    generation++;
    ready = null;
    if (timeout != null) handler.removeCallbacks(timeout);
    if (player != null) {
      player.release();
      player = null;
    }
    if (tts != null) tts.stop();
    complete(null);
  }

  private void complete(String error) {
    if (player != null) {
      player.release();
      player = null;
    }
    if (pending == null) return;
    MethodChannel.Result result = pending;
    pending = null;
    if (error == null) result.success(null);
    else result.error("speech", error, null);
  }

  void say(Map<?, ?> args, MethodChannel.Result result) throws Exception {
    stop();
    pending = result;
    final int token = generation;
    PetProfile pet = PetProfile.from(new org.json.JSONObject((Map<?, ?>) args.get("profile")));
    if (!pet.voiceEnabled) {
      complete(null);
      return;
    }
    String text = (String) args.get("text");
    String clip = args.get("clip") instanceof String
        ? (String) args.get("clip")
        : "timer".equals(args.get("kind")) ? pet.timerClip : pet.taskClip;
    Runnable speech =
        () -> {
          if (token != generation || pending == null) return;
          if (!initialized) {
            ready = () -> speak(pet, text, token);
          } else speak(pet, text, token);
        };
    timeout =
        () -> {
          if (token == generation && pending != null) stop();
        };
    handler.postDelayed(timeout, 75000);
    if (!clip.isEmpty() && FlutterVoiceAssets.canPlay(activity, clip)) {
      try {
        player = new MediaPlayer();
        player.setAudioAttributes(
            new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build());
        FlutterVoiceAssets.setDataSource(activity, player, clip);
        player.setVolume(pet.volume, pet.volume);
        player.setOnPreparedListener(
            p -> {
              if (token == generation && player == p) p.start();
            });
        player.setOnCompletionListener(
            p -> {
              if (token != generation || player != p) return;
              p.release();
              player = null;
              if (pet.readText) speech.run();
              else complete(null);
            });
        player.setOnErrorListener(
            (p, w, e) -> {
              if (token == generation && player == p) {
                p.release();
                player = null;
                speech.run();
              }
              return true;
            });
        player.prepareAsync();
        return;
      } catch (Exception e) {
        if (player != null) {
          player.release();
          player = null;
        }
      }
    }
    speech.run();
  }

  private void speak(PetProfile pet, String text, int token) {
    if (token != generation || pending == null) return;
    if (!available) {
      complete("No system speech engine is available.");
      return;
    }
    tts.setSpeechRate(pet.rate);
    tts.setPitch(pet.pitch);
    Bundle options = new Bundle();
    options.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, pet.volume);
    if (tts.speak(text, TextToSpeech.QUEUE_FLUSH, options, "in-app-" + token) == TextToSpeech.ERROR)
      complete("The system voice could not start.");
  }

  void dispose() {
    stop();
    tts.shutdown();
  }
}
