package com.remindme.companion;

import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.media.*;
import android.net.Uri;
import android.os.*;
import android.provider.OpenableColumns;
import io.flutter.plugin.common.MethodChannel;
import java.io.*;
import java.util.*;

/** Explicit, foreground-only microphone recording and system audio-file selection. */
final class VoiceCapture {
  static final int PICK = 702, MIC = 703;
  final Activity activity;
  MethodChannel.Result picking, permission, playing;
  MediaRecorder recorder;
  MediaPlayer player;
  File recordingFile, lastRecording;
  final Handler handler = new Handler(Looper.getMainLooper());

  VoiceCapture(Activity a) {
    activity = a;
  }

  Map<String, Object> clip(File file, String name) {
    Map<String, Object> out = new HashMap<>();
    out.put("uri", file.getPath());
    out.put("name", name);
    return out;
  }

  boolean handle(String method, Object args, MethodChannel.Result result) throws Exception {
    switch (method) {
      case "pickVoice":
        if (picking != null) {
          result.error("busy", "The audio picker is already open.", null);
          return true;
        }
        picking = result;
        try {
          activity.startActivityForResult(
              new Intent(Intent.ACTION_OPEN_DOCUMENT)
                  .setType("audio/*")
                  .addCategory(Intent.CATEGORY_OPENABLE),
              PICK);
        } catch (Exception e) {
          picking = null;
          throw e;
        }
        return true;
      case "startRecording":
        if (permission != null || recorder != null) {
          result.error("busy", "A recording is already in progress.", null);
          return true;
        }
        if (activity.checkSelfPermission("android.permission.RECORD_AUDIO")
            != PackageManager.PERMISSION_GRANTED) {
          permission = result;
          activity.requestPermissions(new String[] {"android.permission.RECORD_AUDIO"}, MIC);
        } else start(result);
        return true;
      case "stopRecording":
        finish();
        if (lastRecording == null) {
          result.error("recording", "No recording was saved. Please record again.", null);
        } else {
          VoiceFiles.validate(activity, lastRecording);
          result.success(clip(lastRecording, "My recording.m4a"));
          lastRecording = null;
        }
        return true;
      case "cancelRecording":
        if (permission != null) {
          MethodChannel.Result pending = permission;
          permission = null;
          pending.error("cancelled", "Recording cancelled.", null);
        }
        finish();
        if (lastRecording != null) VoiceFiles.deleteUnused(activity, lastRecording.getPath());
        lastRecording = null;
        result.success(null);
        return true;
      case "deleteClip":
        VoiceFiles.deleteUnused(activity, (String) args);
        result.success(null);
        return true;
      case "stopClip":
        stopPlayer();
        result.success(null);
        return true;
      case "playClip":
        {
          stopPlayer();
          Map<?, ?> map = (Map<?, ?>) args;
          String path = (String) map.get("uri");
          if (!VoiceFiles.owned(activity, path)) {
            result.error("audio", "This clip is no longer available. Import it again.", null);
            return true;
          }
          playing = result;
          player = new MediaPlayer();
          player.setAudioAttributes(
              new AudioAttributes.Builder()
                  .setUsage(AudioAttributes.USAGE_MEDIA)
                  .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                  .build());
          player.setDataSource(path);
          float volume = ((Number) map.get("volume")).floatValue();
          player.setVolume(volume, volume);
          player.setOnPreparedListener(p -> p.start());
          player.setOnCompletionListener(p -> stopPlayer());
          player.setOnErrorListener(
              (p, w, e) -> {
                MethodChannel.Result failed = playing;
                playing = null;
                stopPlayer();
                if (failed != null)
                  failed.error(
                      "audio", "This clip cannot be played. Try another audio file.", null);
                return true;
              });
          player.prepareAsync();
          handler.postDelayed(this::stopPlayer, 75000);
          return true;
        }
      default:
        return false;
    }
  }

