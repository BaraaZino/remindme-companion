import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remindme_companion/companion_model.dart';
import 'package:remindme_companion/main.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });
  test(
    'Tasks and nudge choices persist after reopening the workspace',
    () async {
      final model = CompanionModel();
      await model.load();
      await model.upsert(
        Task(id: '1', title: 'Read a chapter', list: 'Personal'),
      );
      model.minutes = 35;
      model.nudges = true;
      model.watched = {'video'};
      await model.save();
      await model.toggle(model.tasks.single);
      final reopened = CompanionModel();
      await reopened.load();
      expect(reopened.tasks.single.title, 'Read a chapter');
      expect(reopened.tasks.single.done, true);
      expect(reopened.minutes, 35);
      expect(reopened.nudges, true);
      expect(reopened.watched, {'video'});
      await reopened.remove(reopened.tasks.single);
      final empty = CompanionModel();
      await empty.load();
      expect(empty.tasks, isEmpty);
    },
  );
  test(
      'Today includes overdue and undated tasks but keeps future and completed tasks separate',
      () {
    final model = CompanionModel();
    final now = DateTime.now();
    model.tasks = [
      Task(id: '1', title: 'Undated'),
      Task(
        id: '2',
        title: 'Overdue',
        due: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      ),
      Task(
        id: '3',
        title: 'Future',
        due: now.add(const Duration(days: 2)).millisecondsSinceEpoch,
      ),
      Task(id: '4', title: 'Complete', done: true),
    ];
    expect(model.visibleTasks('Today').map((t) => t.id), ['2', '1']);
    expect(model.visibleTasks('All tasks').map((t) => t.id), ['2', '3', '1']);
    expect(model.visibleTasks('Done').single.id, '4');
  });
  testWidgets('Mobile user can add a task, complete it, and find it in Done', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = CompanionModel()..loaded = true;
    await tester.pumpWidget(RemindMeApp(model: model));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField).first, 'Read a chapter');
    await tester.tap(find.text('Add step'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(model.tasks.single.title, 'Read a chapter');
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump(const Duration(milliseconds: 200));
    expect(model.tasks.single.done, true);
    await tester.tap(find.text('Done').first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Read a chapter'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  });
  test(
      'Android task mutations preserve widget-created tasks and settings never replace tasks',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final native = [Task(id: 'widget', title: 'Added on home screen').toJson()];
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
    final model = CompanionModel()..loaded = true;
    await model.upsert(Task(id: 'app', title: 'Added inside app'));
    expect(model.tasks.map((t) => t.id), ['widget', 'app']);
    await model.toggle(model.tasks.first);
    expect(model.tasks.first.done, true);
    await model.remove(model.tasks.last);
    expect(model.tasks.single.id, 'widget');
    model.minutes = 30;
    await model.save();
    final settings = calls.last.arguments as Map;
    expect(calls.last.method, 'saveState');
    expect(settings.containsKey('tasks'), false);
    expect(native.single['done'], true);
    model.dispose();
  });

  testWidgets('Widget preview can add, complete, and remove shared tasks',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = CompanionModel()
      ..loaded = true
      ..tasks = [
        Task(id: 'finish', title: 'Finish me'),
        Task(id: 'remove', title: 'Remove me')
      ];
    await tester.pumpWidget(RemindMeApp(model: model));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Home-screen widget'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Add a task'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField).first, 'From the widget');
    await tester.tap(find.text('Add task'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(model.tasks.length, 3);
    await tester.tap(find.byTooltip('Complete Finish me'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(model.visibleTasks('Done').single.title, 'Finish me');
    await tester.tap(find.byTooltip('Delete Remove me'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(model.tasks.any((t) => t.id == 'remove'), false);
    expect(model.visibleTasks('All tasks').single.title, 'From the widget');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Narrow and desktop layouts render without overflow', (
    tester,
  ) async {
    for (final size in [const Size(320, 740), const Size(1100, 820)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final model = CompanionModel()..loaded = true;
      await tester.pumpWidget(RemindMeApp(key: ValueKey(size), model: model));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Make space\nfor small wins.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Companion').first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('A kinder kind\nof reminder.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Home-screen widget'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Your tasks.\nWithin reach.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    debugDefaultTargetPlatformOverride = null;
  });
}
