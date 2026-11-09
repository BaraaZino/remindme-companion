import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'companion_model.dart';
import 'pixel_cat.dart';
import 'voice_backend.dart';
import 'app_style.dart';

class VisitRequest {
  VisitRequest(
      {required this.pet,
      required this.text,
      this.kind = 'task',
      this.taskId,
      this.onDone,
      this.onSnooze});
  final Pet pet;
  final String text, kind;
  final String? taskId;
  final VoidCallback? onDone, onSnooze;
}

class VisitController extends ChangeNotifier {
  VisitRequest? current;
  final Queue<VisitRequest> _queue = Queue();
  bool suspended = false, _disposed = false, _foreground = true;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void add(VisitRequest request) {
    if (_disposed) return;
    if (current?.taskId != null && current!.taskId == request.taskId) return;
    if (current == null && !suspended && _foreground) {
      current = request;
      notifyListeners();
    } else {
      _queue.add(request);
    }
  }

  void finish() {
    if (_disposed) return;
    current = null;
    if (!suspended && _foreground && _queue.isNotEmpty) {
      current = _queue.removeFirst();
    }
    notifyListeners();
  }

  void clear() {
    if (_disposed) return;
    current = null;
    _queue.clear();
    notifyListeners();
  }

  void setForeground(bool active) {
    if (_disposed || active == _foreground) return;
    _foreground = active;
    if (!active && current != null) {
      _queue.addFirst(current!);
      current = null;
    } else if (active && !suspended && current == null && _queue.isNotEmpty) {
      current = _queue.removeFirst();
    }
    notifyListeners();
  }

  void suspend() {
    if (_disposed) return;
    suspended = true;
    if (current != null) _queue.addFirst(current!);
    current = null;
    notifyListeners();
  }

  void resume() {
    if (_disposed) return;
    suspended = false;
    if (current == null && _foreground && _queue.isNotEmpty) {
      current = _queue.removeFirst();
      notifyListeners();
    }
  }
}

class VisitOverlay extends StatefulWidget {
  const VisitOverlay({super.key, required this.controller});
  final VisitController controller;
  @override
  State<VisitOverlay> createState() => _VisitOverlayState();
}

