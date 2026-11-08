import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class Pet {
  Pet(
      {required this.id,
      this.name = 'Mochi',
      this.animal = 'cat',
      this.color = 0xFFD99458,
      this.accent = 0xFFFFE4BB,
      this.size = 88,
      this.fontSize = 15,
      this.font = 'rounded',
      this.textColor = 0xFF293E34,
      this.bubbleColor = 0xFFFFFCF3,
      this.radius = 20,
      this.opacity = 1,
      this.speed = 90,
      this.holdSeconds = 12,
      this.entry = 'left',
      this.position = 'center',
      this.vertical = 'bottom',
      this.voiceEnabled = false,
      this.readText = false,
      this.volume = .8,
      this.rate = 1,
      this.pitch = 1,
      this.taskClip = '',
      this.taskClipName = '',
      this.timerClip = '',
      this.timerClipName = ''});
  String id,
      name,
      animal,
      font,
      entry,
      position,
      vertical,
      taskClip,
      taskClipName,
      timerClip,
      timerClipName;
  int color, accent, textColor, bubbleColor;
  double size,
      fontSize,
      radius,
      opacity,
      speed,
      holdSeconds,
      volume,
      rate,
      pitch;
  bool voiceEnabled, readText;
  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
      id: j['id'] as String? ?? 'mochi',
      name: j['name'] as String? ?? 'Mochi',
      animal: j['animal'] as String? ?? 'cat',
      color: (j['color'] as num?)?.toInt() ?? 0xFFD99458,
      accent: (j['accent'] as num?)?.toInt() ?? 0xFFFFE4BB,
      size: (j['size'] as num?)?.toDouble() ?? 88,
      fontSize: (j['fontSize'] as num?)?.toDouble() ?? 15,
      font: j['font'] as String? ?? 'rounded',
      textColor: (j['textColor'] as num?)?.toInt() ?? 0xFF293E34,
      bubbleColor: (j['bubbleColor'] as num?)?.toInt() ?? 0xFFFFFCF3,
      radius: (j['radius'] as num?)?.toDouble() ?? 20,
      opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
      speed: (j['speed'] as num?)?.toDouble() ?? 90,
      holdSeconds: (j['holdSeconds'] as num?)?.toDouble() ?? 12,
      entry: j['entry'] as String? ?? 'left',
      position: j['position'] as String? ?? 'center',
      vertical: j['vertical'] as String? ?? 'bottom',
      voiceEnabled: j['voiceEnabled'] == true,
      readText: j['readText'] == true,
      volume: (j['volume'] as num?)?.toDouble() ?? .8,
      rate: (j['rate'] as num?)?.toDouble() ?? 1,
      pitch: (j['pitch'] as num?)?.toDouble() ?? 1,
      taskClip: j['taskClip'] as String? ?? '',
      taskClipName: j['taskClipName'] as String? ?? '',
      timerClip: j['timerClip'] as String? ?? '',
      timerClipName: j['timerClipName'] as String? ?? '');
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'animal': animal,
        'color': color,
        'accent': accent,
        'size': size,
        'fontSize': fontSize,
        'font': font,
        'textColor': textColor,
        'bubbleColor': bubbleColor,
        'radius': radius,
        'opacity': opacity,
        'speed': speed,
        'holdSeconds': holdSeconds,
        'entry': entry,
        'position': position,
        'vertical': vertical,
        'voiceEnabled': voiceEnabled,
        'readText': readText,
        'volume': volume,
        'rate': rate,
        'pitch': pitch,
        'taskClip': taskClip,
        'taskClipName': taskClipName,
        'timerClip': timerClip,
        'timerClipName': timerClipName
      };
  Pet copy() => Pet.fromJson(toJson());
  String clip(String kind) => kind == 'timer' ? timerClip : taskClip;
  String clipName(String kind) =>
      kind == 'timer' ? timerClipName : taskClipName;
  String get fontFamily => switch (font) {
        'serif' => 'Lora',
        'mono' => 'RobotoMono',
        _ => 'Nunito'
      };
}

class TimerRule {
  TimerRule(
      {required this.id,
      this.name = 'A scrolling break',
      this.minutes = 20,
      this.companionId = 'mochi',
      this.enabled = true,
      Set<String>? apps})
      : apps = apps ?? {};
  String id, name, companionId;
  int minutes;
  bool enabled;
  Set<String> apps;
  factory TimerRule.fromJson(Map<String, dynamic> j) => TimerRule(
      id: j['id'] as String,
      name: j['name'] as String? ?? 'A scrolling break',
      minutes: ((j['minutes'] as num?)?.toInt() ?? 20).clamp(5, 120),
      companionId: j['companionId'] as String? ?? 'mochi',
      enabled: j['enabled'] != false,
      apps: Set<String>.from(j['apps'] as List? ?? []));
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'minutes': minutes,
        'companionId': companionId,
        'enabled': enabled,
        'apps': apps.toList()
      };
  TimerRule copy() => TimerRule.fromJson(toJson());
}

