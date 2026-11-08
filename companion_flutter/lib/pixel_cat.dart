import 'dart:math' as math;

import 'package:flutter/material.dart';

class PixelCat extends StatefulWidget {
  const PixelCat({super.key, this.size = 100, this.walking = true, this.onTap});
  final double size;
  final bool walking;
  final VoidCallback? onTap;
  @override
  State<PixelCat> createState() => _PixelCatState();
}

class _PixelCatState extends State<PixelCat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..repeat();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Mochi, your ginger pixel cat',
        button: widget.onTap != null,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: CatPainter(
                widget.walking && !MediaQuery.disableAnimationsOf(context)
                    ? _controller.value
                    : 0,
              ),
            ),
          ),
        ),
      );
}

class CatPainter extends CustomPainter {
  CatPainter(this.phase);
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    canvas.save();
    final scale = math.min(size.width / 36, size.height / 34);
    canvas.translate(
      (size.width - 36 * scale) / 2,
      (size.height - 34 * scale) / 2,
    );
    canvas.scale(scale);
    void r(int c, double x, double y, double w, double h) {
      paint.color = Color(c);
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    }

    const fur = 0xFFD99458,
        stripe = 0xFFAF6C3C,
        ink = 0xFF483A2E,
        cream = 0xFFFFE4BB;
    final step = phase < .5 ? 0.0 : 1.0;
    r(0x14365B45, 5, 31, 26, 1);
    r(fur, 5, 20, 23, 8);
    r(fur, 12, 10, 18, 15);
    r(fur, 12, 4, 5, 9);
    r(fur, 25, 4, 5, 9);
    r(0xFFEFB598, 13, 6, 3, 5);
    r(0xFFEFB598, 26, 6, 3, 5);
    r(fur, 2, 16, 4, 10);
    r(fur, 1, 12 + step, 3, 6);
    r(fur, 0, 10 + step, 3, 4);
    r(stripe, 7, 20, 3, 5);
    r(stripe, 17, 10, 2, 4);
    r(stripe, 23, 10, 2, 4);
    r(ink, 17, 17, 2, 3);
    r(ink, 26, 17, 2, 3);
    r(cream, 19, 22, 8, 3);
    r(ink, 22, 22, 2, 1);
    r(ink, 23, 24, 2, 1);
    r(0xFFEDB690, 15, 21, 3, 1);
    r(0xFFEDB690, 28, 21, 3, 1);
    r(fur, 9 + step, 27, 4, 3 - step);
    r(fur, 24 - step, 27, 4, 2 + step);
    r(cream, 9 + step, 29 - step, 4, 1);
    r(cream, 24 - step, 28 + step, 4, 1);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CatPainter oldDelegate) => oldDelegate.phase != phase;
}
