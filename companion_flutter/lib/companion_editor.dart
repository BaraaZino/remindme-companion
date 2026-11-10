import 'dart:async';
import 'package:flutter/material.dart';
import 'companion_model.dart';
import 'pixel_cat.dart';
import 'animal_catalog.dart';
import 'animal_voices.dart';
import 'package:flutter/services.dart';
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

class _CompanionEditorState extends State<CompanionEditor>
    with WidgetsBindingObserver {
  late Pet draft = widget.pet.copy();
  late final name = TextEditingController(text: draft.name);
  final List<String> imported = [];
  bool saving = false, saved = false;
  int section = 0;
  String previewPose = 'Idle';
  String? error;
  String? previewingVoice;
  int audition = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      VoiceTools.stopPlayback().catchError((_) {});
    }
  }

  Future<void> previewVoice(AnimalVoice voice) async {
    final token = ++audition;
    final stop = previewingVoice == voice.id;
    setState(() => previewingVoice = stop ? null : voice.id);
    widget.visits.suspend();
    try {
      await VoiceTools.stopPlayback();
      if (token != audition) return;
      if (!stop) {
        await VoiceTools.playClip(
            AnimalVoices.preview(draft, voice.id), draft.volume);
      }
    } catch (_) {
      if (mounted && token == audition) {
        setState(() => error = 'Could not play this sample. Please try again.');
      }
    } finally {
      if (token == audition) {
        if (mounted) setState(() => previewingVoice = null);
        widget.visits.resume();
      }
    }
  }

  void selectVoice(String id) => setState(() {
        draft.voicePreset = id;
        draft.voiceEnabled = true;
      });

  Future<void> soundCredits() async {
    final text =
        await rootBundle.loadString('assets/audio/animal_voices/CREDITS.txt');
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (context) =>
            AlertDialog(
                title: const Text('Companion sound credits'),
                content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                        child: SelectableText(text,
                            style:
                                const TextStyle(fontSize: 12, height: 1.5)))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ]));
  }

  Widget voiceOption(String id, String title, String subtitle,
          {Widget? trailing}) =>
      ListTile(
          contentPadding: EdgeInsets.zero,
          key: ValueKey('voice-option-$id'),
          leading: Icon(
              draft.voicePreset == id
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: draft.voicePreset == id ? green : muted),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 12, color: muted)),
          selected: draft.voicePreset == id,
          onTap: () => selectVoice(id),
          trailing: trailing);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    audition++;
    if (previewingVoice != null) {
      VoiceTools.stopPlayback().catchError((_) {});
      widget.visits.resume();
    }
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
    audition++;
    previewingVoice = null;
    await VoiceTools.stopPlayback();
    if (!mounted) return;
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
          draft.voicePreset = 'custom';
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
          backgroundColor: cream,
          actions: [
            IconButton(
                tooltip: 'Preview reminder visit',
                onPressed: () => widget.onPreview(draft.copy(), 'task'),
                icon: const Icon(Icons.play_circle_outline_rounded))
          ]),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                  children: [
                    panel(
                        Column(children: [
                          Opacity(
                              opacity: draft.opacity,
                              child: PixelCat(
                                  size: draft.size.clamp(48, 160),
                                  walking: previewPose == 'Walk',
                                  talking: previewPose == 'Talk',
                                  animal: draft.animal,
                                  name: draft.name,
                                  color: draft.color,
                                  accent: draft.accent)),
                          Wrap(
                              spacing: 6,
                              children: ['Idle', 'Walk', 'Talk']
                                  .map((pose) => ChoiceChip(
                                      label: Text(pose),
                                      selected: previewPose == pose,
                                      showCheckmark: false,
                                      onSelected: (_) =>
                                          setState(() => previewPose = pose)))
                                  .toList()),
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
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      for (final (i, title, icon) in [
                        (0, 'Look', Icons.pets_outlined),
                        (1, 'Bubble', Icons.chat_bubble_outline_rounded),
                        (2, 'Movement', Icons.directions_walk_rounded),
                        (3, 'Voice', Icons.mic_none_rounded)
                      ])
                        ChoiceChip(
                            key: ValueKey('companion-section-$i'),
                            avatar: Icon(icon, size: 17),
                            label: Text(title),
                            selected: section == i,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => section = i))
                    ]),
                    const SizedBox(height: 16),
                    if (section == 0) ...[
                      sectionTitle('Meet your companion'),
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
                            const Text('Choose an animal',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            const Text(
                                'Your colors stay with you when you switch animals.',
                                style: TextStyle(color: muted, fontSize: 12)),
                            const SizedBox(height: 12),
                            LayoutBuilder(builder: (context, constraints) {
                              final columns =
                                  constraints.maxWidth < 340 ? 2 : 3;
                              final width =
                                  (constraints.maxWidth - (columns - 1) * 8) /
                                      columns;
                              return Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final animal in animalDesigns)
                                  SizedBox(
                                      width: width,
                                      child: Semantics(
                                          selected: draft.animal == animal.id,
                                          button: true,
                                          child: Material(
                                              color: draft.animal == animal.id
                                                  ? mint
                                                  : cream,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  side: BorderSide(
                                                      color: draft.animal ==
                                                              animal.id
                                                          ? green
                                                          : line,
                                                      width: draft.animal ==
                                                              animal.id
                                                          ? 2
                                                          : 1)),
                                              clipBehavior: Clip.antiAlias,
                                              child: InkWell(
                                                  onTap: () => setState(() =>
                                                      draft.animal = animal.id),
                                                  child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                              vertical: 10),
                                                      child: Column(children: [
                                                        PixelCat(
                                                            size: 64,
                                                            walking: false,
                                                            animal: animal.id,
                                                            name: animal.label,
                                                            color: animal.color,
                                                            accent:
                                                                animal.accent),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(animal.label,
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700)),
                                                      ]))))))
                              ]);
                            }),
                            const SizedBox(height: 12),
                            Text(animalDesign(draft.animal).description,
                                style: const TextStyle(
                                    color: muted, fontSize: 12)),
                            TextButton.icon(
                                onPressed: () => setState(() {
                                      final design = animalDesign(draft.animal);
                                      draft.color = design.color;
                                      draft.accent = design.accent;
                                    }),
                                icon: const Icon(Icons.palette_outlined,
                                    size: 18),
                                label: const Text('Use suggested colors')),
                            color('Body color', draft.color,
                                (c) => draft.color = c),
                            color('Accent color', draft.accent,
                                (c) => draft.accent = c),
                            settingSlider('Animal size', draft.size, 48, 160,
                                (v) => update(() => draft.size = v),
                                display: '${(draft.size / 88 * 100).round()}%',
                                divisions: 112),
                            settingSlider('Opacity', draft.opacity, .7, 1,
                                (v) => update(() => draft.opacity = v),
                                display: '${(draft.opacity * 100).round()}%',
                                divisions: 30)
                          ])),
                    ],
                    if (section == 1) ...[
                      sectionTitle('Text bubble'),
                      panel(Column(children: [
                        pick('Font', draft.font, ['rounded', 'serif', 'mono'],
                            (v) => draft.font = v),
                        settingSlider('Font size', draft.fontSize, 12, 24,
                            (v) => update(() => draft.fontSize = v),
                            display: '${draft.fontSize.round()}',
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
                    ],
                    if (section == 2) ...[
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
                            display: '${(draft.speed / 90 * 100).round()}%',
                            divisions: 120),
                        const Text(
                            'Walk in → stop and talk → keep walking off-screen.',
                            style: TextStyle(fontSize: 12, color: muted))
                      ])),
                    ],
                    if (section == 3) ...[
                      sectionTitle('Voice & recordings'),
                      panel(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                    'Enable this companion’s voice',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                value: draft.voiceEnabled,
                                onChanged: (v) =>
                                    setState(() => draft.voiceEnabled = v)),
                            const Text('Choose a voice',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            const Text(
                                'Each built-in voice has 3 variations. A different clip is picked for each visit, with no back-to-back repeats.',
                                style: TextStyle(
                                    fontSize: 12, color: muted, height: 1.5)),
                            for (final voice in voicesFor(draft.animal))
                              voiceOption(voice.id, voice.label,
                                  '${voice.description} · 3 clips',
                                  trailing: IconButton(
                                      key:
                                          ValueKey('preview-voice-${voice.id}'),
                                      tooltip: previewingVoice == voice.id
                                          ? 'Stop sample'
                                          : 'Listen to ${voice.label}',
                                      onPressed: () => previewVoice(voice),
                                      icon: Icon(previewingVoice == voice.id
                                          ? Icons.stop_rounded
                                          : Icons.play_arrow_rounded))),
                            Text(
                                draft.animal == 'turtle'
                                    ? 'Original cartoon chirps, rather than real turtle calls.'
                                    : draft.animal == 'bunny'
                                        ? 'Rabbit eating and rustling sounds, rather than vocal calls.'
                                        : 'Sound-designed animal styles with pitch and timing variations.',
                                style: const TextStyle(
                                    fontSize: 12, color: muted, height: 1.5)),
                            TextButton.icon(
                                onPressed: soundCredits,
                                icon: const Icon(Icons.info_outline_rounded,
                                    size: 16),
                                label: const Text('Sound sources & credits')),
                            const Divider(),
                            voiceOption('custom', 'My recordings',
                                'Record or import your own audio. Saved clips are kept when you switch voices.'),
                            voiceOption('system', 'System voice only',
                                'Read the reminder aloud without an animal sound.'),
                            if (draft.voicePreset == 'custom') ...[
                              const SizedBox(height: 12),
                              const Text(
                                  'Up to 60 seconds / 5 MB per clip. The bubble always shows the actual reminder.',
                                  style: TextStyle(
                                      fontSize: 12, color: muted, height: 1.5)),
                              const SizedBox(height: 12),
                              voiceCard('task', 'Task reminders'),
                              voiceCard('timer', 'App-timer nudges'),
                            ],
                            if (draft.voicePreset != 'system')
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                      'Read reminder text after the sound',
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
                    ],
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
                            setState(() {
                              error = 'Give this companion a name.';
                              section = 0;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Give this companion a name.')));
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
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(error!)));
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
