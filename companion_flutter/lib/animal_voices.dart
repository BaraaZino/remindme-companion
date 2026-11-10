import 'dart:math';
import 'animal_catalog.dart';
import 'companion_model.dart';

class AnimalVoice {
  const AnimalVoice(this.id, this.label, this.description);
  final String id, label, description;
}

/// Styles are sound-designed versions of licensed sources, not voice cloning.
List<AnimalVoice> voicesFor(String animal) {
  final call = switch (animal) {
    'cat' => 'meows',
    'dog' => 'barks',
    'bunny' => 'nibbles',
    'fox' => 'yips',
    'bear' => 'grumbles',
    'panda' => 'squeaks',
    'frog' => 'croaks',
    'penguin' => 'calls',
    'owl' => 'hoots',
    'monkey' => 'chatters',
    _ => 'chirps',
  };
  return [
    AnimalVoice('soft', 'Soft $call', 'A gentle, higher voice'),
    AnimalVoice('bright', 'Bright $call', 'A playful, lively voice'),
    AnimalVoice('deep', 'Low $call', 'A warm, lower voice'),
  ];
}

/// Kept outside Pet: playback must never rewrite a saved recording or profile.
class AnimalVoicePicker {
  AnimalVoicePicker({Random? random}) : _random = random ?? Random();
  final Random _random;
  final Map<String, int> _last = {};
  String pick(String petId, String animal, String preset) {
    final supportedAnimal = animalDesign(animal).id;
    final key = '$petId/$supportedAnimal/$preset';
    final previous = _last[key];
    var index = _random.nextInt(previous == null ? 3 : 2);
    if (previous != null && index >= previous) index++;
    _last[key] = index;
    return 'asset:assets/audio/animal_voices/${supportedAnimal}_${preset}_${index + 1}.mp3';
  }
}

class AnimalVoices {
  static final _picker = AnimalVoicePicker();
  static bool isPreset(String id) =>
      const ['soft', 'bright', 'deep'].contains(id);
  static String clip(Pet pet, String kind) {
    if (isPreset(pet.voicePreset)) {
      return _picker.pick(pet.id, pet.animal, pet.voicePreset);
    }
    if (pet.voicePreset == 'system') return '';
    return pet.clip(kind);
  }

  static String preview(Pet pet, String preset) =>
      _picker.pick('preview-${pet.id}', pet.animal, preset);
  static String summary(Pet pet) {
    if (!pet.voiceEnabled) return 'Quiet visits · Voice off';
    if (isPreset(pet.voicePreset)) {
      return '${voicesFor(pet.animal).firstWhere((v) => v.id == pet.voicePreset).label} · 3 random clips';
    }
    return pet.voicePreset != 'system' &&
            (pet.taskClip.isNotEmpty || pet.timerClip.isNotEmpty)
        ? 'Voice on · My recordings'
        : 'Voice on · System voice';
  }
}
