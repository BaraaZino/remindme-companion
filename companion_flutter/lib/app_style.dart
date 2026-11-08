import 'package:flutter/material.dart';

const ink = Color(0xFF293E34),
    green = Color(0xFF42634D),
    cream = Color(0xFFF8F7F2),
    muted = Color(0xFF767F74),
    line = Color(0xFFE2E7DA),
    mint = Color(0xFFE4EBD9);
Widget panel(Widget child, {Color color = const Color(0xFFFFFEFA)}) =>
    Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: line)),
        child: Material(type: MaterialType.transparency, child: child));
Widget pageTitle(String eyebrow, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(eyebrow.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
              color: green)),
      const SizedBox(height: 10),
      Text(title,
          style: const TextStyle(
              fontSize: 32,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -1)),
      const SizedBox(height: 10),
      Text(subtitle,
          style: const TextStyle(color: muted, fontSize: 14, height: 1.55))
    ]));
Widget sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 12),
    child: Text(text,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)));
Widget settingSlider(String label, double value, double min, double max,
        ValueChanged<double> change,
        {String? display, int? divisions}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13))),
        Text(display ?? '${value.round()}',
            style: const TextStyle(color: green, fontSize: 13))
      ]),
      Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: change)
    ]);
Future<int?> chooseColor(BuildContext context, int current) async {
  final input = TextEditingController(
      text:
          (current & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase());
  int selected = current;
  String? error;
  final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, local) => AlertDialog(
                  title: const Text('Choose a color'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          0xFFD99458,
                          0xFFC47743,
                          0xFF7E9C9A,
                          0xFFB896AD,
                          0xFFE2E0D5,
                          0xFF6F7D69,
                          0xFF293E34,
                          0xFFFFFCF3,
                          0xFFFFE4BB,
                          0xFFBDCFDD,
                          0xFFACC4A2,
                          0xFFE4B6A5
                        ]
                            .map((color) => InkWell(
                                onTap: () {
                                  local(() {
                                    selected = color;
                                    input.text = (color & 0xffffff)
                                        .toRadixString(16)
                                        .padLeft(6, '0')
                                        .toUpperCase();
                                  });
                                },
                                child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                        color: Color(color),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: selected == color
                                                ? green
                                                : line,
                                            width: 3)))))
                            .toList()),
                    const SizedBox(height: 18),
                    TextField(
                        controller: input,
                        maxLength: 6,
                        decoration: InputDecoration(
                            labelText: 'Hex color',
                            prefixText: '#',
                            errorText: error),
                        onChanged: (value) {
                          if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) {
                            local(() => selected =
                                0xff000000 | int.parse(value, radix: 16));
                          }
                        })
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          if (!RegExp(r'^[0-9a-fA-F]{6}$')
                              .hasMatch(input.text)) {
                            local(
                                () => error = 'Enter six hexadecimal digits.');
                            return;
                          }
                          Navigator.pop(context,
                              0xff000000 | int.parse(input.text, radix: 16));
                        },
                        child: const Text('Use color'))
                  ])));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  input.dispose();
  return result;
}
