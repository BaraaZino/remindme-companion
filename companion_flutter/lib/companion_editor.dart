import 'dart:async';
import 'package:flutter/material.dart';
import 'companion_model.dart';
import 'pixel_cat.dart';
import 'app_style.dart';
import 'voice_backend.dart';
import 'visit_overlay.dart';

class CompanionEditor extends StatefulWidget {
  const CompanionEditor(
      {super.key,
      required this.model,
      required this.pet,
      required this.onPreview,
      required this.visits,
      this.isNew = false});
  final CompanionModel model;
  final Pet pet;
  final bool isNew;
  final void Function(Pet, String) onPreview;
  final VisitController visits;
  @override
  State<CompanionEditor> createState() => _CompanionEditorState();
}

class _CompanionEditorState extends State<CompanionEditor> {
  late Pet draft = widget.pet.copy();
  late final name = TextEditingController(text: draft.name);
  final List<String> imported = [];
  bool saving = false, saved = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    for (final path in imported) {
      if (!saved || (path != draft.taskClip && path != draft.timerClip)) {
        VoiceTools.deleteClip(path);
      }
    }
    super.dispose();
  }

  void update(VoidCallback change) => setState(change);
  Future<void> audio(String role, bool record) async {
    setState(() => error = null);
    widget.visits.suspend();
    try {
      final clip = record
          ? await showDialog<VoiceClip>(
              context: context,
              barrierDismissible: false,
              builder: (_) => const RecordingDialog())
          : await VoiceTools.importClip();
      if (!mounted) return;
      if (clip != null) {
        imported.add(clip.uri);
        setState(() {
          if (role == 'task') {
            draft.taskClip = clip.uri;
            draft.taskClipName = clip.name;
          } else {
            draft.timerClip = clip.uri;
            draft.timerClipName = clip.name;
          }
          draft.voiceEnabled = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      widget.visits.resume();
    }
  }

  Widget pick(String label, String value, List<String> values,
          ValueChanged<String> change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
              initialValue: value,
              decoration: InputDecoration(labelText: label),
              items: values
                  .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v[0].toUpperCase() + v.substring(1))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => change(v));
              }));
  Widget color(String label, int value, ValueChanged<int> change) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      trailing: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: Color(value),
              shape: BoxShape.circle,
              border: Border.all(color: line))),
      onTap: () async {
        final selected = await chooseColor(context, value);
        if (selected != null && mounted) setState(() => change(selected));
      });
  Widget voiceCard(String kind, String title) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(
            draft.clip(kind).isEmpty
                ? 'No clip · use the system voice when enabled'
                : draft.clipName(kind),
            style: const TextStyle(color: muted, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        Wrap(spacing: 8, children: [
          TextButton.icon(
              onPressed: () => audio(kind, false),
              icon: const Icon(Icons.audio_file_outlined, size: 17),
              label: const Text('Import')),
          TextButton.icon(
              key: ValueKey('record-$kind'),
              onPressed: () => audio(kind, true),
              icon: const Icon(Icons.mic_none_rounded, size: 17),
              label: const Text('Record')),
          if (draft.clip(kind).isNotEmpty) ...[
            IconButton(
                tooltip: 'Play $kind clip',
                onPressed: () async {
                  try {
                    await VoiceTools.playClip(draft.clip(kind), draft.volume);
                  } catch (e) {
                    if (mounted) {
                      setState(() => error =
                          'Could not play this clip. Please import it again.');
                    }
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded)),
            IconButton(
                tooltip: 'Remove $kind clip',
                onPressed: () => setState(() {
                      if (kind == 'task') {
                        draft.taskClip = '';
                        draft.taskClipName = '';
                      } else {
                        draft.timerClip = '';
                        draft.timerClipName = '';
                      }
                    }),
                icon: const Icon(Icons.close_rounded, size: 18))
          ]
        ]),
        const Divider(height: 20)
      ]);
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.isNew ? 'New companion' : draft.name),
          backgroundColor: cream),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                  children: [
                    panel(
                        Column(children: [
                          PixelCat(
                              size: draft.size.clamp(60, 140),
                              animal: draft.animal,
                              name: draft.name,
                              color: draft.color,
                              accent: draft.accent),
                          const SizedBox(height: 12),
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: Color(draft.bubbleColor),
                                  borderRadius:
                                      BorderRadius.circular(draft.radius)),
                              child: Text(
                                  'Hey! A little step is waiting for you.',
                                  style: TextStyle(
                                      fontFamily: draft.fontFamily,
                                      fontSize: draft.fontSize,
                                      color: Color(draft.textColor),
                                      height: 1.4))),
                          const SizedBox(height: 10),
                          Text('Live appearance preview',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: muted.withValues(alpha: .9)))
                        ]),
                        color: mint),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(error!,
                              style:
                                  const TextStyle(color: Color(0xFFA34F3E)))),
                    sectionTitle('Identity & design'),
                    panel(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                              controller: name,
                              maxLength: 32,
                              decoration: const InputDecoration(
                                  labelText: 'Companion name'),
                              onChanged: (value) =>
                                  setState(() => draft.name = value)),
                          const SizedBox(height: 12),
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ['cat', 'dog', 'bunny', 'fox']
                                  .map((animal) => ChoiceChip(
                                      selected: draft.animal == animal,
                                      showCheckmark: false,
                                      label: Text(animal[0].toUpperCase() +
                                          animal.substring(1)),
                                      avatar: SizedBox(
                                          width: 24,
                                          child: PixelCat(
                                              size: 24,
                                              walking: false,
                                              animal: animal,
                                              color: draft.color,
                                              accent: draft.accent)),
                                      onSelected: (_) => setState(
                                          () => draft.animal = animal)))
                                  .toList()),
                          color('Body color', draft.color,
                              (c) => draft.color = c),
                          color('Accent color', draft.accent,
                              (c) => draft.accent = c),
                          settingSlider('Animal size', draft.size, 48, 160,
                              (v) => update(() => draft.size = v),
                              display: '${draft.size.round()} dp',
                              divisions: 112),
                          settingSlider('Opacity', draft.opacity, .7, 1,
                              (v) => update(() => draft.opacity = v),
                              display: '${(draft.opacity * 100).round()}%',
                              divisions: 30)
                        ])),
                    sectionTitle('Text bubble'),
                    panel(Column(children: [
                      pick('Font', draft.font, ['rounded', 'serif', 'mono'],
                          (v) => draft.font = v),
                      settingSlider('Font size', draft.fontSize, 12, 24,
                          (v) => update(() => draft.fontSize = v),
                          display: '${draft.fontSize.round()} sp',
                          divisions: 12),
                      color('Text color', draft.textColor,
                          (v) => draft.textColor = v),
                      color('Bubble color', draft.bubbleColor,
                          (v) => draft.bubbleColor = v),
                      settingSlider('Rounded corners', draft.radius, 8, 28,
                          (v) => update(() => draft.radius = v),
                          divisions: 20),
                      settingSlider('Minimum reading time', draft.holdSeconds,
                          5, 40, (v) => update(() => draft.holdSeconds = v),
                          display: '${draft.holdSeconds.round()} sec',
                          divisions: 35),
                      const Text(
                          'The companion waits for its voice clip to finish before leaving.',
                          style: TextStyle(
                              fontSize: 12, color: muted, height: 1.5))
                    ])),
                    sectionTitle('Arrival & departure'),
                    panel(Column(children: [
                      pick(
                          'Walk in from',
                          draft.entry,
                          ['left', 'right', 'alternate'],
                          (v) => draft.entry = v),
                      pick(
                          'Stop at',
                          draft.position,
                          ['left', 'center', 'right'],
                          (v) => draft.position = v),
                      pick(
                          'Screen height',
                          draft.vertical,
                          ['top', 'middle', 'bottom'],
                          (v) => draft.vertical = v),
                      settingSlider('Walking speed', draft.speed, 40, 160,
                          (v) => update(() => draft.speed = v),
                          display: '${draft.speed.round()} dp/sec',
                          divisions: 120),
                      const Text(
                          'Walk in → stop and talk → keep walking off-screen.',
                          style: TextStyle(fontSize: 12, color: muted))
                    ])),
                    sectionTitle('Voice & recordings'),
                    panel(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable this companion’s voice',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              value: draft.voiceEnabled,
                              onChanged: (v) =>
                                  setState(() => draft.voiceEnabled = v)),
                          const Text(
                              'Use your own recordings or audio files. Clips play as recorded; the bubble always shows the actual reminder. Up to 60 seconds / 5 MB per clip.',
                              style: TextStyle(
                                  fontSize: 12, color: muted, height: 1.5)),
                          const SizedBox(height: 18),
                          voiceCard('task', 'Task reminders'),
                          voiceCard('timer', 'App-timer nudges'),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  'Read reminder text after my clip',
                                  style: TextStyle(fontSize: 13)),
                              subtitle: const Text(
                                  'Uses the phone’s system voice. With no clip, the system voice reads the reminder.',
                                  style: TextStyle(fontSize: 11)),
                              value: draft.readText,
                              onChanged: (v) =>
                                  setState(() => draft.readText = v)),
                          settingSlider('Voice volume', draft.volume, 0, 1,
                              (v) => update(() => draft.volume = v),
                              display: '${(draft.volume * 100).round()}%',
                              divisions: 20),
                          settingSlider('System voice speed', draft.rate, .7,
                              1.4, (v) => update(() => draft.rate = v),
                              display: '${draft.rate.toStringAsFixed(2)}×',
                              divisions: 14),
                          settingSlider('System voice pitch', draft.pitch, .7,
                              1.4, (v) => update(() => draft.pitch = v),
                              display: draft.pitch.toStringAsFixed(2),
                              divisions: 14),
                          Wrap(spacing: 8, children: [
                            OutlinedButton(
                                onPressed: () =>
                                    widget.onPreview(draft.copy(), 'task'),
                                child: const Text('Test task visit')),
                            OutlinedButton(
                                onPressed: () =>
                                    widget.onPreview(draft.copy(), 'timer'),
                                child: const Text('Test timer visit'))
                          ])
                        ])),
                    if (!widget.isNew && widget.model.pets.length > 1)
                      TextButton.icon(
                          onPressed: () async {
                            final count = widget.model.tasks
                                .where((t) => t.companionId == draft.id)
                                .length;
                            final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                        title: Text('Remove ${draft.name}?'),
                                        content: Text(
                                            '$count tasks and any assigned timers will move to another companion. Your tasks will be kept.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, false),
                                              child: const Text('Cancel')),
                                          FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, true),
                                              child: const Text(
                                                  'Remove companion'))
                                        ]));
                            if (confirmed == true) {
                              await widget.model.removePet(draft.id);
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove companion')),
                  ]))),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
              decoration: const BoxDecoration(
                  color: cream, border: Border(top: BorderSide(color: line))),
              child: FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          if (name.text.trim().isEmpty) {
                            setState(
                                () => error = 'Give this companion a name.');
                            return;
                          }
                          setState(() => saving = true);
                          draft.name = name.text.trim();
                          await widget.model.savePet(draft.copy());
                          if (!context.mounted) return;
                          if (widget.model.error != null) {
                            setState(() {
                              saving = false;
                              error = widget.model.error;
                            });
                            return;
                          }
                          saved = true;
                          final previous = [
                            widget.pet.taskClip,
                            widget.pet.timerClip
                          ];
                          for (final uri in previous) {
                            if (uri.isNotEmpty &&
                                uri != draft.taskClip &&
                                uri != draft.timerClip) {
                              VoiceTools.deleteClip(uri);
                            }
                          }
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(saving ? 'Saving…' : 'Save companion')))));
}

