import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ilustración propia: identifica una familia de relojes, no un modelo enlazado.
class DeviceWatchArtwork extends StatelessWidget {
  const DeviceWatchArtwork({
    super.key,
    required this.accent,
    this.square = false,
  });

  final Color accent;
  final bool square;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 118,
      width: 118,
      child: CustomPaint(painter: _WatchPainter(accent, square)),
    ),
  );
}

class _WatchPainter extends CustomPainter {
  const _WatchPainter(this.accent, this.square);

  final Color accent;
  final bool square;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 118, size.height / 118);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [accent.withValues(alpha: .17), accent.withValues(alpha: 0)],
      ).createShader(const Rect.fromLTWH(0, 0, 118, 118));
    canvas.drawCircle(const Offset(59, 59), 59, glow);
    final strap = RRect.fromRectAndRadius(
      const Rect.fromLTWH(42, 2, 34, 114),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      strap,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff252d36), Color(0xff3b4650), Color(0xff1c232b)],
        ).createShader(strap.outerRect),
    );
    for (var y = 8.0; y < 116; y += 6) {
      canvas.drawLine(
        Offset(47, y),
        Offset(71, y),
        Paint()..color = const Color(0xff111820).withValues(alpha: .6),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(square ? 88 : 92, 46, 5, 13),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xff8b9299),
    );
    final frame = square
        ? RRect.fromRectAndRadius(
            const Rect.fromLTWH(27, 23, 64, 75),
            const Radius.circular(17),
          )
        : RRect.fromRectAndRadius(
            const Rect.fromLTWH(21, 21, 76, 76),
            const Radius.circular(38),
          );
    canvas.drawShadow(Path()..addRRect(frame), Colors.black, 8, false);
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffb6bdc5), Color(0xff3d4752), Color(0xff78838d)],
        ).createShader(frame.outerRect),
    );
    canvas.drawRRect(
      frame.deflate(3),
      Paint()..color = const Color(0xff111820),
    );
    final screen = frame.deflate(square ? 5 : 8);
    canvas.drawRRect(screen, Paint()..color = const Color(0xff060b10));
    canvas.save();
    canvas.clipRRect(screen);
    if (square) {
      for (var i = 0; i < 3; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(59, 66), radius: 18 - i * 5),
          -math.pi / 2,
          math.pi * (1.7 - i * .18),
          false,
          Paint()
            ..color = [
              accent,
              const Color(0xffb9e85a),
              const Color(0xff5bded0),
            ][i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
      _text(canvas, '10:09', const Offset(59, 37), 10, Colors.white);
    } else {
      for (var i = 0; i < 12; i++) {
        final angle = i * math.pi / 6;
        canvas.drawLine(
          Offset(59 + math.sin(angle) * 27, 59 + math.cos(angle) * 27),
          Offset(59 + math.sin(angle) * 29, 59 + math.cos(angle) * 29),
          Paint()..color = const Color(0xff677786),
        );
      }
      canvas.drawArc(
        const Rect.fromLTWH(35, 35, 48, 48),
        -math.pi / 2,
        math.pi * 1.45,
        false,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      _text(canvas, '10:09', const Offset(59, 51), 16, Colors.white);
      canvas.drawLine(
        const Offset(48, 72),
        const Offset(70, 72),
        Paint()
          ..color = accent.withValues(alpha: .8)
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
    canvas.restore();
  }

  void _text(
    Canvas canvas,
    String value,
    Offset center,
    double size,
    Color color,
  ) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(_WatchPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.square != square;
}
