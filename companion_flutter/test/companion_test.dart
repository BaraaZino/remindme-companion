import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remindme_companion/companion_model.dart';
import 'package:remindme_companion/main.dart';
import 'package:remindme_companion/visit_overlay.dart';

Future<void> nav(WidgetTester tester, String title) async {
  await tester.tap(find
      .descendant(of: find.byType(NavigationBar), matching: find.text(title))
      .last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

void screen(WidgetTester tester, {Size size = const Size(430, 1000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  debugDefaultTargetPlatformOverride = null;
}

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('Existing tasks, voice preference, and app timer migrate to Mochi',
      () async {
    SharedPreferences.setMockInitialValues({
      'remindme.workspace.v2': jsonEncode({
        'tasks': [
          {'id': 'old', 'title': 'Existing step', 'due': 0}
        ],
        'speech': true,
        'nudges': true,
        'minutes': 35,
        'watched': ['video']
      })
    });
    final model = CompanionModel();
    await model.load();
    expect(model.pets.single.id, 'mochi');
    expect(model.pets.single.voiceEnabled, true);
    expect(model.tasks.single.companionId, 'mochi');
    expect(model.timers.single.minutes, 35);
    expect(model.timers.single.apps, {'video'});
    expect(model.timers.single.companionId, 'mochi');
    model.dispose();
  });
  test(
      'Companion designs, voices, task and timer assignments persist; deletion reassigns without losing tasks',
      () async {
    final model = CompanionModel();
    await model.load();
    final pet = Pet(
        id: 'fox',
        name: 'Ember',
        animal: 'fox',
        size: 130,
        font: 'serif',
        fontSize: 22,
        entry: 'right',
        voiceEnabled: true,
        taskClip: 'data:audio/wav;base64,AA==',
        taskClipName: 'My task clip',
        timerClip: 'timer.m4a',
        timerClipName: 'A break',
        holdSeconds: 20);
    await model.savePet(pet);
    await model.upsert(Task(id: 'read', title: 'Read', companionId: 'fox'));
    await model.saveTimer(TimerRule(
        id: 'social',
        name: 'Social apps',
        companionId: 'fox',
        minutes: 45,
        apps: {'video'}));
    final restored = CompanionModel();
    await restored.load();
    expect(restored.pet('fox').toJson(), pet.toJson());
    expect(restored.tasks.single.companionId, 'fox');
    expect(restored.timers.single.companionId, 'fox');
    await restored.removePet('fox');
    expect(restored.tasks.single.title, 'Read');
    expect(restored.tasks.single.companionId, 'mochi');
    expect(restored.timers.single.companionId, 'mochi');
    await restored.removePet('mochi');
    expect(restored.pets.length, 1);
    final reopened = CompanionModel();
    await reopened.load();
    expect(reopened.tasks.single.companionId, 'mochi');
    model.dispose();
    restored.dispose();
    reopened.dispose();
  });
  test('Today, future and completed tasks stay separate', () {
    final model = CompanionModel();
    final now = DateTime.now();
    model.tasks = [
      Task(id: '1', title: 'Undated'),
      Task(
          id: '2',
          title: 'Overdue',
          due: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch),
      Task(
          id: '3',
          title: 'Future',
          due: now.add(const Duration(days: 2)).millisecondsSinceEpoch),
      Task(id: '4', title: 'Done', done: true)
    ];
    expect(model.visibleTasks('Today').map((t) => t.id), ['2', '1']);
    expect(model.visibleTasks('All tasks').map((t) => t.id), ['2', '3', '1']);
    expect(model.visibleTasks('Done').single.id, '4');
    model.dispose();
  });
  test(
      'Native mutations preserve widget tasks and pass companion assignment; settings cannot replace tasks',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final native = [Task(id: 'widget', title: 'From widget').toJson()];
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CompanionModel.channel, (call) async {
      calls.add(call);
      if (call.method == 'upsertTask') {
        native.add(Map<String, dynamic>.from(call.arguments as Map));
        return native;
      }
      if (call.method == 'completeTask') {
        final args = call.arguments as Map;
        native.firstWhere((t) => t['id'] == args['id'])['done'] = args['done'];
        return native;
      }
      if (call.method == 'deleteTask') {
        native.removeWhere((t) => t['id'] == call.arguments);
        return native;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CompanionModel.channel, null));
    final model = CompanionModel()
      ..loaded = true
      ..pets.add(Pet(id: 'bunny', name: 'Clover', animal: 'bunny'));
    await model
        .upsert(Task(id: 'app', title: 'App task', companionId: 'bunny'));
    expect(model.tasks.map((t) => t.id), ['widget', 'app']);
    expect(native.last['companionId'], 'bunny');
    await model.toggle(model.tasks.first);
    expect(model.tasks.first.done, true);
    await model.remove(model.tasks.last);
    expect(model.tasks.single.id, 'widget');
    await model.save();
    expect((calls.last.arguments as Map).containsKey('tasks'), false);
    expect((calls.last.arguments as Map)['companions'], isA<List>());
    model.dispose();
  });
  testWidgets(
      'Bottom tabs are the only page switcher; add a named fox and assign a task',
      (tester) async {
    screen(tester);
    final model = CompanionModel()..loaded = true;
    await tester.pumpWidget(RemindMeApp(model: model));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.byType(AppBar), findsNothing);
    await nav(tester, 'Companions');
    await tester.ensureVisible(find.text('Add companion'));
    await tester.pump();
    await tester.tap(find.text('Add companion'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField).first, 'Sunny');
    await tester.tap(find.text('Fox'));
    await tester.tap(find.text('Save companion'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(model.pets.last.name, 'Sunny');
    expect(model.pets.last.animal, 'fox');
    await nav(tester, 'Tasks');
    await tester.tap(find.byTooltip('Add a task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField).first, 'Read with Sunny');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Sunny').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Add task').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(model.tasks.single.companionId, model.pets.last.id);
    expect(tester.takeException(), isNull);
    await closeApp(tester);
  });
  testWidgets('App timer selects its own companion and watched apps',
      (tester) async {
    screen(tester);
    final model = CompanionModel()
      ..loaded = true
      ..pets.add(Pet(id: 'dog', name: 'Biscuit', animal: 'dog'))
      ..apps = [
        {'name': 'Video', 'package': 'video'}
      ];
    await tester.pumpWidget(RemindMeApp(model: model));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await nav(tester, 'App timers');
    await tester.ensureVisible(find.text('Add app timer'));
    await tester.tap(find.text('Add app timer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField).first, 'Evening scrolling');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Biscuit').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Choose apps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Video'));
    await tester.tap(find.text('Use selected apps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Save timer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(model.timers.single.companionId, 'dog');
    expect(model.timers.single.apps, {'video'});
    expect(model.timers.single.name, 'Evening scrolling');
    expect(tester.takeException(), isNull);
    await closeApp(tester);
  });
  testWidgets('Compact widget has header add, group subtitles, and completion',
      (tester) async {
    screen(tester);
    final model = CompanionModel()
      ..loaded = true
      ..tasks = [
        Task(id: 'finish', title: 'Finish me', list: 'Learning'),
        Task(id: 'remove', title: 'Remove me')
      ];
    await tester.pumpWidget(RemindMeApp(model: model));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.text('Home-screen widget'));
    await tester.pump();
    await tester.tap(find.text('Home-screen widget'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('My tasks'), findsOneWidget);
    expect(find.text('Learning'), findsOneWidget);
    expect(find.byTooltip('Delete Remove me'), findsNothing);
    await tester.tap(find.byTooltip('Add a task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField).first, 'From widget');
    await tester.tap(find.text('Add task').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(model.tasks.length, 3);
    await tester.tap(find.byTooltip('Complete Finish me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(model.visibleTasks('Done').single.title, 'Finish me');
    expect(model.visibleTasks('All tasks').map((t) => t.title),
        containsAll(['Remove me', 'From widget']));
    expect(tester.takeException(), isNull);
    await closeApp(tester);
  });
  testWidgets('Recorded task voice is assigned only to its companion',
      (tester) async {
    screen(tester);
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CompanionModel.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'stopRecording') {
        return {'uri': 'recorded.m4a', 'name': 'My own voice'};
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CompanionModel.channel, null));
    final model = CompanionModel()
      ..loaded = true
      ..pets.add(Pet(id: 'fox', name: 'Ember', animal: 'fox'));
    await tester.pumpWidget(RemindMeApp(model: model));
    await tester.pump();
    await nav(tester, 'Companions');
    await tester.tap(find.byTooltip('Settings for Mochi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('record-task')), 350,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('record-task')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Record').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, contains('startRecording'));
    await tester.tap(find.text('Stop & use clip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Save companion'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(model.pet('mochi').taskClip, 'recorded.m4a');
    expect(model.pet('mochi').voiceEnabled, true);
    expect(model.pet('fox').taskClip, isEmpty);
    expect(model.pet('mochi').timerClip, isEmpty);
    expect(tester.takeException(), isNull);
    await closeApp(tester);
  });

  testWidgets('Visit enters, stops with a bubble, then fully exits',
      (tester) async {
    screen(tester, size: const Size(400, 800));
    final controller = VisitController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: VisitOverlay(controller: controller))));
    await tester.pump();
    controller.add(VisitRequest(
        pet: Pet(id: 'cat', size: 64, speed: 160, holdSeconds: 5),
        text: 'One small step'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('One small step'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.current, isNull);
    expect(find.text('One small step'), findsNothing);
    expect(tester.takeException(), isNull);
    await closeApp(tester);
    controller.dispose();
  });
  test('Visit queue pauses for voice recording and resumes in order', () {
    final c = VisitController();
    final one = VisitRequest(pet: Pet(id: 'one'), text: 'One'),
        two = VisitRequest(pet: Pet(id: 'two'), text: 'Two');
    c.add(one);
    c.add(two);
    c.suspend();
    expect(c.current, isNull);
    c.resume();
    expect(c.current, one);
    c.finish();
    expect(c.current, two);
    c.finish();
    expect(c.current, isNull);
    c.dispose();
  });
  testWidgets('Three pages and companion settings fit narrow and wide layouts',
      (tester) async {
    screen(tester);
    for (final size in [const Size(320, 740), const Size(1100, 820)]) {
      tester.view.physicalSize = size;
      final model = CompanionModel()..loaded = true;
      await tester.pumpWidget(RemindMeApp(key: ValueKey(size), model: model));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await nav(tester, 'Companions');
      await tester.scrollUntilVisible(find.byTooltip('Settings for Mochi'), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(find.byTooltip('Settings for Mochi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Save companion'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await nav(tester, 'App timers');
      expect(tester.takeException(), isNull);
      await closeApp(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