class RecordingDialog extends StatefulWidget {
  const RecordingDialog({super.key});
  @override
  State<RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<RecordingDialog> {
  bool recording = false, busy = false, finished = false;
  int seconds = 0;
  Timer? clock;
  String? error;
  @override
  void dispose() {
    clock?.cancel();
    if (!finished) VoiceTools.cancelRecording().catchError((_) {});
    super.dispose();
  }

  Future<void> start() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await VoiceTools.startRecording();
      if (!mounted) {
        VoiceTools.cancelRecording();
        return;
      }
      setState(() {
        busy = false;
        recording = true;
        seconds = 0;
      });
      clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => seconds++);
        if (seconds >= 60) stop();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'Could not start recording. Allow microphone access or import an audio file.';
        });
      }
    }
  }

  Future<void> stop() async {
    clock?.cancel();
    setState(() => busy = true);
    try {
      final clip = await VoiceTools.stopRecording();
      if (!mounted) return;
      finished = true;
      Navigator.pop(context, clip);
    } catch (e) {
      if (mounted) {
        setState(() {
          recording = false;
          busy = false;
          error = 'Could not save this recording. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: AlertDialog(
          title: const Text('Record your companion’s voice'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 42, color: green),
            const SizedBox(height: 16),
            Text(
                recording
                    ? '0:${seconds.toString().padLeft(2, '0')} / 1:00'
                    : 'Ready when you are.',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text(
                'Keep the app open while recording. Microphone access is requested only when you tap Record.',
                style: TextStyle(fontSize: 12, color: muted, height: 1.5)),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!,
                      style: const TextStyle(
                          color: Color(0xFFA34F3E), fontSize: 12)))
          ]),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton.icon(
                onPressed: busy
                    ? null
                    : recording
                        ? stop
                        : start,
                icon: Icon(
                    recording ? Icons.stop_rounded : Icons.mic_none_rounded),
                label: Text(busy
                    ? 'Please wait…'
                    : recording
                        ? 'Stop & use clip'
                        : 'Record'))
          ]));
}
