import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'companion_model.dart';
import 'pixel_cat.dart';
import 'animal_catalog.dart';
import 'animal_voices.dart';
import 'app_style.dart';
import 'companion_editor.dart';
import 'visit_overlay.dart';
import 'task_widget_preview.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RemindMeApp());
}

class RemindMeApp extends StatefulWidget {
  const RemindMeApp({super.key, this.model});
  final CompanionModel? model;
  @override
  State<RemindMeApp> createState() => _RemindMeAppState();
}

class _RemindMeAppState extends State<RemindMeApp> with WidgetsBindingObserver {
  bool foreground = true;
  late final CompanionModel model = widget.model ?? CompanionModel();
  final visits = VisitController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!model.loaded) {
      model.load().then((_) {
        if (mounted) model.loadApps();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == foreground) return;
    visits.setForeground(active);
    setState(() => foreground = active);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    visits.dispose();
    if (widget.model == null) model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RemindMe · your companions',
      theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Nunito',
          scaffoldBackgroundColor: cream,
          colorScheme: ColorScheme.fromSeed(seedColor: green, surface: cream),
          textTheme: ThemeData.light()
              .textTheme
              .apply(fontFamily: 'Nunito', bodyColor: ink, displayColor: ink),
          appBarTheme: const AppBarTheme(
              backgroundColor: cream,
              foregroundColor: ink,
              surfaceTintColor: Colors.transparent),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)))),
          dialogTheme: const DialogThemeData(backgroundColor: cream)),
      builder: (context, child) =>
          VisitHost(controller: visits, foreground: foreground, child: child!),
      home: CompanionHome(model: model, visits: visits));
}

class CompanionHome extends StatefulWidget {
  const CompanionHome({super.key, required this.model, required this.visits});
  final CompanionModel model;
  final VisitController visits;
  @override
  State<CompanionHome> createState() => _CompanionHomeState();
}

