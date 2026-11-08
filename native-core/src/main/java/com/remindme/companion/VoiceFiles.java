package com.remindme.companion;

import android.content.Context;
import android.media.MediaMetadataRetriever;
import java.io.*;
import org.json.*;

public final class VoiceFiles {
  public static volatile boolean recording;

  public static boolean owned(Context c, String path) {
    try {
      return new File(path)
          .getCanonicalPath()
          .startsWith(new File(c.getFilesDir(), "voices").getCanonicalPath() + File.separator);
    } catch (Exception e) {
      return false;
    }
  }

  public static void validate(Context c, File file) throws Exception {
    if (!owned(c, file.getPath()) || file.length() > 5 * 1024 * 1024 || file.length() == 0)
      throw new IOException("Choose audio up to 5 MB and 60 seconds.");
    MediaMetadataRetriever r = new MediaMetadataRetriever();
    try {
      r.setDataSource(file.getPath());
      String duration = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
      if (duration == null || Long.parseLong(duration) > 61000)
        throw new IOException("Choose an audio clip no longer than 60 seconds.");
    } finally {
      r.release();
    }
  }

  public static void deleteUnused(Context c, String path) {
    if (!owned(c, path)) return;
    JSONArray a = PetProfile.companions(c);
    for (int i = 0; i < a.length(); i++) {
      JSONObject p = a.optJSONObject(i);
      if (p != null
          && (path.equals(p.optString("taskClip")) || path.equals(p.optString("timerClip"))))
        return;
    }
    new File(path).delete();
  }
}