class VoiceClip {
  VoiceClip(this.uri, this.name);
  final String uri, name;
  factory VoiceClip.fromJson(Map<dynamic, dynamic> j) =>
      VoiceClip(j['uri'] as String, j['name'] as String);
}

class Task {
  Task(
      {required this.id,
      required this.title,
      this.list = 'Personal',
      this.companionId = 'mochi',
      this.due = 0,
      this.done = false,
      this.reminded = false});
  final String id;
  String title, list, companionId;
  int due;
  bool done, reminded;
  factory Task.fromJson(Map<String, dynamic> j) => Task(
      id: j['id'] as String,
      title: j['title'] as String,
      list: j['list'] as String? ?? 'Personal',
      companionId: j['companionId'] as String? ?? 'mochi',
      due: (j['due'] as num?)?.toInt() ?? 0,
      done: j['done'] == true,
      reminded: j['reminded'] == true);
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'list': list,
        'companionId': companionId,
        'due': due,
        'done': done,
        'reminded': reminded
      };
}

class CompanionModel extends ChangeNotifier {
  static const channel = MethodChannel('remindme/companion');
  List<Task> tasks = [];
  List<Pet> pets = [Pet(id: 'mochi')];
  List<TimerRule> timers = [];
  String defaultCompanion = 'mochi';
  bool loaded = false,
      running = false,
      nudges = false,
      speech = false,
      overlayAllowed = false,
      usageAllowed = false,
      notificationsAllowed = false,
      demo = kIsWeb;
  int minutes = 20;
  Set<String> watched = {};
  List<Map<String, String>> apps = [];
  String? error;
  SharedPreferences? _preferences;
  StreamSubscription<dynamic>? _taskChanges;
  bool _disposed = false;
  Pet pet(String? id) =>
      pets.firstWhere((p) => p.id == id, orElse: () => pets.first);
  Pet get defaultPet => pet(defaultCompanion);
  List<Task> _decodeTasks(List<dynamic> items) => items
      .map((t) => Task.fromJson(Map<String, dynamic>.from(t as Map)))
      .toList();
  @override
  void dispose() {
    _disposed = true;
    _taskChanges?.cancel();
    super.dispose();
  }

  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      Map<String, dynamic> state;
      if (isAndroid) {
        state = Map<String, dynamic>.from(
            await channel.invokeMethod('loadState') as Map);
      } else {
        _preferences = await SharedPreferences.getInstance();
        final raw = _preferences!.getString('remindme.workspace.v2');
        state = raw == null
            ? {}
            : Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (raw == null && kIsWeb) {
          state['tasks'] = [
            Task(id: 'demo-1', title: 'Make a little room to read').toJson(),
            Task(
                    id: 'demo-2',
                    title: 'Take a walk, leave the phone',
                    list: 'Wellbeing')
                .toJson()
          ];
        }
      }
      tasks = _decodeTasks(state['tasks'] as List? ?? []);
      pets = ((state['companions'] as List?) ?? [])
          .map((p) => Pet.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
      if (pets.isEmpty) {
        pets = [Pet(id: 'mochi', voiceEnabled: state['speech'] == true)];
      }
      defaultCompanion = state['defaultCompanion'] as String? ?? pets.first.id;
      if (!pets.any((p) => p.id == defaultCompanion)) {
        defaultCompanion = pets.first.id;
      }
      nudges = state['nudges'] == true;
      speech = state['speech'] == true;
      minutes = ((state['minutes'] as num?)?.toInt() ?? 20).clamp(5, 120);
      watched = Set<String>.from(state['watched'] as List? ?? []);
      timers = ((state['timers'] as List?) ?? [])
          .map((r) => TimerRule.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
      if (!state.containsKey('timers') && watched.isNotEmpty) {
        timers = [
          TimerRule(
              id: 'legacy-timer',
              minutes: minutes,
              enabled: nudges,
              apps: Set.of(watched),
              companionId: defaultCompanion)
        ];
      }
      for (final task in tasks) {
        if (!pets.any((p) => p.id == task.companionId)) {
          task.companionId = defaultCompanion;
        }
      }
      for (final rule in timers) {
        if (!pets.any((p) => p.id == rule.companionId)) {
          rule.companionId = defaultCompanion;
        }
      }
      demo = state['demo'] as bool? ?? kIsWeb;
      if (isAndroid) {
        _permissions(state);
        _taskChanges ??= const EventChannel('remindme/tasks')
            .receiveBroadcastStream()
            .listen((event) {
          tasks = _decodeTasks(event as List);
          changed();
        }, onError: (_) {});
      }
      error = null;
      loaded = true;
      changed();
    } catch (_) {
      error = 'Your workspace could not be loaded. Please reopen the app.';
      loaded = true;
      changed();
    }
  }

  void _permissions(Map<String, dynamic> j) {
    running = j['running'] == true;
    overlayAllowed = j['overlay'] == true;
    usageAllowed = j['usage'] == true;
    notificationsAllowed = j['notifications'] == true;
  }

  Future<void> refreshPermissions() async {
    if (!isAndroid) return;
    try {
      _permissions(Map<String, dynamic>.from(
          await channel.invokeMethod('permissions') as Map));
      changed();
    } catch (_) {}
  }

