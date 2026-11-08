import 'dart:math' as math;
import 'package:flutter/material.dart';

class PixelCat extends StatefulWidget {
  const PixelCat(
      {super.key,
      this.size = 100,
      this.walking = true,
      this.talking = false,
      this.onTap,
      this.animal = 'cat',
      this.name = 'Mochi',
      this.color = 0xFFD99458,
      this.accent = 0xFFFFE4BB,
      this.faceRight = true});
  final double size;
  final bool walking, talking, faceRight;
  final String animal, name;
  final int color, accent;
  final VoidCallback? onTap;
  @override
  State<PixelCat> createState() => _PixelCatState();
}

class _PixelCatState extends State<PixelCat>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 720))
    ..repeat();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: '${widget.name}, your ${widget.animal} companion',
      button: widget.onTap != null,
      child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => CustomPaint(
                  size: Size.square(widget.size),
                  painter: AnimalPainter(
                      phase: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : controller.value,
                      walking: widget.walking,
                      talking: widget.talking,
                      animal: widget.animal,
                      color: widget.color,
                      accent: widget.accent,
                      faceRight: widget.faceRight)))));
}

class AnimalPainter extends CustomPainter {
  AnimalPainter(
      {required this.phase,
      required this.walking,
      required this.talking,
      required this.animal,
      required this.color,
      required this.accent,
      required this.faceRight});
  final double phase;
  final bool walking, talking, faceRight;
  final String animal;
  final int color, accent;
  @override
  void paint(Canvas c, Size size) {
    final p = Paint()..isAntiAlias = false;
    c.save();
    final s = math.min(size.width / 36, size.height / 40);
    c.translate((size.width - 36 * s) / 2, (size.height - 40 * s) / 2);
    c.scale(s, s);
    if (!faceRight) {
      c.translate(36, 0);
      c.scale(-1, 1);
    }
    void r(int color, double x, double y, double w, double h) {
      p.color = Color(color);
      c.drawRect(Rect.fromLTWH(x, y, w, h), p);
    }

    final step = walking && phase > .5 ? 1.0 : 0.0;
    const ink = 0xFF483A2E;
    r(0x18365B45, 5, 37, 26, 1);
    r(color, 5, 25, 23, 9);
    r(color, 12, 15, 18, 14);
    if (animal == 'bunny') {
      r(color, 13, 2, 5, 15);
      r(color, 24, 2, 5, 15);
      r(accent, 14, 4, 3, 11);
      r(accent, 25, 4, 3, 11);
      r(accent, 1, 27, 6, 6);
    } else if (animal == 'dog') {
      r(accent, 9, 14, 6, 15);
      r(accent, 27, 14, 6, 15);
      r(color, 1, 20 + step, 5, 13);
    } else {
      r(color, 12, 9, 5, 9);
      r(color, 25, 9, 5, 9);
      r(accent, 13, 11, 3, 5);
      r(accent, 26, 11, 3, 5);
      r(color, 2, 21, 4, 12);
      r(color, 0, 16 + step, 4, 9);
      if (animal == 'fox') r(accent, 0, 16 + step, 4, 5);
    }
    if (animal == 'cat') {
      r(accent, 17, 15, 2, 5);
      r(accent, 23, 15, 2, 5);
      r(accent, 7, 26, 3, 5);
    }
    r(ink, 17, 22, 2, 3);
    r(ink, 26, 22, 2, 3);
    r(accent, 19, 27, 8, 4);
    r(ink, 22, 27, 2, 1);
    r(ink, 23, 29, 2, talking && phase > .5 ? 3 : 1);
    r(color, 9 + step, 33, 4, 3 - step);
    r(color, 24 - step, 33, 4, 2 + step);
    r(accent, 9 + step, 35 - step, 4, 1);
    r(accent, 24 - step, 34 + step, 4, 1);
    c.restore();
  }

  @override
  bool shouldRepaint(AnimalPainter old) =>
      phase != old.phase ||
      walking != old.walking ||
      talking != old.talking ||
      animal != old.animal ||
      color != old.color ||
      accent != old.accent ||
      faceRight != old.faceRight;
}