class _CompanionHomeState extends State<CompanionHome>
    with WidgetsBindingObserver {
  CompanionModel get model => widget.model;
  int page = 0;
  String filter = 'Today';
  late final Timer reminders;
  StreamSubscription<dynamic>? nativeVisits;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (isAndroid) {
      nativeVisits = const EventChannel('remindme/visits')
          .receiveBroadcastStream()
          .listen((raw) {
        if (!foreground || !model.running || !mounted) return;
        final event = Map<String, dynamic>.from(raw as Map);
        Task? task;
        for (final item in model.tasks) {
          if (item.id == event['taskId'] && !item.done) task = item;
        }
        if (event['taskId'] != null && task == null) return;
        visit(model.pet(event['petId'] as String?),
            event['kind'] as String? ?? 'task',
            text: event['text'] as String?, task: task);
      }, onError: (_) {});
    }
    reminders = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isAndroid || !model.loaded || !foreground) return;
      for (final task in model.tasks) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (task.nextReminder != null && task.nextReminder! <= now) {
          task.lastReminderAt = now;
          task.snoozeUntil = 0;
          task.reminded = task.due <= now;
          model.save();
          if (model.running) {
            visit(model.pet(task.companionId), 'task',
                text: 'A little reminder: ${task.title}', task: task);
          }
          break;
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground && isAndroid) model.load();
  }

  @override
  void dispose() {
    reminders.cancel();
    nativeVisits?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> visit(Pet pet, String kind, {String? text, Task? task}) async {
    text ??= kind == 'timer'
        ? 'We’ve been scrolling for a while. A stretch, or one small step?'
        : 'Hi, I’m ${pet.name}. A little step is waiting. Let’s make room for it.';
    widget.visits.add(VisitRequest(
        pet: pet.copy(),
        text: text,
        kind: kind,
        taskId: task?.id,
        onDone: () {
          if (task != null) {
            final matches =
                model.tasks.where((t) => t.id == task.id && !t.done);
            if (matches.isNotEmpty) model.toggle(matches.first);
          }
        },
        onSnooze: () {
          if (task != null) model.snooze(task);
        }));
  }

  Future<void> setEnabled(bool enabled) async {
    if (!isAndroid) {
      model.running = enabled;
      await model.save();
    } else {
      await model.action(enabled ? 'start' : 'stop');
    }
    if (!enabled) widget.visits.clear();
  }

  void editPet(Pet pet, {bool isNew = false}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => CompanionEditor(
              model: model,
              pet: pet,
              isNew: isNew,
              onPreview: (p, k) => visit(p, k),
              visits: widget.visits)));

  Widget petArt(Pet p, {double size = 62, bool walking = false}) => PixelCat(
      size: size,
      animal: p.animal,
      name: p.name,
      color: p.color,
      accent: p.accent,
      walking: walking);
  String dueLabel(Task task) {
    if (task.due == 0) return 'No reminder';
    final due = DateTime.fromMillisecondsSinceEpoch(task.due);
    return '${DateUtils.isSameDay(due, DateTime.now()) ? 'Today' : MaterialLocalizations.of(context).formatShortDate(due)} · ${TimeOfDay.fromDateTime(due).format(context)}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: model,
      builder: (context, _) => Scaffold(
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: !model.loaded
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              key: ValueKey(page),
                              padding:
                                  const EdgeInsets.fromLTRB(24, 24, 24, 100),
                              children: [
                                  const Padding(
                                      padding: EdgeInsets.only(bottom: 26),
                                      child: Text('remindme.',
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -1))),
                                  if (model.error != null)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 14),
                                        child: Text(model.error!,
                                            style: const TextStyle(
                                                color: Color(0xFFA34F3E)))),
                                  if (page == 0)
                                    ...tasksPage()
                                  else if (page == 1)
                                    ...companionsPage()
                                  else
                                    ...timersPage()
                                ])))),
          floatingActionButton: page == 0
              ? FloatingActionButton.extended(
                  tooltip: 'Add a task',
                  onPressed: () => editTask(),
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add task'))
              : null,
          bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: line))),
              child: NavigationBar(
                  selectedIndex: page,
                  onDestinationSelected: (value) =>
                      setState(() => page = value),
                  backgroundColor: cream,
                  indicatorColor: mint,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.checklist_rounded), label: 'Tasks'),
                    NavigationDestination(
                        icon: Icon(Icons.pets_outlined),
                        selectedIcon: Icon(Icons.pets_rounded),
                        label: 'Companions'),
                    NavigationDestination(
                        icon: Icon(Icons.hourglass_bottom_rounded),
                        label: 'App timers')
                  ]))));
  List<Widget> tasksPage() {
    final tasks = model.visibleTasks(filter);
    return [
      pageTitle(
          'A little company. A little more done.',
          'Your day, a little lighter.',
          'Choose a companion for each small step. They’ll visit when it’s time.'),
      Wrap(
          spacing: 8,
          runSpacing: 6,
          children: ['Today', 'All tasks', 'Done']
              .map((value) => ChoiceChip(
                  label: Text(value),
                  selected: filter == value,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => filter = value)))
              .toList()),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
            child: sectionTitle(filter == 'Done'
                ? 'Little wins, collected'
                : 'Your small steps')),
        Text('${tasks.length}', style: const TextStyle(color: muted))
      ]),
      if (tasks.isEmpty)
        panel(const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.spa_outlined, color: green),
              SizedBox(height: 12),
              Text('A little room to begin.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('Your companion will help you remember what matters.',
                  style: TextStyle(color: muted, height: 1.5))
            ]))
      else
        ...tasks.map(taskTile),
      const SizedBox(height: 16),
      OutlinedButton.icon(
          onPressed: openCalendars,
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Connect phone calendar')),
      const SizedBox(height: 8),
      OutlinedButton.icon(
          onPressed: openWidget,
          icon: const Icon(Icons.widgets_outlined, size: 18),
          label: const Text('Home-screen widget')),
      if (model.demo && kIsWeb)
        TextButton(
            onPressed: model.clearDemo,
            child: const Text('Clear example tasks',
                style: TextStyle(fontSize: 11))),
    ];
  }

  Widget taskTile(Task task) {
    final pet = model.pet(task.companionId);
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: const Color(0xFFFFFEFA),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: line)),
          child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => editTask(original: task),
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 14, 14, 14),
                  child: Row(children: [
                    Checkbox(
                        value: task.done,
                        semanticLabel: 'Complete ${task.title}',
                        onChanged: (_) => model.toggle(task),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6))),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(task.title,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  decoration: task.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.done ? muted : ink)),
                          const SizedBox(height: 7),
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            Text(task.list,
                                style: const TextStyle(
                                    fontSize: 11, color: green)),
                            Text(dueLabel(task),
                                style:
                                    const TextStyle(fontSize: 11, color: muted))
                          ]),
                          if (task.calendarError.isNotEmpty)
                            Text(
                                'Calendar needs attention: ${task.calendarError}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.red)),
                          if (task.calendarEventId != 0 &&
                              task.calendarError.isEmpty)
                            const Text('Linked to calendar',
                                style: TextStyle(fontSize: 11, color: green)),
                          const SizedBox(height: 5),
                          Row(children: [
                            petArt(pet, size: 25),
                            const SizedBox(width: 5),
                            Expanded(
                                child: Text('Reminds with ${pet.name}',
                                    style: const TextStyle(
                                        fontSize: 11, color: muted)))
                          ]),
                        ])),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: muted),
                  ]))),
        ));
  }

  Future<void> openCalendars() async {
    await model.connectCalendars();
    if (!mounted) return;
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Phone calendars'),
                content: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(model.calendarMessage ?? ''),
                      const SizedBox(height: 12),
                      ...model.calendars.map((c) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(c['name'] as String? ?? 'Calendar'),
                          subtitle: Text(c['account'] as String? ?? ''))),
                      const Text(
                          'Dated tasks are calendar events, not Microsoft To Do entries. '
                          'Edits made in the calendar do not update RemindMe. '
                          'Enable Outlook’s Sync calendars option if its calendar is missing.')
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'))
                ]));
  }

  void openWidget() => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Home-screen widget')),
                body: SafeArea(
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: ListView(
                                padding: const EdgeInsets.all(24),
                                children: [
                                  TaskWidgetPreview(
                                      model: model,
                                      onAdd: () => editTask(quick: true)),
                                  const SizedBox(height: 20),
                                  if (isAndroid)
                                    FilledButton.icon(
                                        onPressed: () =>
                                            model.action('pinWidget'),
                                        icon: const Icon(
                                            Icons.add_to_home_screen),
                                        label:
                                            const Text('Add to home screen')),
                                  const SizedBox(height: 16),
                                  Text(
                                      kIsWeb
                                          ? 'Interactive preview. The real widget lives on your Android home screen.'
                                          : 'Add RemindMe tasks from your home screen’s Widgets picker. Then long-press the widget and drag its side or bottom handles to resize it. The launcher controls the available sizes.',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: muted,
                                          height: 1.6)),
                                ])))),
              )));
  List<Widget> companionsPage() => [
        pageTitle('A friend for different parts of your day', 'Your companions',
            'Name them, make them yours, and decide what each one reminds you about.'),
        panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable companion visits',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              subtitle: Text(
                  model.running
                      ? 'Pets visit while you use RemindMe. Background reminders use notifications.'
                      : 'Turn on reminder visits inside RemindMe.',
                  style: const TextStyle(fontSize: 12, color: muted)),
              value: model.running,
              onChanged: setEnabled),
          const SizedBox(height: 6),
          const Text(
              'Companions appear only inside this app. They hide and stop speaking when you leave it.',
              style: TextStyle(fontSize: 12, color: muted, height: 1.6)),
        ])),
        FilledButton.icon(
            onPressed: () => editPet(
                Pet(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: 'New friend',
                    animal: 'dog',
                    voicePreset: 'soft',
                    color: 0xFFB88C67,
                    accent: 0xFFF1DCC0),
                isNew: true),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add companion')),
        const SizedBox(height: 16),
        ...model.pets.map(companionCard),
        const SizedBox(height: 10),
        if (isAndroid)
          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            sectionTitle('Permissions'),
            permission('Task notifications', model.notificationsAllowed,
                'notificationPermission'),
            permission('Precise reminder timing', model.exactAllowed,
                'exactPermission')
          ]))
        else
          panel(const Text(
              'Visits stay inside RemindMe on every device. Record or import voice clips when your browser allows it.',
              style: TextStyle(fontSize: 12, color: muted, height: 1.6))),
      ];
  Widget companionCard(Pet pet) {
    final tasks =
        model.tasks.where((t) => t.companionId == pet.id && !t.done).length;
    final timers = model.timers.where((r) => r.companionId == pet.id).length;
    return panel(
        Column(children: [
          Row(children: [
            petArt(pet, size: 88, walking: false),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(pet.name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(
                      '${animalDesign(pet.animal).label} · $tasks ${tasks == 1 ? 'task' : 'tasks'} · $timers ${timers == 1 ? 'timer' : 'timers'}',
                      style: const TextStyle(fontSize: 12, color: muted))
                ])),
            IconButton(
                tooltip: 'Settings for ${pet.name}',
                onPressed: () => editPet(pet),
                icon: const Icon(Icons.tune_rounded, color: green))
          ]),
          const SizedBox(height: 10),
          Align(
              alignment: Alignment.centerLeft,
              child: Text(AnimalVoices.summary(pet),
                  style: const TextStyle(fontSize: 12, color: muted))),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                    onPressed: () => editPet(pet),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Customize')),
                OutlinedButton.icon(
                    onPressed: () => visit(pet, 'task'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Test visit')),
                TextButton(
                    onPressed: pet.id == model.defaultCompanion
                        ? null
                        : () {
                            model.defaultCompanion = pet.id;
                            model.save();
                          },
                    child: Text(pet.id == model.defaultCompanion
                        ? 'Default for new tasks'
                        : 'Make default'))
              ]),
        ]),
        color:
            pet.id == model.defaultCompanion ? mint : const Color(0xFFFFFEFA));
  }

  Widget permission(String title, bool allowed, String action) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text(allowed ? 'Allowed' : 'Tap to set up',
          style: const TextStyle(fontSize: 11, color: muted)),
      trailing: Icon(
          allowed ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
          color: green,
          size: 20),
      onTap: () => model.action(action));
  List<Widget> timersPage() => [
        pageTitle('A gentler way to put the phone down', 'App timers',
            'Choose the apps, the time limit, and the companion who checks in.'),
        if (isAndroid)
          panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            permission(
                'App-usage access', model.usageAllowed, 'usagePermission'),
            if (!model.running)
              TextButton.icon(
                  onPressed: () => setState(() => page = 1),
                  icon: const Icon(Icons.pets_outlined, size: 17),
                  label: const Text('Enable visits in Companions'))
          ]))
        else
          panel(const Text(
              'Browser preview: choose example apps and preview the visit. Real usage tracking runs on Android while companion visits are enabled.',
              style: TextStyle(fontSize: 12, color: muted, height: 1.6))),
        if (model.timers.isEmpty)
          panel(const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hourglass_empty_rounded, color: green),
                SizedBox(height: 10),
                Text('Make room for a little break.',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text(
                    'Start a timer for the apps you want a gentle nudge about.',
                    style: TextStyle(color: muted, height: 1.5))
              ])),
        ...model.timers.map(timerCard),
        FilledButton.icon(
            onPressed: () => editTimer(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add app timer')),
        const SizedBox(height: 18),
        const Text(
            'Time counts continuously across each timer’s chosen apps. Leaving those apps or locking your phone resets that timer.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.6)),
      ];
  Widget timerCard(TimerRule rule) {
    final pet = model.pet(rule.companionId);
    return panel(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(rule.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800))),
            Switch(
                value: rule.enabled,
                onChanged: (v) {
                  rule.enabled = v;
                  model.save();
                })
          ]),
          Text('${rule.minutes} continuous minutes · ${pet.name}',
              style: const TextStyle(
                  color: green, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
              spacing: 6,
              runSpacing: 4,
              children: rule.apps
                  .map((app) => Chip(
                      label: Text(model.appName(app),
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact))
                  .toList()),
          Wrap(spacing: 8, children: [
            TextButton.icon(
                onPressed: () => editTimer(rule),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit timer')),
            TextButton.icon(
                onPressed: () => visit(pet, 'timer',
                    text:
                        '${pet.name} here. Time for a little break from ${rule.name}?'),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Test visit'))
          ]),
        ]),
        color:
            rule.enabled ? const Color(0xFFFFFEFA) : const Color(0xFFEFEFE7));
  }

  Future<void> editTimer([TimerRule? original]) async {
    if (model.apps.isEmpty) await model.loadApps();
    if (!mounted) return;
    final rule = original?.copy() ??
        TimerRule(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            companionId: model.defaultCompanion);
    final title = TextEditingController(text: rule.name);
    String? error;
    await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, local) => AlertDialog(
                    title: Text(original == null
                        ? 'A new app timer'
                        : 'Edit app timer'),
                    content: SizedBox(
                        width: 420,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              TextField(
                                  controller: title,
                                  maxLength: 40,
                                  decoration: const InputDecoration(
                                      labelText: 'Timer name')),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                  initialValue: rule.companionId,
                                  decoration: const InputDecoration(
                                      labelText: 'Companion'),
                                  items: model.pets
                                      .map((pet) => DropdownMenuItem(
                                          value: pet.id, child: Text(pet.name)))
                                      .toList(),
                                  onChanged: (id) {
                                    if (id != null) {
                                      local(() => rule.companionId = id);
                                    }
                                  }),
                              const SizedBox(height: 20),
                              settingSlider(
                                  'Nudge after',
                                  rule.minutes.toDouble(),
                                  5,
                                  120,
                                  (v) => local(() => rule.minutes = v.round()),
                                  display: '${rule.minutes} minutes',
                                  divisions: 115),
                              OutlinedButton.icon(
                                  onPressed: () async {
                                    final selected =
                                        await chooseApps(rule.apps);
                                    if (selected != null) {
                                      local(() => rule.apps = selected);
                                    }
                                  },
                                  icon:
                                      const Icon(Icons.apps_rounded, size: 18),
                                  label: Text(rule.apps.isEmpty
                                      ? 'Choose apps'
                                      : '${rule.apps.length} apps selected')),
                              if (rule.apps.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                        rule.apps.map(model.appName).join(', '),
                                        style: const TextStyle(
                                            fontSize: 12, color: muted))),
                              if (error != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(error!,
                                        style: const TextStyle(
                                            color: Color(0xFFA34F3E))))
                            ]))),
                    actions: [
                      if (original != null)
                        TextButton(
                            onPressed: () async {
                              await model.removeTimer(rule.id);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text('Delete')),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () async {
                            if (title.text.trim().isEmpty ||
                                rule.apps.isEmpty) {
                              local(() => error =
                                  'Give the timer a name and choose at least one app.');
                              return;
                            }
                            rule.name = title.text.trim();
                            await model.saveTimer(rule);
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text('Save timer'))
                    ])));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    title.dispose();
  }

  Future<Set<String>?> chooseApps(Set<String> current) async {
    final selected = Set<String>.of(current);
    String search = '';
    return showDialog<Set<String>>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, local) => AlertDialog(
                    title: const Text('Choose apps to watch'),
                    content: SizedBox(
                        width: 400,
                        height: 370,
                        child: Column(children: [
                          TextField(
                              decoration: const InputDecoration(
                                  hintText: 'Search apps',
                                  prefixIcon: Icon(Icons.search)),
                              onChanged: (v) =>
                                  local(() => search = v.toLowerCase())),
                          const SizedBox(height: 10),
                          Expanded(
                              child: ListView(
                                  children: model.apps
                                      .where((app) => app['name']!
                                          .toLowerCase()
                                          .contains(search))
                                      .map((app) => CheckboxListTile(
                                          value:
                                              selected.contains(app['package']),
                                          title: Text(app['name']!),
                                          onChanged: (v) => local(() {
                                                if (v == true) {
                                                  selected.add(app['package']!);
                                                } else {
                                                  selected
                                                      .remove(app['package']);
                                                }
                                              })))
                                      .toList()))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, selected),
                          child: const Text('Use selected apps'))
                    ])));
  }

  Future<void> editTask({Task? original, bool quick = false}) async {
    final name = TextEditingController(text: original?.title),
        list = TextEditingController(text: original?.list ?? 'Personal');
    final taskId =
        original?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    String petId = original?.companionId ?? model.defaultCompanion;
    int dailyDays = original?.dailyDays ?? 3;
    int calendarId = original?.calendarId ?? 0;
    final offsets = TextEditingController(
        text: original == null
            ? '3, 1'
            : original.reminderOffsets
                .where((m) => m > 0)
                .map((m) =>
                    (m / 60).toString().replaceFirst(RegExp(r'\.0$'), ''))
                .join(', '));
    DateTime? due = original == null || original.due == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(original.due);
    String? error;
    await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, local) => AlertDialog(
                    title: Text(original == null
                        ? 'A new small step'
                        : 'Edit your task'),
                    content: SizedBox(
                        width: 400,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              TextField(
                                  controller: name,
                                  autofocus: true,
                                  maxLength: 200,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                      labelText:
                                          'What would you like to get done?',
                                      errorText: error)),
                              const SizedBox(height: 12),
                              TextField(
                                  controller: list,
                                  maxLength: 40,
                                  decoration:
                                      const InputDecoration(labelText: 'List')),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                  initialValue: petId,
                                  decoration: const InputDecoration(
                                      labelText: 'Reminder companion'),
                                  items: model.pets
                                      .map((p) => DropdownMenuItem(
                                          value: p.id, child: Text(p.name)))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      local(() => petId = value);
                                    }
                                  }),
                              if (!quick) ...[
                                const SizedBox(height: 12),
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                        Icons.notifications_none_rounded),
                                    title: Text(
                                        due == null
                                            ? 'Set deadline and reminders'
                                            : '${MaterialLocalizations.of(context).formatShortDate(due!)} · ${TimeOfDay.fromDateTime(due!).format(context)}',
                                        style: const TextStyle(fontSize: 13)),
                                    trailing: due == null
                                        ? const Icon(Icons.add, size: 18)
                                        : IconButton(
                                            tooltip: 'Clear deadline',
                                            onPressed: () =>
                                                local(() => due = null),
                                            icon: const Icon(Icons.close,
                                                size: 17)),
                                    onTap: () async {
                                      final now = DateTime.now(),
                                          initial = due != null &&
                                                  due!.isAfter(DateTime.now())
                                              ? due!
                                              : DateTime.now();
                                      final date = await showDatePicker(
                                          context: context,
                                          initialDate: initial,
                                          firstDate: DateUtils.dateOnly(now),
                                          lastDate: DateTime(now.year + 10));
                                      if (date == null || !context.mounted) {
                                        return;
                                      }
                                      final time = await showTimePicker(
                                          context: context,
                                          initialTime:
                                              TimeOfDay.fromDateTime(initial));
                                      if (time != null) {
                                        local(() => due = DateTime(
                                            date.year,
                                            date.month,
                                            date.day,
                                            time.hour,
                                            time.minute));
                                      }
                                    }),
                                if (due != null) ...[
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<int>(
                                      isExpanded: true,
                                      initialValue: dailyDays,
                                      decoration: const InputDecoration(
                                          labelText: 'Daily reminders start'),
                                      items: ({
                                        0,
                                        1,
                                        2,
                                        3,
                                        5,
                                        7,
                                        14,
                                        30,
                                        dailyDays
                                      }.toList()
                                            ..sort())
                                          .map((d) => DropdownMenuItem(
                                              value: d,
                                              child: Text(d == 0
                                                  ? 'No daily reminders'
                                                  : '$d days before')))
                                          .toList(),
                                      onChanged: (v) =>
                                          local(() => dailyDays = v ?? 0)),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'Daily reminders use the deadline’s time of day. A reminder is also sent at the deadline.',
                                      style: TextStyle(fontSize: 12)),
                                  TextField(
                                      controller: offsets,
                                      decoration: const InputDecoration(
                                          labelText:
                                              'Extra reminders (hours before)',
                                          hintText: '3, 1, 0.5',
                                          helperMaxLines: 2,
                                          helperText:
                                              'Separate hours with commas; 0.5 means 30 minutes.')),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                      onPressed: () async {
                                        await model.connectCalendars();
                                        if (context.mounted) local(() {});
                                      },
                                      icon: const Icon(
                                          Icons.calendar_month_outlined),
                                      label: const Text('Connect calendars')),
                                  if (model.calendarMessage != null)
                                    Text(model.calendarMessage!,
                                        style: const TextStyle(fontSize: 12)),
                                  DropdownButtonFormField<int>(
                                      key: ValueKey(
                                          'calendar-${model.calendars.length}-$calendarId'),
                                      initialValue: calendarId,
                                      decoration: const InputDecoration(
                                          labelText: 'Put task in calendar'),
                                      isExpanded: true,
                                      items: [
                                        const DropdownMenuItem(
                                            value: 0,
                                            child: Text('No calendar')),
                                        if (calendarId != 0 &&
                                            !model.calendars.any(
                                                (c) => c['id'] == calendarId))
                                          DropdownMenuItem(
                                              value: calendarId,
                                              child: const Text(
                                                  'Previously linked calendar')),
                                        ...model.calendars.map((c) =>
                                            DropdownMenuItem(
                                                value: (c['id'] as num).toInt(),
                                                child: Text(
                                                    '${c['name']} · ${c['account']}',
                                                    overflow:
                                                        TextOverflow.ellipsis)))
                                      ],
                                      onChanged: (v) =>
                                          local(() => calendarId = v ?? 0)),
                                  const Text(
                                      'Saved as a 15-minute calendar event at the deadline. RemindMe handles repeated reminders. Calendar edits do not sync back.',
                                      style: TextStyle(fontSize: 12)),
                                  if (original?.calendarError.isNotEmpty ==
                                      true)
                                    Text(original!.calendarError,
                                        style:
                                            const TextStyle(color: Colors.red))
                                ]
                              ]
                            ]))),
                    actions: [
                      if (original != null)
                        TextButton(
                            onPressed: () async {
                              await model.remove(original);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text('Delete')),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () async {
                            if (name.text.trim().isEmpty) {
                              local(() => error = 'Give your task a name.');
                              return;
                            }
                            if (due != null &&
                                due!.millisecondsSinceEpoch != original?.due &&
                                !due!.isAfter(DateTime.now())) {
                              local(() =>
                                  error = 'Choose a future reminder time.');
                              return;
                            }
                            final parsedOffsets = <int>[];
                            for (final part in offsets.text.split(',')) {
                              if (part.trim().isEmpty) continue;
                              final hours = double.tryParse(part.trim());
                              if (hours == null ||
                                  !hours.isFinite ||
                                  hours < 0 ||
                                  hours > 720 ||
                                  parsedOffsets.length >= 32) {
                                local(() => error =
                                    'Use up to 32 reminder offsets between 0 and 720 hours.');
                                return;
                              }
                              parsedOffsets.add((hours * 60).round());
                            }
                            await model.upsert(Task(
                                id: taskId,
                                title: name.text.trim(),
                                list: list.text.trim().isEmpty
                                    ? 'Personal'
                                    : list.text.trim(),
                                companionId: petId,
                                due: due?.millisecondsSinceEpoch ?? 0,
                                dailyDays: due == null ? 0 : dailyDays,
                                reminderOffsets: due == null
                                    ? []
                                    : (parsedOffsets.toSet().toList()..sort()),
                                calendarId: due == null ? 0 : calendarId,
                                calendarEventId: original?.calendarEventId ?? 0,
                                lastReminderAt: original?.lastReminderAt ?? 0,
                                reminderFrom: original?.reminderFrom ?? 0,
                                snoozeUntil: original?.snoozeUntil ?? 0,
                                done: original?.done ?? false,
                                reminded: original != null &&
                                        (due?.millisecondsSinceEpoch ?? 0) ==
                                            original.due
                                    ? original.reminded
                                    : false));
                            if (model.error != null) {
                              local(() => error = model.error);
                              return;
                            }
                            final saved =
                                model.tasks.where((t) => t.id == taskId);
                            if (saved.isNotEmpty &&
                                saved.first.calendarError.isNotEmpty) {
                              local(() => error =
                                  'Task saved locally. ${saved.first.calendarError}');
                              return;
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                          child:
                              Text(original == null ? 'Add task' : 'Save task'))
                    ])));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    name.dispose();
    list.dispose();
    offsets.dispose();
  }
}