  void setMinutes(int value) {
    minutes = value.clamp(5, 120);
    changed();
  }

  Future<void> save() async {
    final state = <String, dynamic>{
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'companions': pets.map((p) => p.toJson()).toList(),
      'defaultCompanion': defaultCompanion,
      'timers': timers.map((r) => r.toJson()).toList(),
      'minutes': minutes,
      'nudges': nudges,
      'speech': speech,
      'watched': watched.toList(),
      'demo': demo
    };
    changed();
    try {
      if (isAndroid) {
        state.remove('tasks');
        await channel.invokeMethod('saveState', state);
      } else {
        _preferences ??= await SharedPreferences.getInstance();
        final saved = await _preferences!
            .setString('remindme.workspace.v2', jsonEncode(state));
        if (!saved) throw StateError('Storage full');
      }
      error = null;
    } catch (_) {
      error =
          'Could not save. Audio clips may be too large for browser storage. Please try a shorter clip.';
    }
    changed();
  }

  Future<void> upsert(Task task) async {
    if (!pets.any((p) => p.id == task.companionId)) {
      task.companionId = defaultCompanion;
    }
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

  Future<void> _persistTask(String method, Object args) async {
    if (!isAndroid) {
      await save();
      return;
    }
    changed();
    try {
      final result = await channel.invokeMethod<List<dynamic>>(method, args);
      if (result != null) tasks = _decodeTasks(result);
      error = null;
    } catch (_) {
      error = 'Could not save this task. Please reopen the app and try again.';
    }
    changed();
  }

  Future<void> savePet(Pet value) async {
    final previous = List<Pet>.of(pets);
    final i = pets.indexWhere((p) => p.id == value.id);
    if (i < 0) {
      pets.add(value);
    } else {
      pets[i] = value;
    }
    await save();
    if (error != null) {
      pets = previous;
      changed();
    }
  }

  Future<void> removePet(String id) async {
    if (pets.length < 2) return;
    final previous = List<Pet>.of(pets);
    final oldDefault = defaultCompanion;
    final oldTasks = {for (final t in tasks) t.id: t.companionId};
    final oldTimers = {for (final r in timers) r.id: r.companionId};
    pets.removeWhere((p) => p.id == id);
    if (defaultCompanion == id) defaultCompanion = pets.first.id;
    for (final t in tasks) {
      if (t.companionId == id) t.companionId = defaultCompanion;
    }
    for (final r in timers) {
      if (r.companionId == id) r.companionId = defaultCompanion;
    }
    await save();
    if (error != null) {
      pets = previous;
      defaultCompanion = oldDefault;
      for (final t in tasks) {
        t.companionId = oldTasks[t.id] ?? oldDefault;
      }
      for (final r in timers) {
        r.companionId = oldTimers[r.id] ?? oldDefault;
      }
      changed();
    }
  }

  Future<void> saveTimer(TimerRule value) async {
    final previous = List<TimerRule>.of(timers);
    final i = timers.indexWhere((r) => r.id == value.id);
    if (i < 0) {
      timers.add(value);
    } else {
      timers[i] = value;
    }
    await save();
    if (error != null) {
      timers = previous;
      changed();
    }
  }

  Future<void> removeTimer(String id) async {
    timers.removeWhere((r) => r.id == id);
    await save();
  }

  Future<void> clearDemo() async {
    tasks.clear();
    demo = false;
    await save();
  }

  Future<void> action(String method, [Object? args]) async {
    if (!isAndroid) return;
    try {
      await channel.invokeMethod(method, args);
      await refreshPermissions();
    } on PlatformException catch (e) {
      error = e.message ?? 'Please try again.';
      changed();
    }
  }

  Future<void> loadApps() async {
    if (!isAndroid) {
      apps = [
        {'name': 'Instagram', 'package': 'demo.instagram'},
        {'name': 'TikTok', 'package': 'demo.tiktok'},
        {'name': 'YouTube', 'package': 'demo.youtube'},
        {'name': 'Reddit', 'package': 'demo.reddit'},
        {'name': 'Chrome', 'package': 'demo.chrome'}
      ];
    } else {
      try {
        apps = (await channel.invokeMethod<List<dynamic>>('apps') ?? [])
            .map((a) => Map<String, String>.from(a as Map))
            .toList();
      } catch (_) {
        error = 'Could not load installed apps.';
      }
    }
    changed();
  }

  String appName(String package) =>
      apps.firstWhere((a) => a['package'] == package,
          orElse: () => {'name': package.split('.').last})['name']!;
  List<Task> visibleTasks(String filter) {
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final out = tasks
        .where((t) => filter == 'Done'
            ? t.done
            : !t.done &&
                (filter == 'All tasks' || t.due == 0 || t.due < tomorrow))
        .toList();
    out.sort((a, b) => (a.due == 0 ? 9999999999999 : a.due)
        .compareTo(b.due == 0 ? 9999999999999 : b.due));
    return out;
  }
}
