import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'companion_model.dart';
import 'pixel_cat.dart';
import 'task_widget_preview.dart';

const ink = Color(0xFF293E34);
const green = Color(0xFF42634D);
const cream = Color(0xFFF8F7F2);
const muted = Color(0xFF767F74);
const line = Color(0xFFE7E9DF);
const mint = Color(0xFFE4EBD9);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RemindMeApp());
}

class RemindMeApp extends StatelessWidget {
  const RemindMeApp({super.key, this.model});
  final CompanionModel? model;
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RemindMe · a little company',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: cream,
          colorScheme: ColorScheme.fromSeed(seedColor: green, surface: cream),
          textTheme: ThemeData.light().textTheme.apply(
                bodyColor: ink,
                displayColor: ink,
              ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          dialogTheme: const DialogThemeData(backgroundColor: cream),
        ),
        home: CompanionHome(model: model),
      );
}

class CompanionHome extends StatefulWidget {
  const CompanionHome({super.key, this.model});
  final CompanionModel? model;
  @override
  State<CompanionHome> createState() => _CompanionHomeState();
}

class _CompanionHomeState extends State<CompanionHome>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final CompanionModel model = widget.model ?? CompanionModel();
  String filter = 'Today';
  int page = 0;
  String? bubble;
  Task? bubbleTask;
  Timer? dismissTimer;
  late final Timer reminderTimer;
  final Set<String> shown = {};
  late final AnimationController stroll = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!model.loaded) model.load();
    reminderTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isAndroid || !model.loaded) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final t in model.tasks) {
        if (!t.done &&
            !t.reminded &&
            t.due > 0 &&
            t.due <= now &&
            !shown.contains(t.id)) {
          shown.add(t.id);
          t.reminded = true;
          model.save();
          speak('A little reminder: ${t.title}', task: t);
          break;
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      model.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    reminderTimer.cancel();
    stroll.dispose();
    dismissTimer?.cancel();
    if (widget.model == null) model.dispose();
    super.dispose();
  }

  void speak(String message, {Task? task}) {
    dismissTimer?.cancel();
    if (isAndroid || !model.running) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    setState(() {
      bubble = message;
      bubbleTask = task;
    });
    dismissTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) {
        setState(() {
          bubble = null;
          bubbleTask = null;
        });
      }
    });
  }

  void nextTask() {
    final pending = model.visibleTasks('All tasks');
    if (pending.isEmpty) {
      speak('All clear. A little rest counts as progress, too.');
    } else {
      speak('One small step? ${pending.first.title}', task: pending.first);
    }
  }

  Future<void> togglePet() async {
    if (isAndroid) {
      if (!model.overlayAllowed) {
        await model.action('overlayPermission');
      } else {
        await model.action(model.running ? 'stop' : 'start');
      }
    } else {
      setState(() {
        model.running = !model.running;
      });
      if (model.running) {
        speak('Hi, I’m Mochi. Let’s take today one small step at a time.');
      } else {
        setState(() {
          bubble = null;
        });
      }
    }
  }

  String dateLabel(Task t) {
    if (t.due == 0) return 'Whenever you’re ready';
    final date = DateTime.fromMillisecondsSinceEpoch(t.due);
    final now = DateTime.now();
    final today = DateUtils.isSameDay(date, now);
    final prefix = today
        ? 'Today'
        : MaterialLocalizations.of(context).formatShortDate(date);
    return '$prefix · ${TimeOfDay.fromDateTime(date).format(context)}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: model,
        builder: (context, _) {
          final wide = MediaQuery.sizeOf(context).width >= 960;
          final phone = ClipRRect(
            borderRadius: BorderRadius.circular(wide ? 32 : 0),
            child: Container(
              decoration: BoxDecoration(
                color: cream,
                border:
                    wide ? Border.all(color: const Color(0xFFDEE3D5)) : null,
                borderRadius: BorderRadius.circular(wide ? 32 : 0),
              ),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: Stack(
                    children: [
                      if (!model.loaded)
                        const Center(child: CircularProgressIndicator())
                      else
                        ListView(
                          key: ValueKey(page),
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                          children: [
                            Row(
                              children: [
                                const Flexible(
                                    child: Text(
                                  'remindme',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.1,
                                  ),
                                )),
                                const Text(
                                  '.',
                                  style: TextStyle(
                                    color: Color(0xFFD38E58),
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                    tooltip: 'Home-screen widget',
                                    onPressed: () => setState(() {
                                          page = 2;
                                        }),
                                    icon: const Icon(Icons.widgets_outlined,
                                        size: 22)),
                                IconButton(
                                  tooltip: 'Companion settings',
                                  onPressed: () => setState(() {
                                    page = 1;
                                  }),
                                  icon:
                                      const Icon(Icons.tune_rounded, size: 22),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            if (model.error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  model.error!,
                                  style:
                                      const TextStyle(color: Color(0xFFA5412C)),
                                ),
                              ),
                            if (page == 0)
                              ...dayContent()
                            else if (page == 1)
                              ...companionContent()
                            else
                              ...widgetContent(),
                          ],
                        ),
                      if (model.running && !isAndroid) previewPet(),
                    ],
                  ),
                ),
                bottomNavigationBar: SafeArea(
                  top: false,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: cream,
                      border: Border(top: BorderSide(color: line)),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: navItem('My day', Icons.wb_sunny_outlined, 0),
                        ),
                        Expanded(
                          child: navItem('Companion', Icons.pets_outlined, 1),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 50,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero),
                            onPressed: () => editTask(),
                            child: const Icon(Icons.add_rounded, size: 27),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          if (!wide) return phone;
          return Scaffold(
            backgroundColor: const Color(0xFFEDEFE7),
            body: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 330,
                        child: SingleChildScrollView(child: desktopIntro())),
                    const SizedBox(width: 64),
                    Container(
                      width: 430,
                      constraints: const BoxConstraints(maxHeight: 900),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: ink.withValues(alpha: .07),
                            blurRadius: 60,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      child: phone,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  Widget navItem(String title, IconData icon, int index) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          page = index;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: page == index ? green : muted),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: page == index ? FontWeight.w700 : FontWeight.w500,
                  color: page == index ? green : muted,
                ),
              )),
            ],
          ),
        ),
      );
  Widget eyebrow(String label, {Color color = muted}) => Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          color: color,
        ),
      );
  Widget title(String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 34,
          height: 1.08,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.3,
        ),
      );
  Widget subtitle(String label) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          label,
          style: const TextStyle(color: muted, fontSize: 14, height: 1.55),
        ),
      );

  List<Widget> dayContent() {
    final visible = model.visibleTasks(filter);
    final completed = model.tasks.where((t) => t.done).length;
    final total = model.tasks.length;
    return [
      eyebrow('A little company. A little more done.'),
      const SizedBox(height: 10),
      title('Make space\nfor small wins.'),
      subtitle('You don’t have to do it all. Just the next thing.'),
      const SizedBox(height: 24),
      mochiCard(),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(child: eyebrow('One step at a time')),
          const SizedBox(width: 8),
          Text(
            '$completed of $total done',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : completed / total,
          minHeight: 5,
          color: green,
          backgroundColor: line,
        ),
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final item in ['Today', 'All tasks', 'Done'])
            Padding(
              padding: EdgeInsets.zero,
              child: ChoiceChip(
                label: Text(item),
                selected: filter == item,
                showCheckmark: false,
                selectedColor: green,
                backgroundColor: Colors.transparent,
                side: BorderSide(color: filter == item ? green : line),
                labelStyle: TextStyle(
                  color: filter == item ? Colors.white : muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() {
                  filter = item;
                }),
              ),
            ),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
              child: Text(
            filter == 'Done' ? 'Little wins, collected' : 'Your small steps',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -.4,
            ),
          )),
          const SizedBox(width: 8),
          Text(
            '${visible.length}',
            style: const TextStyle(color: muted, fontSize: 13),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (visible.isEmpty)
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                filter == 'Done'
                    ? Icons.auto_awesome_outlined
                    : Icons.spa_outlined,
                color: green,
              ),
              const SizedBox(height: 12),
              Text(
                filter == 'Done'
                    ? 'Your first little win is waiting.'
                    : 'A little room to begin.',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                filter == 'Done'
                    ? 'Completed tasks will find a home here.'
                    : 'Add something that matters to you.\nMochi will help you remember.',
                style: const TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => editTask(),
                child: const Text('+ Add your first step'),
              ),
            ],
          ),
        )
      else
        ...visible.map(taskTile),
      const SizedBox(height: 10),
      Center(
        child: TextButton.icon(
          onPressed: () => editTask(),
          icon: const Icon(Icons.add, size: 17),
          label: const Text('A new small step', style: TextStyle(fontSize: 13)),
        ),
      ),
      if (model.demo && kIsWeb)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Example tasks · saved in this browser',
                style: TextStyle(fontSize: 10, color: muted),
              ),
              TextButton(
                onPressed: () async {
                  await model.clearDemo();
                },
                child: const Text('Clear', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      const Center(
        child: Text(
          'A gentler way to get there.',
          style: TextStyle(
            fontSize: 11,
            color: muted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    ];
  }

  Widget mochiCard() => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      eyebrow('Your little sidekick', color: green),
                      const SizedBox(height: 10),
                      const Text(
                        'Mochi is here.',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.7,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'A soft nudge.\nA friend in your corner.',
                        style:
                            TextStyle(color: green, fontSize: 13, height: 1.55),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F2DD).withValues(alpha: .65),
                          shape: BoxShape.circle,
                        ),
                      ),
                      PixelCat(size: 110, onTap: nextTask),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: model.running ? green : const Color(0xFFB2B9A1),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    model.running
                        ? 'Keeping you company'
                        : 'Ready when you are',
                    style: const TextStyle(fontSize: 11, color: green),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: togglePet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAF0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          model.running ? 'Pause' : 'Wake Mochi',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: green,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          model.running
                              ? Icons.pause_rounded
                              : Icons.arrow_forward_rounded,
                          size: 14,
                          color: green,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget taskTile(Task task) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Material(
          color: const Color(0xFFFFFEFA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
            side: const BorderSide(color: line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () => editTask(task),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 13, 12, 13),
              child: Row(
                children: [
                  Checkbox(
                    value: task.done,
                    onChanged: (_) async {
                      await model.toggle(task);
                      if (task.done) {
                        speak('Look at you go. One little win, collected.');
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    activeColor: green,
                    side:
                        const BorderSide(color: Color(0xFFC4CDBD), width: 1.5),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: task.done ? muted : ink,
                            decoration:
                                task.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: task.list == 'Wellbeing'
                                    ? const Color(0xFFF2E8DA)
                                    : const Color(0xFFEBEEE5),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                task.list,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              dateLabel(task),
                              style:
                                  const TextStyle(fontSize: 10, color: muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: Color(0xFFA0AA99),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  Widget panel(Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFA),
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );

  List<Widget> companionContent() => [
        eyebrow('A friend, not another alarm'),
        const SizedBox(height: 10),
        title('A kinder kind\nof reminder.'),
        subtitle('Make Mochi’s little nudges work for you.'),
        const SizedBox(height: 24),
        mochiCard(),
        const SizedBox(height: 20),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.hourglass_bottom_rounded,
                    size: 19,
                    color: green,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'A little less scrolling',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Switch(
                    value: model.nudges,
                    onChanged: (v) {
                      model.nudges = v;
                      model.save();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'A gentle check-in after continuous time in the apps you choose.',
                style: TextStyle(color: muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${model.minutes}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const Expanded(
                      child: Padding(
                    padding: EdgeInsets.only(left: 6, bottom: 6),
                    child: Text(
                      'minutes, then a nudge',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  )),
                ],
              ),
              Slider(
                value: model.minutes.toDouble(),
                min: 5,
                max: 120,
                divisions: 115,
                label: '${model.minutes} minutes',
                onChanged: (v) {
                  model.setMinutes(v.round());
                },
                onChangeEnd: (_) => model.save(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('5 min',
                      style: TextStyle(fontSize: 10, color: muted)),
                  const Text(
                    '120 min',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  side: const BorderSide(color: line),
                ),
                onPressed: chooseApps,
                icon: const Icon(Icons.apps_rounded, size: 18),
                label: Text(
                  model.watched.isEmpty
                      ? 'Choose apps to watch'
                      : '${model.watched.length} apps selected',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Leaving these apps or locking your phone resets the timer.',
                style: TextStyle(fontSize: 11, color: muted, height: 1.5),
              ),
            ],
          ),
        ),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.record_voice_over_outlined,
                    size: 19,
                    color: green,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Give Mochi a voice',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Switch(
                    value: model.speech,
                    onChanged: (v) {
                      model.speech = v;
                      model.save();
                    },
                  ),
                ],
              ),
              const Text(
                'Read reminders aloud using your phone’s voice.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  if (isAndroid) {
                    model.action('preview');
                  } else {
                    speak(
                      'Hey, a little check-in. Time for a stretch, or one small step?',
                    );
                  }
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                label: const Text('Try a little reminder'),
              ),
            ],
          ),
        ),
        if (isAndroid)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Room to roam',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                permissionRow(
                  'Floating pet',
                  model.overlayAllowed,
                  'overlayPermission',
                ),
                permissionRow(
                  'Task notifications',
                  model.notificationsAllowed,
                  'notificationPermission',
                ),
                permissionRow(
                  'App-usage access',
                  model.usageAllowed,
                  'usagePermission',
                ),
              ],
            ),
          ),
        if (kIsWeb)
          panel(
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Browser preview\nYou can try the interface, tasks, and Mochi here. Floating over other apps, spoken reminders, and usage tracking work on Android.',
                    style: TextStyle(fontSize: 12, color: muted, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Tap Mochi for a task. Drag the floating cat to move it; hold to pause. Your tasks stay on this device.',
            style: TextStyle(fontSize: 12, color: muted, height: 1.6),
          ),
        ),
      ];
  List<Widget> widgetContent() => [
        eyebrow('A little less opening your phone'),
        const SizedBox(height: 10),
        title('Your tasks.\nWithin reach.'),
        subtitle('Add, finish, and remove tasks—right from your home screen.'),
        const SizedBox(height: 24),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: mint, borderRadius: BorderRadius.circular(28)),
            child: TaskWidgetPreview(model: model, onAdd: quickAddWidgetTask)),
        const SizedBox(height: 20),
        if (isAndroid)
          FilledButton.icon(
              onPressed: () => model.action('pinWidget'),
              icon: const Icon(Icons.add_to_home_screen),
              label: const Text('Add to home screen')),
        const SizedBox(height: 12),
        const Text(
            'Tap the circle to finish a task. Tap × to remove it. Add a task opens a small quick-add dialog. Changes stay in sync with My day.',
            style: TextStyle(fontSize: 13, color: muted, height: 1.6)),
        const SizedBox(height: 16),
        panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kIsWeb ? 'Interactive widget preview' : 'Place your widget',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              kIsWeb
                  ? 'Try it here with your current tasks. The real home-screen widget is available on Android.'
                  : 'Long-press an empty space on your home screen, choose Widgets, and find RemindMe tasks. Drag it onto your home screen and resize it to fit.',
              style: const TextStyle(fontSize: 12, color: muted, height: 1.6)),
        ])),
        TextButton.icon(
            onPressed: () => setState(() {
                  page = 0;
                }),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back to My day')),
      ];

  Future<void> quickAddWidgetTask() async {
    final name = TextEditingController(),
        list = TextEditingController(text: 'Personal');
    String? error;
    await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                    title: const Text('A new small step'),
                    content: SizedBox(
                        width: 360,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(
                              controller: name,
                              autofocus: true,
                              maxLength: 200,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                  labelText: 'What would you like to get done?',
                                  errorText: error)),
                          TextField(
                              controller: list,
                              maxLength: 40,
                              decoration:
                                  const InputDecoration(labelText: 'List'))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () async {
                            if (name.text.trim().isEmpty) {
                              setLocal(() => error = 'Give your task a name.');
                              return;
                            }
                            await model.upsert(Task(
                                id: DateTime.now()
                                    .microsecondsSinceEpoch
                                    .toString(),
                                title: name.text.trim(),
                                list: list.text.trim().isEmpty
                                    ? 'Personal'
                                    : list.text.trim()));
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text('Add task'))
                    ])));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    name.dispose();
    list.dispose();
  }

  Widget permissionRow(String label, bool allowed, String action) => ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          allowed ? 'Allowed' : 'Tap to set up',
          style: TextStyle(fontSize: 11, color: allowed ? green : muted),
        ),
        trailing: Icon(
          allowed ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
          size: 19,
          color: green,
        ),
        onTap: () => model.action(action),
      );

  Widget desktopIntro() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD5DCCD)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: green),
                SizedBox(width: 7),
                Text(
                  'FLUTTER · LIVE PREVIEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'A small friend.\nA softer nudge.',
            style: TextStyle(
              fontSize: 45,
              height: 1.12,
              fontWeight: FontWeight.w600,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Meet Mochi, your pocket companion for the things you want to make time for.',
            style: TextStyle(fontSize: 16, color: muted, height: 1.7),
          ),
          const SizedBox(height: 32),
          introStep(
              '01', 'Make a small plan', 'Add, edit, and complete a task.'),
          introStep(
            '02',
            'Wake your companion',
            'Tap Mochi for a friendly reminder.',
          ),
          introStep(
            '03',
            'Find your own rhythm',
            'Choose when a scrolling nudge feels right.',
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                model.running = true;
              });
              speak(
                'Hey, we’ve been scrolling for a while. A stretch, or one small step?',
              );
            },
            icon: const Icon(Icons.pets_outlined, size: 18),
            label: const Text('Preview a Mochi check-in'),
          ),
          const SizedBox(height: 24),
          const Text(
            'This is the Flutter app running locally.\nAndroid-only features need a phone to test.',
            style: TextStyle(fontSize: 11, color: muted, height: 1.7),
          ),
        ],
      );
  Widget introStep(String number, String label, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 10,
                  color: green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    desc,
                    style: const TextStyle(
                        fontSize: 12, color: muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget previewPet() => Positioned(
        left: 16,
        right: 16,
        bottom: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bubble != null)
              Container(
                width: 280,
                padding: const EdgeInsets.fromLTRB(15, 10, 8, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF5),
                  border: Border.all(color: const Color(0xFFD6DDC9)),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: ink.withValues(alpha: .08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            bubble!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: ink,
                              height: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: 'Dismiss reminder',
                            onPressed: () => setState(() {
                              bubble = null;
                            }),
                            icon: const Icon(Icons.close, size: 15),
                          ),
                        ),
                      ],
                    ),
                    if (bubbleTask != null)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final task = bubbleTask!;
                              if (!task.done) await model.toggle(task);
                              speak('One small step done. Nicely done!');
                            },
                            child: const Text('Done ✓'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final task = bubbleTask!;
                              task.due = DateTime.now()
                                  .add(const Duration(minutes: 10))
                                  .millisecondsSinceEpoch;
                              task.reminded = false;
                              shown.remove(task.id);
                              await model.upsert(task);
                              setState(() {
                                bubble = null;
                              });
                            },
                            child: const Text('10m later'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            GestureDetector(
              onLongPress: () => setState(() {
                model.running = false;
                bubble = null;
              }),
              child: AnimatedBuilder(
                animation: stroll,
                builder: (context, _) => Align(
                  alignment: Alignment(
                    MediaQuery.disableAnimationsOf(context)
                        ? 1
                        : stroll.value * 2 - 1,
                    0,
                  ),
                  child: Transform.flip(
                    flipX: stroll.status == AnimationStatus.reverse,
                    child: PixelCat(size: 78, onTap: nextTask),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> chooseApps() async {
    await model.loadApps();
    if (!mounted) return;
    final selected = Set<String>.of(model.watched);
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('A little less time in…'),
          content: SizedBox(
            width: 360,
            height: 350,
            child: model.apps.isEmpty
                ? const Center(child: Text('No launchable apps found.'))
                : ListView(
                    children: [
                      if (!isAndroid)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Example apps for the browser preview.',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                      ...model.apps.map(
                        (app) => CheckboxListTile(
                          value: selected.contains(app['package']),
                          title: Text(app['name']!),
                          onChanged: (v) => setLocal(() {
                            if (v == true) {
                              selected.add(app['package']!);
                            } else {
                              selected.remove(app['package']);
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                model.watched = selected;
                await model.save();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save choices'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> editTask([Task? original]) async {
    final name = TextEditingController(text: original?.title);
    final list = TextEditingController(text: original?.list ?? 'Personal');
    DateTime? due = original == null || original.due == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(original.due);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            original == null ? 'A new small step' : 'Make a little adjustment',
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'What matters to you?',
                      hintText: 'Make a little room to read',
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: list,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Your list',
                      hintText: 'Personal, Work, Wellbeing…',
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_none_rounded),
                    title: Text(
                      due == null
                          ? 'Add a reminder'
                          : '${MaterialLocalizations.of(context).formatShortDate(due!)} · ${TimeOfDay.fromDateTime(due!).format(context)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'A gentle nudge when it’s time',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    trailing: due == null
                        ? const Icon(Icons.add, size: 18)
                        : IconButton(
                            tooltip: 'Clear reminder',
                            onPressed: () => setLocal(() {
                              due = null;
                            }),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                    onTap: () async {
                      final now = DateTime.now();
                      final initial =
                          due != null && due!.isAfter(now) ? due! : now;
                      final date = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateUtils.dateOnly(now),
                        lastDate: DateTime(now.year + 10),
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(initial),
                      );
                      if (time != null) {
                        setLocal(() {
                          due = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    },
                  ),
                  if (kIsWeb)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Preview reminders appear while this page is open.',
                        style: TextStyle(
                          fontSize: 11,
                          color: muted,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            if (original != null)
              TextButton(
                onPressed: () async {
                  await model.remove(original);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Color(0xFF9C4E38)),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  setLocal(() {
                    error = 'Give this small step a name.';
                  });
                  return;
                }
                if (due != null &&
                    due!.millisecondsSinceEpoch != original?.due &&
                    !due!.isAfter(DateTime.now())) {
                  setLocal(() {
                    error = 'Choose a reminder in the future.';
                  });
                  return;
                }
                final task = Task(
                  id: original?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  title: name.text.trim(),
                  list:
                      list.text.trim().isEmpty ? 'Personal' : list.text.trim(),
                  due: due?.millisecondsSinceEpoch ?? 0,
                  done: original?.done ?? false,
                  reminded: original != null &&
                          (due?.millisecondsSinceEpoch ?? 0) == original.due
                      ? original.reminded
                      : false,
                );
                await model.upsert(task);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(original == null ? 'Add step' : 'Save'),
            ),
          ],
        ),
      ),
    );
    // Dialog route disposal is asynchronous; dispose controllers after its exit animation.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    name.dispose();
    list.dispose();
  }
}
