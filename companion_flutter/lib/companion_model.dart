import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class Task {
  Task({
    required this.id,
    required this.title,
    this.list = 'Personal',
    this.due = 0,
    this.done = false,
    this.reminded = false,
  });
  final String id;
  String title, list;
  int due;
  bool done, reminded;
  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        list: j['list'] as String? ?? 'Personal',
        due: (j['due'] as num?)?.toInt() ?? 0,
        done: j['done'] == true,
        reminded: j['reminded'] == true,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'list': list,
        'due': due,
        'done': done,
        'reminded': reminded,
      };
}

class CompanionModel extends ChangeNotifier {
  static const channel = MethodChannel('remindme/companion');
  List<Task> tasks = [];
  bool loaded = false, running = false, nudges = false, speech = false;
  bool overlayAllowed = false,
      usageAllowed = false,
      notificationsAllowed = false;
  bool demo = kIsWeb;
  int minutes = 20;
  Set<String> watched = {};
  List<Map<String, String>> apps = [];
  String? error;
  SharedPreferences? _preferences;
  StreamSubscription<dynamic>? _taskChanges;

  List<Task> _decodeTasks(List<dynamic> items) => items
      .map((t) => Task.fromJson(Map<String, dynamic>.from(t as Map)))
      .toList();

  @override
  void dispose() {
    _taskChanges?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      Map<String, dynamic> state;
      if (isAndroid) {
        state = Map<String, dynamic>.from(
          await channel.invokeMethod('loadState') as Map,
        );
      } else {
        _preferences = await SharedPreferences.getInstance();
        final saved = _preferences!.getString('remindme.workspace.v2');
        state = saved == null
            ? {}
            : Map<String, dynamic>.from(jsonDecode(saved) as Map);
        if (saved == null && kIsWeb) {
          final now = DateTime.now();
          final evening = DateTime(now.year, now.month, now.day, 20);
          state['tasks'] = [
            Task(
              id: 'demo-1',
              title: 'Make a little room to read',
              list: 'Personal',
              due: evening.isAfter(now) ? evening.millisecondsSinceEpoch : 0,
            ).toJson(),
            Task(
              id: 'demo-2',
              title: 'Take a walk, leave the phone',
              list: 'Wellbeing',
            ).toJson(),
            Task(
              id: 'demo-3',
              title: 'Plan tomorrow’s first small step',
              list: 'Personal',
            ).toJson(),
          ];
        }
      }
      tasks = ((state['tasks'] as List?) ?? [])
          .map((t) => Task.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
      nudges = state['nudges'] == true;
      speech = state['speech'] == true;
      minutes = ((state['minutes'] as num?)?.toInt() ?? 20).clamp(5, 120);
      watched = Set<String>.from((state['watched'] as List?) ?? []);
      demo = state['demo'] as bool? ?? kIsWeb;
      if (isAndroid) {
        _permissions(state);
        _taskChanges ??= const EventChannel('remindme/tasks')
            .receiveBroadcastStream()
            .listen((event) {
          tasks = _decodeTasks(event as List);
          notifyListeners();
        }, onError: (_) {});
      }
      loaded = true;
      notifyListeners();
    } catch (e) {
      error = 'Your workspace could not be loaded. Please reopen the app.';
      loaded = true;
      notifyListeners();
    }
  }

  void _permissions(Map<String, dynamic> state) {
    running = state['running'] == true;
    overlayAllowed = state['overlay'] == true;
    usageAllowed = state['usage'] == true;
    notificationsAllowed = state['notifications'] == true;
  }

  Future<void> refreshPermissions() async {
    if (!isAndroid) return;
    try {
      _permissions(
        Map<String, dynamic>.from(
          await channel.invokeMethod('permissions') as Map,
        ),
      );
      notifyListeners();
    } catch (_) {}
  }

  void setMinutes(int value) {
    minutes = value.clamp(5, 120);
    notifyListeners();
  }

  Future<void> save() async {
    final state = {
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'minutes': minutes,
      'nudges': nudges,
      'speech': speech,
      'watched': watched.toList(),
      'demo': demo,
    };
    notifyListeners();
    try {
      if (isAndroid) {
        await channel.invokeMethod(
            'saveState', Map<String, dynamic>.of(state)..remove('tasks'));
      } else {
        _preferences ??= await SharedPreferences.getInstance();
        await _preferences!.setString(
          'remindme.workspace.v2',
          jsonEncode(state),
        );
      }
      error = null;
    } catch (_) {
      error = 'Could not save this change. Please try again.';
    }
    notifyListeners();
  }

  Future<void> upsert(Task task) async {
    final i = tasks.indexWhere((t) => t.id == task.id);
    if (i < 0) {
      tasks.add(task);
    } else {
      tasks[i] = task;
    }
    await _persistTask('upsertTask', task.toJson());
  }

  Future<void> toggle(Task task) async {
    task.done = !task.done;
    if (!task.done) task.reminded = false;
    await _persistTask('completeTask', {'id': task.id, 'done': task.done});
  }

  Future<void> remove(Task task) async {
    tasks.removeWhere((t) => t.id == task.id);
    await _persistTask('deleteTask', task.id);
  }

  Future<void> _persistTask(String method, Object arguments) async {
    if (!isAndroid) {
      await save();
      return;
    }
    notifyListeners();
    try {
      final result =
          await channel.invokeMethod<List<dynamic>>(method, arguments);
      if (result != null) tasks = _decodeTasks(result);
      error = null;
    } catch (_) {
      error = 'Could not save this task. Please reopen the app and try again.';
    }
    notifyListeners();
  }

  Future<void> clearDemo() async {
    tasks.clear();
    demo = false;
    await save();
  }

  Future<void> action(String method) async {
    if (!isAndroid) return;
    try {
      await channel.invokeMethod(method);
      await refreshPermissions();
    } on PlatformException catch (e) {
      error = e.message ?? 'Please try again.';
      notifyListeners();
    }
  }

  Future<void> loadApps() async {
    if (!isAndroid) {
      apps = [
        {'name': 'Instagram', 'package': 'demo.instagram'},
        {'name': 'TikTok', 'package': 'demo.tiktok'},
        {'name': 'YouTube', 'package': 'demo.youtube'},
        {'name': 'Reddit', 'package': 'demo.reddit'},
        {'name': 'Chrome', 'package': 'demo.chrome'},
      ];
    } else {
      try {
        final result = await channel.invokeMethod<List<dynamic>>('apps') ?? [];
        apps = result.map((a) => Map<String, String>.from(a as Map)).toList();
      } catch (_) {
        error = 'Could not load installed apps.';
      }
    }
    notifyListeners();
  }

  List<Task> visibleTasks(String filter) {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;
    final result = tasks
        .where(
          (t) => filter == 'Done'
              ? t.done
              : !t.done &&
                  (filter == 'All tasks' || t.due == 0 || t.due < tomorrow),
        )
        .toList();
    result.sort(
      (a, b) => (a.due == 0 ? 9999999999999 : a.due).compareTo(
        b.due == 0 ? 9999999999999 : b.due,
      ),
    );
    return result;
  }
}
