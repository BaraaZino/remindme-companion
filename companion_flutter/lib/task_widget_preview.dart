import 'package:flutter/material.dart';
import 'companion_model.dart';
import 'pixel_cat.dart';

/// Interactive visual counterpart to the Android RemoteViews home-screen widget.
class TaskWidgetPreview extends StatelessWidget {
  const TaskWidgetPreview(
      {super.key, required this.model, required this.onAdd});
  final CompanionModel model;
  final VoidCallback onAdd;
  static const green = Color(0xFF42634D),
      ink = Color(0xFF293E34),
      muted = Color(0xFF767F74);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final tasks = model.visibleTasks('All tasks');
        return Container(
            height: 350,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFF8F7F2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFDAE2D2))),
            child: Column(children: [
              Row(children: [
                PixelCat(
                    size: 30,
                    walking: false,
                    name: model.defaultPet.name,
                    animal: model.defaultPet.animal,
                    color: model.defaultPet.color,
                    accent: model.defaultPet.accent),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('My small steps',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ink))),
                const SizedBox(width: 6),
                Text('${tasks.length}',
                    style: const TextStyle(fontSize: 12, color: green))
              ]),
              const SizedBox(height: 6),
              Expanded(
                  child: tasks.isEmpty
                      ? const Center(
                          child: Text(
                              'A little room to begin.\nAdd your first small step below.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: muted, height: 1.5)))
                      : ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final due = task.due == 0
                                ? ''
                                : ' · ${MaterialLocalizations.of(context).formatShortDate(DateTime.fromMillisecondsSinceEpoch(task.due))}';
                            return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Row(children: [
                                  IconButton(
                                      tooltip: 'Complete ${task.title}',
                                      onPressed: () => model.toggle(task),
                                      icon: const Icon(
                                          Icons.radio_button_unchecked,
                                          size: 23,
                                          color: green)),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(task.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: ink,
                                                fontWeight: FontWeight.w600,
                                                height: 1.4)),
                                        const SizedBox(height: 3),
                                        Text(
                                            '${task.list} · ${model.pet(task.companionId).name}$due',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11, color: muted))
                                      ])),
                                  IconButton(
                                      tooltip: 'Delete ${task.title}',
                                      onPressed: () => model.remove(task),
                                      icon: const Icon(Icons.close_rounded,
                                          size: 20, color: Color(0xFF8C7869))),
                                ]));
                          })),
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE4EBD9),
                          foregroundColor: green,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: onAdd,
                      icon: const Icon(Icons.add, size: 19),
                      label: const Text('Add a task',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)))),
            ]));
      });
}
