import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'companion_model.dart';

class VoiceTools {
  static int _captureToken = 0, _playToken = 0;
  static Completer<void>? _speechDone;
  static web.MediaRecorder? _recorder;
  static web.MediaStream? _stream;
  static final List<web.Blob> _chunks = [];
  static Completer<VoiceClip?>? _recordDone;
  static web.HTMLAudioElement? _audio;
  static Completer<void>? _audioDone;
  static Future<String> _read(web.Blob blob) {
    final done = Completer<String>();
    final reader = web.FileReader();
    reader.onload = ((web.Event e) {
      done.complete((reader.result as JSString).toDart);
    }).toJS;
    reader.onerror = ((web.Event e) {
      done.completeError(StateError('Could not read this audio file.'));
    }).toJS;
    reader.readAsDataURL(blob);
    return done.future;
  }

  static Future<void> _validate(String uri) async {
    final player = web.HTMLAudioElement()..preload = 'metadata';
    final done = Completer<void>();
    player.onloadedmetadata = ((web.Event e) {
      if (player.duration.isFinite && player.duration <= 61) {
        done.complete();
      } else {
        done.completeError(
            StateError('Choose a playable clip no longer than 60 seconds.'));
      }
    }).toJS;
    player.onerror = ((web.Event e) {
      if (!done.isCompleted) {
        done.completeError(StateError(
            'This browser cannot play that audio format. Try MP3, M4A, or WAV.'));
      }
    }).toJS;
    player.src = uri;
    try {
      await done.future.timeout(const Duration(seconds: 15));
    } finally {
      player.pause();
      player.src = '';
    }
  }

  static Future<VoiceClip?> importClip() async {
    final done = Completer<VoiceClip?>();
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = 'audio/*';
    input.onchange = ((web.Event e) {
      () async {
        try {
          final file = input.files?.item(0);
          if (file == null) {
            done.complete(null);
            return;
          }
          if (file.size > 5 * 1024 * 1024) {
            throw StateError('Choose a clip up to 5 MB.');
          }
          final uri = await _read(file);
          await _validate(uri);
          done.complete(VoiceClip(uri, file.name));
        } catch (e) {
          done.completeError(e);
        } finally {
          input.remove();
        }
      }();
    }).toJS;
    input.addEventListener(
        'cancel',
        ((web.Event e) {
          if (!done.isCompleted) done.complete(null);
          input.remove();
        }).toJS);
    input.click();
    return done.future;
  }

  static Future<void> startRecording() async {
    await stopPlayback();
    final token = ++_captureToken;
    _stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart;
    if (token != _captureToken) {
      _stream?.getTracks().toDart.forEach((t) => t.stop());
      _stream = null;
      throw StateError("Recording cancelled.");
    }
    _chunks.clear();
    _recordDone = Completer<VoiceClip?>();
    final mime = web.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : web.MediaRecorder.isTypeSupported('audio/mp4')
            ? 'audio/mp4'
            : '';
    try {
      _recorder =
          web.MediaRecorder(_stream!, web.MediaRecorderOptions(mimeType: mime));
      _recorder!.ondataavailable = ((web.BlobEvent e) {
        if (e.data.size > 0) _chunks.add(e.data);
      }).toJS;
      _recorder!.onstop = ((web.Event e) {
        () async {
          try {
            final blob = web.Blob(_chunks.map<JSAny>((b) => b).toList().toJS,
                web.BlobPropertyBag(type: _recorder?.mimeType ?? mime));
            if (blob.size > 5 * 1024 * 1024) {
              throw StateError('Record a shorter clip (up to 5 MB).');
            }
            _recordDone?.complete(VoiceClip(await _read(blob), 'My recording'));
          } catch (error) {
            _recordDone?.completeError(error);
          } finally {
            _stream?.getTracks().toDart.forEach((track) => track.stop());
            _stream = null;
            _recorder = null;
          }
        }();
      }).toJS;
      _recorder!.onerror = ((web.Event e) {
        if (_recordDone != null && !_recordDone!.isCompleted) {
          _recordDone!.completeError(
              StateError('Recording was interrupted. Please try again.'));
        }
        _stream?.getTracks().toDart.forEach((track) => track.stop());
        _stream = null;
        _recorder = null;
      }).toJS;
      _recorder!.start();
    } catch (_) {
      _stream?.getTracks().toDart.forEach((track) => track.stop());
      _stream = null;
      _recorder = null;
      _recordDone = null;
      rethrow;
    }
  }

  static Future<VoiceClip?> stopRecording() async {
    final done = _recordDone;
    if (done == null) return null;
    if (_recorder?.state == 'recording') _recorder!.stop();
    return done.future;
  }

  static Future<void> cancelRecording() async {
    _captureToken++;
    try {
      await stopRecording();
    } catch (_) {}
    _recordDone = null;
  }

  static Future<void> deleteClip(String uri) async {}
  static Future<void> stopPlayback() async {
    _playToken++;
    if (_speechDone != null && !_speechDone!.isCompleted) {
      _speechDone!.complete();
    }
    _speechDone = null;
    _audio?.pause();
    _audio?.src = '';
    _audio = null;
    if (_audioDone != null && !_audioDone!.isCompleted) _audioDone!.complete();
    _audioDone = null;
    web.window.speechSynthesis.cancel();
  }

  static Future<void> playClip(String uri, double volume) async {
    await stopPlayback();
    await _play(uri, volume, _playToken);
  }

  static Future<void> _play(String uri, double volume, int token) async {
    if (token != _playToken) return;
    final done = Completer<void>();
    _audioDone = done;
    final player = web.HTMLAudioElement()
      ..src = uri
      ..volume = volume;
    _audio = player;
    player.onended = ((web.Event e) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    player.onerror = ((web.Event e) {
      if (!done.isCompleted) {
        done.completeError(StateError('Could not play this audio clip.'));
      }
    }).toJS;
    try {
      await player.play().toDart;
      await done.future.timeout(const Duration(seconds: 65));
    } finally {
      if (identical(_audio, player)) {
        player.pause();
        _audio = null;
        _audioDone = null;
      }
    }
  }

  static Future<void> say(Pet pet, String text, String kind) async {
    if (!pet.voiceEnabled) return;
    await stopPlayback();
    final token = _playToken;
    final clip = pet.clip(kind);
    if (clip.isNotEmpty) await _play(clip, pet.volume, token);
    if (token != _playToken || (clip.isNotEmpty && !pet.readText)) return;
    final done = Completer<void>();
    _speechDone = done;
    final utterance = web.SpeechSynthesisUtterance(text)
      ..volume = pet.volume
      ..rate = pet.rate
      ..pitch = pet.pitch;
    utterance.onend = ((web.Event e) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    utterance.onerror = ((web.Event e) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    web.window.speechSynthesis.speak(utterance);
    await done.future.timeout(const Duration(seconds: 60),
        onTimeout: () => web.window.speechSynthesis.cancel());
    if (identical(_speechDone, done)) _speechDone = null;
  }
}