  void start(MethodChannel.Result result) {
    try {
      File dir = new File(activity.getFilesDir(), "voices");
      dir.mkdirs();
      recordingFile = new File(dir, UUID.randomUUID() + ".m4a");
      lastRecording = null;
      VoiceFiles.recording = true;
      if (CompanionService.instance != null) CompanionService.instance.deferForRecording();
      recorder = Build.VERSION.SDK_INT >= 31 ? new MediaRecorder(activity) : new MediaRecorder();
      recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
      recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
      recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
      recorder.setAudioSamplingRate(44100);
      recorder.setAudioEncodingBitRate(96000);
      recorder.setMaxDuration(60000);
      recorder.setOutputFile(recordingFile.getPath());
      recorder.setOnInfoListener(
          (r, what, extra) -> {
            if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) finish();
          });
      recorder.prepare();
      recorder.start();
      result.success(null);
    } catch (Exception e) {
      finish();
      VoiceFiles.recording = false;
      if (recordingFile != null) recordingFile.delete();
      result.error(
          "microphone", "Could not record audio. Check microphone permission and try again.", null);
    }
  }

  void finish() {
    if (recorder == null) return;
    try {
      recorder.stop();
      lastRecording = recordingFile;
    } catch (RuntimeException e) {
      try {
        VoiceFiles.validate(activity, recordingFile);
        lastRecording = recordingFile;
      } catch (Exception invalid) {
        if (recordingFile != null) recordingFile.delete();
        lastRecording = null;
      }
    } finally {
      recorder.release();
      recorder = null;
      VoiceFiles.recording = false;
    }
  }

  void permissionResult(int code, int[] grants) {
    if (code != MIC || permission == null) return;
    MethodChannel.Result result = permission;
    permission = null;
    if (grants.length > 0 && grants[0] == PackageManager.PERMISSION_GRANTED) start(result);
    else
      result.error(
          "microphone",
          "Microphone permission is needed only to record a clip. You can still import audio"
              + " files.",
          null);
  }

  void activityResult(int code, int resultCode, Intent data) {
    if (code != PICK || picking == null) return;
    MethodChannel.Result result = picking;
    picking = null;
    if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
      result.success(null);
      return;
    }
    Uri uri = data.getData();
    new Thread(
            () -> {
              File file = null;
              try {
                String name = "My voice clip";
                try (Cursor cursor =
                    activity
                        .getContentResolver()
                        .query(
                            uri, new String[] {OpenableColumns.DISPLAY_NAME}, null, null, null)) {
                  if (cursor != null && cursor.moveToFirst()) name = cursor.getString(0);
                }
                File dir = new File(activity.getFilesDir(), "voices");
                dir.mkdirs();
                file = new File(dir, UUID.randomUUID() + ".audio");
                try (InputStream in = activity.getContentResolver().openInputStream(uri);
                    OutputStream out = new FileOutputStream(file)) {
                  if (in == null) throw new IOException();
                  byte[] buffer = new byte[8192];
                  int count, total = 0;
                  while ((count = in.read(buffer)) != -1) {
                    total += count;
                    if (total > 5 * 1024 * 1024)
                      throw new IOException("Choose an audio file up to 5 MB.");
                    out.write(buffer, 0, count);
                  }
                }
                VoiceFiles.validate(activity, file);
                Map<String, Object> value = clip(file, name);
                activity.runOnUiThread(() -> result.success(value));
              } catch (Exception e) {
                if (file != null) file.delete();
                activity.runOnUiThread(
                    () ->
                        result.error(
                            "audio",
                            "Choose a playable audio file up to 5 MB and 60 seconds.",
                            null));
              }
            })
        .start();
  }

  void stopPlayer() {
    handler.removeCallbacksAndMessages(null);
    if (player != null) {
      player.release();
      player = null;
    }
    if (playing != null) {
      MethodChannel.Result result = playing;
      playing = null;
      result.success(null);
    }
  }

  void dispose() {
    finish();
    stopPlayer();
    if (permission != null) {
      permission.error("cancelled", "Recording cancelled.", null);
      permission = null;
    }
    if (picking != null) {
      picking.success(null);
      picking = null;
    }
  }
}
