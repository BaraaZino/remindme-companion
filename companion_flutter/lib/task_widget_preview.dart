import 'package:flutter/material.dart';
import 'companion_model.dart';

/// Interactive counterpart of the compact Android RemoteViews task list.
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
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDAE2D2))),
            child: Column(children: [
              Container(
                  height: 48,
                  color: green,
                  padding: const EdgeInsets.only(left: 14),
                  child: Row(children: [
                    const Expanded(
                        child: Text('My tasks',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white))),
                    IconButton(
                        tooltip: 'Add a task',
                        onPressed: onAdd,
                        icon: const Icon(Icons.add,
                            size: 28, color: Colors.white))
                  ])),
              Expanded(
                  child: tasks.isEmpty
                      ? const Center(
                          child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('No tasks. Tap + to add one.',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontSize: 13, color: muted))))
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: tasks.length,
                          separatorBuilder: (context, index) => const Divider(
                              height: 1, color: Color(0xFFEEF0EC)),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 56),
                                child: Row(children: [
                                  IconButton(
                                      tooltip: 'Complete ${task.title}',
                                      onPressed: () => model.toggle(task),
                                      icon: const Icon(
                                          Icons.radio_button_unchecked,
                                          size: 23,
                                          color: green)),
                                  Expanded(
                                      child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              0, 8, 12, 8),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(task.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        color: ink)),
                                                const SizedBox(height: 3),
                                                Text(task.list,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: muted))
                                              ])))
                                ]));
                          })),
              const SizedBox(height: 8)
            ]));
      });
}
