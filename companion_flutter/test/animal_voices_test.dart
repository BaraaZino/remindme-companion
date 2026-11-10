import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remindme_companion/animal_catalog.dart';
import 'package:remindme_companion/animal_voices.dart';
import 'package:remindme_companion/companion_model.dart';
import 'package:remindme_companion/companion_editor.dart';
import 'package:remindme_companion/visit_overlay.dart';
import 'package:remindme_companion/voice_backend_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('All animal voice sets have 3 bundled, credited MP3 variations',
      () async {
    final manifest = jsonDecode(await rootBundle.loadString(
        'assets/audio/animal_voices/manifest.json')) as Map<String, dynamic>;
    final clips = manifest['clips'] as List;
    expect(clips.length, animalDesigns.length * 9);
    final files = clips.map((c) => c['file']).toSet();
    expect(files.length, animalDesigns.length * 9);
    for (final animal in animalDesigns) {
      final presets = voicesFor(animal.id);
      expect(presets.length, 3);
      for (final preset in presets) {
        for (var i = 1; i <= 3; i++) {
          final name = '${animal.id}_${preset.id}_$i.mp3';
          expect(files, contains(name));
          final data =
              await rootBundle.load('assets/audio/animal_voices/$name');
          expect(data.lengthInBytes, greaterThan(1000));
        }
      }
      expect((manifest['sources'] as Map)[animal.id]['license'], isNotEmpty);
    }
    final credits =
        await rootBundle.loadString('assets/audio/animal_voices/CREDITS.txt');
    expect(credits, contains('SFX by Dan Knoflicek'));
    expect(credits, contains('Wolfgang Wozniak'));
  });

  test(
      'Random clips vary, never repeat immediately, and match the animal/style',
      () {
    final picker = AnimalVoicePicker(random: Random(12));
    for (final animal in animalDesigns) {
      for (final preset in voicesFor(animal.id)) {
        String? previous;
        final heard = <String>{};
        for (var i = 0; i < 40; i++) {
          final clip = picker.pick('pet', animal.id, preset.id);
          expect(clip, isNot(previous));
          expect(
              clip,
              startsWith(
                  'asset:assets/audio/animal_voices/${animal.id}_${preset.id}_'));
          heard.add(clip);
          previous = clip;
        }
        expect(heard.length, 3);
      }
    }
  });

  test('Legacy/custom/system routing keeps original recordings intact',
      () async {
    final legacy = Pet.fromJson({
      'id': 'old',
      'taskClip': 'keep.m4a',
      'timerClip': 'timer.m4a',
      'voiceEnabled': true
    });
    expect(legacy.voicePreset, 'custom');
    expect(AnimalVoices.clip(legacy, 'task'), 'keep.m4a');
    expect(AnimalVoices.clip(legacy, 'timer'), 'timer.m4a');
    legacy.voicePreset = 'bright';
    expect(AnimalVoices.clip(legacy, 'task'), contains('cat_bright_'));
    final initial = CompanionModel();
    await initial.savePet(legacy);
    initial.dispose();
    final model = CompanionModel();
    await model.load();
    expect(model.pet('old').voicePreset, 'bright');
    expect(model.pet('old').taskClip, 'keep.m4a');
    expect(model.pet('old').timerClip, 'timer.m4a');
    legacy.voicePreset = 'system';
    expect(AnimalVoices.clip(legacy, 'task'), isEmpty);
    legacy.voicePreset = 'custom';
    expect(AnimalVoices.clip(legacy, 'task'), 'keep.m4a');
    expect(Pet.fromJson({'id': 'future', 'voicePreset': 'unknown'}).voicePreset,
        'custom');
    model.dispose();
  });

  test(
      'Native visits get a random asset override without rewriting the profile',
      () async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(CompanionModel.channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(CompanionModel.channel, null));
    final pet = Pet(
        id: 'p',
        animal: 'fox',
        voiceEnabled: true,
        voicePreset: 'deep',
        taskClip: 'my.m4a');
    await VoiceTools.say(pet, 'Take a break', 'task');
    await VoiceTools.say(pet, 'Another visit', 'timer');
    final visits = calls.where((c) => c.method == 'say').toList();
    expect(visits.length, 2);
    final one = visits[0].arguments as Map;
    final two = visits[1].arguments as Map;
    expect(
        one['clip'], startsWith('asset:assets/audio/animal_voices/fox_deep_'));
    expect(one['clip'], isNot(two['clip']));
    expect(one['profile']['taskClip'], 'my.m4a');
    expect(pet.taskClip, 'my.m4a');
    pet.voiceEnabled = false;
    await VoiceTools.say(pet, 'Silent', 'task');
    expect(calls.where((c) => c.method == 'say').length, 2);
  });

  test('Stopping during audio startup prevents a late sample from starting',
      () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final waiting = Completer<void>();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(CompanionModel.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'stopSpeech' && calls.length == 1) {
        await waiting.future;
      }
      return null;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(CompanionModel.channel, null));
    final start = VoiceTools.playClip(
        'asset:assets/audio/animal_voices/cat_soft_1.mp3', .8);
    await Future<void>.delayed(Duration.zero);
    await VoiceTools.stopPlayback();
    waiting.complete();
    await start;
    expect(calls, isNot(contains('playClip')));
  });

  testWidgets(
      'Choose a preset at phone width and keep custom recordings on save',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = CompanionModel()..loaded = true;
    final pet = model.defaultPet..taskClip = 'keep.m4a';
    final visits = VisitController();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (context) => CompanionEditor(
                                model: model,
                                pet: pet,
                                visits: visits,
                                onPreview: (profile, kind) {}))),
                    child: const Text('Open editor'))))));
    await tester.tap(find.text('Open editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('companion-section-3')).hitTestable(), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('companion-section-3')));
    await tester.pump();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('voice-option-deep')).hitTestable(), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('voice-option-deep')));
    await tester.pump();
    await tester.tap(find.text('Save companion'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(model.defaultPet.voicePreset, 'deep');
    expect(model.defaultPet.voiceEnabled, true);
    expect(model.defaultPet.taskClip, 'keep.m4a');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    visits.dispose();
    model.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
