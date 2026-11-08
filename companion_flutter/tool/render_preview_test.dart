import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remindme_companion/main.dart';
import 'package:remindme_companion/companion_model.dart';

void main() {
  testWidgets('Render the actual Flutter screens for design review',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    for (final family in ['Nunito', 'Lora', 'RobotoMono']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final model = CompanionModel()
      ..loaded = true
      ..pets.addAll([
        Pet(
            id: 'fox',
            name: 'Ember',
            animal: 'fox',
            color: 0xFFC47743,
            accent: 0xFFFFE4BB),
        Pet(
            id: 'bunny',
            name: 'Clover',
            animal: 'bunny',
            color: 0xFFB6C4BC,
            accent: 0xFFE6C2CB)
      ])
      ..tasks = [
        Task(id: 'read', title: 'Make a little room to read'),
        Task(
            id: 'walk',
            title: 'Take a walk, leave the phone',
            list: 'Wellbeing',
            companionId: 'fox')
      ]
      ..timers = [
        TimerRule(
            id: 'social',
            name: 'A scrolling break',
            minutes: 20,
            companionId: 'bunny',
            apps: {'demo.instagram', 'demo.youtube'})
      ]
      ..apps = [
        {'name': 'Instagram', 'package': 'demo.instagram'},
        {'name': 'YouTube', 'package': 'demo.youtube'}
      ];
    final key = GlobalKey();
    await tester.pumpWidget(
        RepaintBoundary(key: key, child: RemindMeApp(model: model)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    Future<void> save(String name) async {
      await tester.pump(const Duration(milliseconds: 100));
      final box =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await box.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../.tools/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await save('v03-tasks');
    await tester.tap(find
        .descendant(
            of: find.byType(NavigationBar), matching: find.text('Companions'))
        .last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await save('v03-companions');
    await tester.tap(find.byTooltip('Settings for Mochi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await save('v03-appearance');
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('record-task')), 350,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await save('v03-voices');
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find
        .descendant(
            of: find.byType(NavigationBar), matching: find.text('App timers'))
        .last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await save('v03-timers');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    debugDefaultTargetPlatformOverride = null;
    model.dispose();
  });
}
