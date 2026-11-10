package com.remindme.companion;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.media.MediaPlayer;
import io.flutter.FlutterInjector;
import java.io.IOException;

/** Built-in sounds stay in the APK; private recording ownership rules stay unchanged. */
final class FlutterVoiceAssets {
  static boolean isAsset(String uri) {
    return uri != null && uri.matches(
        "asset:assets/audio/animal_voices/(cat|dog|bunny|fox|bear|panda|frog|penguin|owl|turtle|monkey)_(soft|bright|deep)_[123]\\.mp3");
  }

  static boolean canPlay(Context context, String uri) {
    return isAsset(uri) || (uri != null && VoiceFiles.owned(context, uri));
  }

  static void setDataSource(Context context, MediaPlayer player, String uri) throws IOException {
    if (isAsset(uri)) {
      String key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(uri.substring(6));
      try (AssetFileDescriptor asset = context.getAssets().openFd(key)) {
        player.setDataSource(asset.getFileDescriptor(), asset.getStartOffset(), asset.getLength());
      }
    } else if (VoiceFiles.owned(context, uri)) {
      player.setDataSource(uri);
    } else {
      throw new IOException("Unknown companion audio source.");
    }
  }
}
