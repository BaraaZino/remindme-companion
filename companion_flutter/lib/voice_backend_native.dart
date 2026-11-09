import 'companion_model.dart';

class VoiceTools {
  static Future<VoiceClip?> importClip() async {
    final result = await CompanionModel.channel
        .invokeMethod<Map<dynamic, dynamic>>('pickVoice');
    return result == null ? null : VoiceClip.fromJson(result);
  }

  static Future<void> startRecording() async {
    await CompanionModel.channel.invokeMethod('startRecording');
  }

  static Future<VoiceClip?> stopRecording() async {
    final result = await CompanionModel.channel
        .invokeMethod<Map<dynamic, dynamic>>('stopRecording');
    return result == null ? null : VoiceClip.fromJson(result);
  }

  static Future<void> cancelRecording() async {
    await CompanionModel.channel.invokeMethod('cancelRecording');
  }

  static Future<void> deleteClip(String uri) async {
    try {
      await CompanionModel.channel.invokeMethod('deleteClip', uri);
    } catch (_) {}
  }

  static Future<void> stopPlayback() async {
    await CompanionModel.channel.invokeMethod('stopSpeech');
    await CompanionModel.channel.invokeMethod('stopClip');
  }

  static Future<void> playClip(String uri, double volume) async {
    await CompanionModel.channel
        .invokeMethod('playClip', {'uri': uri, 'volume': volume});
  }

  static Future<void> say(Pet pet, String text, String kind) async {
    await CompanionModel.channel.invokeMethod(
        'say', {'profile': pet.toJson(), 'text': text, 'kind': kind});
  }
}
