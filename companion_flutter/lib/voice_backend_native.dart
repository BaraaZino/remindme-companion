import 'companion_model.dart';
import 'animal_voices.dart';

class VoiceTools {
  static int _playToken = 0;
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

  static Future<int> _beginPlayback() async {
    final token = ++_playToken;
    await CompanionModel.channel.invokeMethod('stopSpeech');
    if (token == _playToken) {
      await CompanionModel.channel.invokeMethod('stopClip');
    }
    return token;
  }

  static Future<void> stopPlayback() async {
    await _beginPlayback();
  }

  static Future<void> playClip(String uri, double volume) async {
    final token = await _beginPlayback();
    if (token != _playToken) return;
    await CompanionModel.channel
        .invokeMethod('playClip', {'uri': uri, 'volume': volume});
  }

  static Future<void> say(Pet pet, String text, String kind) async {
    if (!pet.voiceEnabled) return;
    final token = await _beginPlayback();
    if (token != _playToken) return;
    await CompanionModel.channel.invokeMethod('say', {
      'profile': pet.toJson(),
      'text': text,
      'kind': kind,
      'clip': AnimalVoices.clip(pet, kind)
    });
  }
}