class _VisitOverlayState extends State<VisitOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController move = AnimationController(vsync: this);
  VisitRequest? visit;
  Timer? hold, safety, fade;
  String phase = 'idle';
  bool left = true, audioDone = true, holdDone = false;
  int token = 0;
  double start = 0, target = 0, end = 0, y = 0;
  String? audioError;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => sync());
  }

  void sync() {
    if (!mounted || identical(visit, widget.controller.current)) return;
    token++;
    hold?.cancel();
    safety?.cancel();
    fade?.cancel();
    move.stop();
    if (visit?.pet.voiceEnabled == true) {
      VoiceTools.stopPlayback().catchError((_) {});
    }
    visit = widget.controller.current;
    audioError = null;
    if (visit == null) {
      setState(() => phase = 'idle');
      return;
    }
    final p = visit!.pet;
    final screen = MediaQuery.sizeOf(context);
    final bubble = math.min(300.0, screen.width - 24);
    final offset = math.max(0, (bubble - p.size) / 2);
    left = p.entry == 'left' || (p.entry == 'alternate' && token.isOdd);
    final raw = (screen.width - p.size) *
        (p.position == 'left'
            ? .2
            : p.position == 'right'
                ? .8
                : .5);
    target = raw.clamp(offset + 12,
        math.max(offset + 12, screen.width - bubble - 12 + offset));
    start = left ? -p.size : screen.width;
    end = left ? screen.width : -p.size;
    y = math.min(
        screen.height - p.size - 90,
        math.max(
            220,
            screen.height *
                    (p.vertical == 'top'
                        ? .3
                        : p.vertical == 'middle'
                            ? .55
                            : .8) -
                p.size));
    setState(() => phase = 'enter');
    final id = token;
    move.duration = Duration(
        milliseconds: ((target - start).abs() / p.speed * 1000)
            .round()
            .clamp(400, 10000));
    move.forward(from: 0).then((_) {
      if (mounted && id == token && visit != null) talk();
    });
  }

  void talk() {
    setState(() => phase = 'talk');
    final id = token;
    holdDone = false;
    audioDone = !visit!.pet.voiceEnabled;
    hold = Timer(
        Duration(milliseconds: (visit!.pet.holdSeconds * 1000).round()), () {
      holdDone = true;
      tryExit();
    });
    safety = Timer(const Duration(seconds: 75), () {
      audioDone = true;
      holdDone = true;
      tryExit();
    });
    if (!audioDone) {
      VoiceTools.say(visit!.pet, visit!.text, visit!.kind)
          .catchError((Object e) {
        if (mounted && id == token) {
          setState(() => audioError = 'Tap the sound button to retry audio.');
        }
      }).whenComplete(() {
        if (mounted && id == token) {
          audioDone = true;
          tryExit();
        }
      });
    }
  }

  void tryExit() {
    if (mounted && phase == 'talk' && holdDone && audioDone) exit();
  }

  void exit() {
    if (visit == null || phase == 'exit' || phase == 'fade') return;
    hold?.cancel();
    safety?.cancel();
    fade?.cancel();
    if (visit!.pet.voiceEnabled) VoiceTools.stopPlayback().catchError((_) {});
    final id = token;
    setState(() => phase = 'fade');
    fade = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || id != token || visit == null) return;
      setState(() => phase = 'exit');
      move.duration = Duration(
          milliseconds: ((end - target).abs() / visit!.pet.speed * 1000)
              .round()
              .clamp(400, 10000));
      move.forward(from: 0).then((_) {
        if (mounted && id == token) widget.controller.finish();
      });
    });
  }

  @override
  void dispose() {
    token++;
    widget.controller.removeListener(sync);
    hold?.cancel();
    safety?.cancel();
    fade?.cancel();
    move.dispose();
    if (visit?.pet.voiceEnabled == true) {
      VoiceTools.stopPlayback().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (visit == null) return const SizedBox.shrink();
    final p = visit!.pet;
    final width = MediaQuery.sizeOf(context).width;
    return AnimatedBuilder(
        animation: move,
        builder: (context, _) {
          final x = phase == 'enter'
              ? start + (target - start) * move.value
              : phase == 'exit'
                  ? target + (end - target) * move.value
                  : target;
          return Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned(
                left: (target - (math.min(300, width - 24) - p.size) / 2).clamp(
                    12, math.max(12, width - math.min(300, width - 24) - 12)),
                top: y - 8,
                child: FractionalTranslation(
                    translation: const Offset(0, -1),
                    child: IgnorePointer(
                        ignoring: phase != 'talk',
                        child: ExcludeSemantics(
                            excluding: phase != 'talk',
                            child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeInOut,
                                opacity: phase == 'talk' ? 1 : 0,
                                child: buildBubble(p)))))),
            Positioned(
                left: x,
                top: y,
                child: Opacity(
                    opacity: p.opacity,
                    child: GestureDetector(
                        onLongPress: exit,
                        child: PixelCat(
                            size: p.size,
                            walking: phase == 'enter' || phase == 'exit',
                            talking: phase == 'talk',
                            name: p.name,
                            animal: p.animal,
                            color: p.color,
                            accent: p.accent,
                            faceRight: left)))),
          ]);
        });
  }

  Widget buildBubble(Pet p) => Opacity(
      opacity: p.opacity,
      child: Material(
          color: Color(p.bubbleColor),
          elevation: 5,
          shadowColor: ink.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(p.radius),
          child: Container(
              width: math.min(300, MediaQuery.sizeOf(context).width - 24),
              constraints: BoxConstraints(maxHeight: math.max(140, y - 20)),
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 12),
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(p.name,
                              style: TextStyle(
                                  fontFamily: p.fontFamily,
                                  fontSize: 11,
                                  color: Color(p.textColor),
                                  fontWeight: FontWeight.w800))),
                      if (p.voiceEnabled)
                        IconButton(
                            tooltip: 'Replay voice',
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                VoiceTools.say(p, visit!.text, visit!.kind)
                                    .catchError((_) {}),
                            icon: Icon(Icons.volume_up_outlined,
                                size: 18, color: Color(p.textColor))),
                      IconButton(
                          tooltip: 'Dismiss visit',
                          visualDensity: VisualDensity.compact,
                          onPressed: exit,
                          icon: Icon(Icons.close,
                              size: 16, color: Color(p.textColor)))
                    ]),
                    Text(visit!.text,
                        style: TextStyle(
                            fontFamily: p.fontFamily,
                            fontSize: p.fontSize,
                            color: Color(p.textColor),
                            height: 1.45)),
                    if (audioError != null)
                      Text(audioError!,
                          style: const TextStyle(fontSize: 10, color: muted)),
                    if (visit!.taskId != null)
                      Wrap(children: [
                        TextButton(
                            onPressed: () {
                              visit!.onDone?.call();
                              exit();
                            },
                            child: const Text('Done ✓')),
                        TextButton(
                            onPressed: () {
                              visit!.onSnooze?.call();
                              exit();
                            },
                            child: const Text('10m later'))
                      ]),
                  ])))));
}

/// Provides an Overlay ancestor for visit tooltips above every Navigator route.
class VisitHost extends StatefulWidget {
  const VisitHost(
      {super.key,
      required this.child,
      required this.controller,
      required this.foreground});
  final Widget child;
  final VisitController controller;
  final bool foreground;
  @override
  State<VisitHost> createState() => _VisitHostState();
}

class _VisitHostState extends State<VisitHost> {
  late final OverlayEntry entry = OverlayEntry(
      builder: (_) => Stack(fit: StackFit.expand, children: [
            widget.child,
            if (widget.foreground) VisitOverlay(controller: widget.controller)
          ]));
  @override
  void didUpdateWidget(VisitHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    entry.markNeedsBuild();
  }

  @override
  void dispose() {
    entry.remove();
    entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [entry]);
}
