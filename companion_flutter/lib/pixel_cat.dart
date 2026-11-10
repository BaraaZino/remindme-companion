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
      vsync: this, duration: const Duration(milliseconds: 3840))
    ..repeat();
  int pose = -1;
  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      final next = (controller.value * 96).floor();
      if (next != pose) setState(() => pose = next);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
    } else if (!controller.isAnimating) {
      controller.repeat();
    }
  }

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
          child: RepaintBoundary(
              child: CustomPaint(
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
    void r(int color, num x, num y, num w, num h) {
      p.color = Color(color);
      c.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
          p);
    }

    // A shared 36 × 40 grid, a top-left light source and integer-pixel poses.
    final frame = (phase * 24).floor() % 4;
    final stride = walking ? [0, 1, 0, -1][frame] : 0;
    final hopping = animal == 'bunny' || animal == 'frog';
    final lift = !walking
        ? 0
        : animal == 'turtle'
            ? 0
            : hopping
                ? [0, -1, -2, -1][frame]
                : frame.isOdd
                    ? -1
                    : 0;
    final tail = walking
        ? stride
        : phase > .2 && phase < .5
            ? 1
            : 0;
    final blink = !walking && phase > .92 && phase < .96;
    final breathe = !walking && phase > .35 && phase < .7 ? -1 : 0;
    final bob = lift + breathe;
    const ink = 0xFF3C3B42, pink = 0xFFE6A5A0, gold = 0xFFE6B86C;
    final shade =
        Color.lerp(Color(color), const Color(0xFF41445C), .27)!.toARGB32();
    final light =
        Color.lerp(Color(color), const Color(0xFFFFF2D5), .25)!.toARGB32();
    void box(int fill, int x, int y, int w, int h) {
      // Stepped corners, with a one-pixel outline.
      r(ink, x + 2, y, w - 4, h);
      r(ink, x, y + 2, w, h - 4);
      r(fill, x + 2, y + 1, w - 4, h - 2);
      r(fill, x + 1, y + 2, w - 2, h - 4);
    }

    void eye(int x, int y) {
      r(ink, x, y, 3, blink ? 1 : 4);
      if (!blink) r(0xFFFFFCF0, x, y, 1, 1);
    }

    void paw(int x, int offset, {int? fill}) {
      box(fill ?? color, x + offset, 32 + (offset.abs() == 1 ? -1 : 0), 6, 5);
      r(accent, x + offset + 1, 35 - offset.abs(), 4, 1);
    }

    r(0x18365B45, 6, 38, 24, 1);
    c.save();
    c.translate(
        walking && animal == 'penguin' ? stride.toDouble() : 0, bob.toDouble());

    if (animal == 'turtle') {
      box(color, 25, 21, 9, 10);
      box(shade, 4, 17, 23, 17);
      box(accent, 6, 17, 19, 15);
      box(shade, 11, 21, 10, 8);
      r(light, 8, 20, 3, 4);
      r(shade, 7, 27, 4, 2);
      r(shade, 20, 20, 3, 2);
      eye(29, 23);
      r(pink, 31, 28, 2, 1);
      paw(7, stride);
      paw(23, -stride);
    } else if (animal == 'monkey') {
      // Curled tail, round side ears and a pale face mask distinguish the monkey.
      c.save();
      c.translate(0, tail.toDouble());
      r(ink, 1, 19, 3, 12);
      r(ink, 3, 16, 6, 3);
      r(ink, 7, 18, 3, 6);
      r(ink, 5, 22, 4, 3);
      r(ink, 3, 29, 9, 4);
      r(light, 2, 19, 1, 11);
      r(light, 3, 17, 5, 1);
      r(color, 8, 18, 1, 5);
      r(color, 5, 23, 3, 1);
      r(color, 3, 30, 8, 1);
      c.restore();
      box(shade, 12, 24, 17, 12);
      box(color, 12, 23, 16, 11);
      box(accent, 17, 26, 9, 8);
      box(color, 8, 25 + stride, 5, 9);
      box(color, 28, 25 - stride, 5, 9);
      box(accent, 7, 31 + stride, 6, 5);
      box(accent, 28, 31 - stride, 6, 5);
      box(color, 7, 14, 8, 10);
      box(color, 27, 14, 8, 10);
      r(pink, 9, 17, 3, 4);
      r(pink, 30, 17, 3, 4);
      box(color, 11, 11, 20, 19);
      r(color, 18, 8, 5, 4);
      r(light, 19, 9, 3, 2);
      box(accent, 13, 16, 16, 13);
      r(accent, 18, 14, 7, 4);
      r(light, 14, 13, 4, 1);
      eye(16, 19);
      eye(25, 19);
      r(shade, 21, 24, 2, 1);
      r(pink, 14, 25, 2, 1);
      r(pink, 28, 25, 1, 1);
      r(ink, 20, 27, 6, 1);
      if (talking && frame.isOdd) {
        r(ink, 21, 28, 4, 2);
        r(pink, 22, 29, 2, 1);
      }
      paw(13, stride);
      paw(24, -stride);
    } else if (animal == 'frog') {
      box(shade, 6, 25, 25, 11);
      box(color, 9, 23, 19, 11);
      box(accent, 13, 27, 12, 7);
      box(color, 7, 13, 25, 16);
      box(color, 8, 9, 9, 10);
      box(color, 23, 9, 9, 10);
      eye(11, 12);
      eye(26, 12);
      r(light, 16, 15, 5, 1);
      r(pink, 10, 24, 3, 1);
      r(pink, 27, 24, 3, 1);
      r(ink, 17, 25, 8, 1);
      if (talking && frame.isOdd) r(ink, 19, 26, 4, 2);
      paw(4, stride);
      paw(25, -stride);
    } else {
      // Tail silhouettes are drawn behind the body.
      if (animal == 'fox') {
        box(color, 1, 22 + tail, 12, 12);
        box(accent, 1, 20 + tail, 7, 7);
      } else if (animal == 'cat' || animal == 'dog') {
        box(color, 2, 20 + tail, 5, 14);
        if (animal == 'cat') box(color, 1, 16 + tail, 5, 8);
      } else if (animal == 'bunny') {
        box(accent, 3, 27, 8, 7);
      }
      box(shade, 7, 24, 22, 12);
      box(color, 8, 22, 21, 12);
      r(light, 10, 24, 4, 5);
      box(accent, 17, 26, 10, 8);
      if (animal == 'penguin' || animal == 'owl') {
        box(shade, 5, 24 + stride, 5, 10);
        box(shade, 28, 24 - stride, 5, 10);
      }
      // Ears keep each animal readable even as a solid silhouette.
      if (animal == 'bunny') {
        box(color, 11, 2 + (phase > .7 && phase < .8 ? 1 : 0), 6, 17);
        box(color, 24, 1, 6, 18);
        r(pink, 13, 5, 2, 10);
        r(pink, 26, 4, 2, 11);
      } else if (animal == 'bear' || animal == 'panda') {
        box(animal == 'panda' ? accent : color, 9, 10, 8, 9);
        box(animal == 'panda' ? accent : color, 25, 10, 8, 9);
        r(pink, 12, 12, 2, 3);
        r(pink, 28, 12, 2, 3);
      } else if (animal == 'cat' || animal == 'fox' || animal == 'owl') {
        box(color, 10, 8, 7, 12);
        box(color, 25, 8, 7, 12);
        r(animal == 'owl' ? light : pink, 12, 11, 3, 6);
        r(animal == 'owl' ? light : pink, 27, 11, 3, 6);
      }
      box(color, 10, animal == 'penguin' ? 12 : 15, 23, 16);
      r(light, 13, 16, 10, 1);
      r(shade, 30, 19, 2, 8);
      if (animal == 'dog') {
        box(shade, 7, 14 + stride.abs(), 6, 14);
        box(shade, 29, 14 - stride.abs(), 6, 14);
        r(color, 8, 17, 2, 7);
        r(accent, 20, 17, 3, 7);
      }
      if (animal == 'fox' || animal == 'penguin') {
        box(accent, 12, 22, 19, 8);
        if (animal == 'penguin') {
          r(accent, 13, 18, 6, 9);
          r(accent, 24, 18, 6, 9);
        }
      }
      if (animal == 'panda') {
        box(accent, 13, 20, 7, 8);
        box(accent, 25, 20, 7, 8);
      }
      if (animal == 'owl') {
        box(accent, 12, 18, 9, 11);
        box(accent, 23, 18, 9, 11);
        r(shade, 13, 31, 2, 2);
        r(shade, 24, 31, 2, 2);
        r(shade, 18, 33, 2, 1);
      }
      eye(16, 21);
      eye(26, 21);
      if (animal == 'cat') {
        r(shade, 20, 17, 2, 3);
        r(shade, 24, 17, 2, 2);
        r(shade, 11, 25, 3, 1);
        r(shade, 29, 26, 3, 1);
      }
      if (animal == 'penguin' || animal == 'owl') {
        r(gold, 21, 25, 4, 2);
        r(gold, 22, 27, 2, 1);
      } else {
        r(accent, 19, 26, 9, 3);
        r(ink, 22, 26, 3, 2);
        r(pink, 14, 26, 2, 1);
        r(pink, 28, 26, 2, 1);
      }
      r(ink, 23, 29, 3, talking && frame.isOdd ? 3 : 1);
      if (talking && frame.isOdd) r(pink, 24, 31, 1, 1);
      final foot = animal == 'panda'
          ? accent
          : animal == 'penguin' || animal == 'owl'
              ? gold
              : color;
      paw(10, stride, fill: foot);
      paw(25, -stride, fill: foot);
    }
    c.restore();
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
