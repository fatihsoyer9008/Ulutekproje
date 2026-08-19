import 'package:flutter/material.dart';

enum HairStyle { bald, short, side, bob, long, curly, ponytail, quiff }

enum OutfitStyle { suit, blouse, dress, turtleneck, casual }

class PersonAvatarSpec {
  const PersonAvatarSpec({
    required this.skinTone,
    required this.hairColor,
    required this.hairStyle,
    required this.outfitColor,
    required this.outfitStyle,
    this.accentColor,
    this.hasBeard = false,
  });

  final Color skinTone;
  final Color hairColor;
  final HairStyle hairStyle;
  final Color outfitColor;
  final OutfitStyle outfitStyle;
  final Color? accentColor;
  final bool hasBeard;
}

/// Flat, faceless "bust" illustration in a 100x100 logical box, similar in
/// spirit to common stock avatar-picker art: colored circle background
/// (provided by the parent), skin-tone head + shoulders, a hairstyle shape
/// and a simple outfit collar/lapel detail.
class PersonAvatarPainter extends CustomPainter {
  const PersonAvatarPainter(this.spec);

  final PersonAvatarSpec spec;

  static const _headCenter = Offset(50, 40);
  static const _headRadius = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final torsoPath = _torsoPath();
    final skinPaint = Paint()..color = spec.skinTone;
    final hairPaint = Paint()..color = spec.hairColor;
    final outfitPaint = Paint()..color = spec.outfitColor;

    // Hair drawn behind the head reads better for long/bob/curly styles.
    final backHair = _hairPath(behindHead: true);
    if (backHair != null) canvas.drawPath(backHair, hairPaint);

    canvas.drawPath(torsoPath, outfitPaint);
    _paintCollar(canvas);
    canvas.drawCircle(_headCenter, _headRadius, skinPaint);
    if (spec.hasBeard) _paintBeard(canvas);

    final frontHair = _hairPath(behindHead: false);
    if (frontHair != null) canvas.drawPath(frontHair, hairPaint);

    canvas.restore();
  }

  Path _torsoPath() => Path()
    ..moveTo(10, 100)
    ..lineTo(10, 84)
    ..quadraticBezierTo(11, 68, 30, 61)
    ..quadraticBezierTo(40, 57, 50, 57)
    ..quadraticBezierTo(60, 57, 70, 61)
    ..quadraticBezierTo(89, 68, 90, 84)
    ..lineTo(90, 100)
    ..close();

  void _paintCollar(Canvas canvas) {
    final light = Paint()..color = Colors.white.withValues(alpha: .92);
    switch (spec.outfitStyle) {
      case OutfitStyle.suit:
        final lapels = Path()
          ..moveTo(50, 58)
          ..lineTo(38, 78)
          ..lineTo(46, 78)
          ..lineTo(50, 66)
          ..lineTo(54, 78)
          ..lineTo(62, 78)
          ..close();
        canvas.drawPath(lapels, light);
        final tieColor = spec.accentColor ?? spec.outfitColor;
        final tie = Path()
          ..moveTo(47, 62)
          ..lineTo(53, 62)
          ..lineTo(51.5, 72)
          ..lineTo(50, 90)
          ..lineTo(48.5, 72)
          ..close();
        canvas.drawPath(tie, Paint()..color = tieColor);
      case OutfitStyle.blouse:
        final vNeck = Path()
          ..moveTo(50, 58)
          ..lineTo(41, 74)
          ..lineTo(50, 70)
          ..lineTo(59, 74)
          ..close();
        canvas.drawPath(vNeck, light);
      case OutfitStyle.dress:
        final scoop = Path()
          ..moveTo(40, 60)
          ..quadraticBezierTo(50, 74, 60, 60)
          ..quadraticBezierTo(50, 68, 40, 60)
          ..close();
        canvas.drawPath(scoop, light);
        final necklaceColor = spec.accentColor ?? Colors.white;
        canvas.drawCircle(
          const Offset(50, 76),
          2.6,
          Paint()..color = necklaceColor,
        );
      case OutfitStyle.turtleneck:
        final band = RRect.fromRectAndRadius(
          const Rect.fromLTWH(40, 56, 20, 9),
          const Radius.circular(6),
        );
        canvas.drawRRect(
          band,
          Paint()..color = Color.lerp(spec.outfitColor, Colors.black, .18)!,
        );
      case OutfitStyle.casual:
        final crew = Path()
          ..moveTo(42, 60)
          ..quadraticBezierTo(50, 68, 58, 60)
          ..quadraticBezierTo(50, 64, 42, 60)
          ..close();
        canvas.drawPath(crew, light);
    }
  }

  void _paintBeard(Canvas canvas) {
    final beardPath = Path()
      ..addOval(const Rect.fromLTWH(34, 44, 32, 22));
    final headPath = Path()
      ..addOval(
        Rect.fromCircle(center: _headCenter, radius: _headRadius),
      );
    final clipped = Path.combine(
      PathOperation.intersect,
      beardPath,
      headPath,
    );
    canvas.drawPath(clipped, Paint()..color = spec.hairColor);
  }

  Path? _hairPath({required bool behindHead}) {
    final head = Path()
      ..addOval(Rect.fromCircle(center: _headCenter, radius: _headRadius));

    Path ring(double radius, double bottomCutoff) {
      final big = Path()
        ..addOval(Rect.fromCircle(center: _headCenter, radius: radius));
      final donut = Path.combine(PathOperation.difference, big, head);
      final clipRect = Path()
        ..addRect(Rect.fromLTRB(0, 0, 100, bottomCutoff));
      return Path.combine(PathOperation.intersect, donut, clipRect);
    }

    switch (spec.hairStyle) {
      case HairStyle.bald:
        return null;
      case HairStyle.short:
        if (behindHead) return null;
        return ring(_headRadius + 3, 30);
      case HairStyle.side:
        if (behindHead) return null;
        final cap = ring(_headRadius + 4, 32);
        final fringe = Path()
          ..moveTo(66, 24)
          ..quadraticBezierTo(74, 34, 68, 42)
          ..quadraticBezierTo(72, 30, 62, 22)
          ..close();
        return Path.combine(PathOperation.union, cap, fringe);
      case HairStyle.bob:
        if (behindHead) return ring(_headRadius + 5, 58);
        return ring(_headRadius + 5, 30);
      case HairStyle.long:
        if (!behindHead) return ring(_headRadius + 4, 30);
        final cap = ring(_headRadius + 4, 40);
        final leftStrand = RRect.fromRectAndRadius(
          const Rect.fromLTWH(24, 42, 11, 46),
          const Radius.circular(7),
        );
        final rightStrand = RRect.fromRectAndRadius(
          const Rect.fromLTWH(65, 42, 11, 46),
          const Radius.circular(7),
        );
        final strands = Path()
          ..addRRect(leftStrand)
          ..addRRect(rightStrand);
        return Path.combine(PathOperation.union, cap, strands);
      case HairStyle.curly:
        final base = ring(_headRadius + 5, behindHead ? 52 : 30);
        if (!behindHead) return base;
        var bumps = base;
        const bumpCenters = [
          Offset(28, 40),
          Offset(26, 52),
          Offset(30, 62),
          Offset(72, 40),
          Offset(74, 52),
          Offset(70, 62),
        ];
        for (final center in bumpCenters) {
          final bump = Path()..addOval(Rect.fromCircle(center: center, radius: 6));
          bumps = Path.combine(PathOperation.union, bumps, bump);
        }
        final headCutout = Path.combine(
          PathOperation.difference,
          bumps,
          head,
        );
        return headCutout;
      case HairStyle.ponytail:
        if (!behindHead) return ring(_headRadius + 3, 30);
        final tail = Path()
          ..moveTo(70, 34)
          ..quadraticBezierTo(84, 40, 80, 58)
          ..quadraticBezierTo(76, 68, 72, 60)
          ..quadraticBezierTo(78, 46, 66, 32)
          ..close();
        return tail;
      case HairStyle.quiff:
        if (behindHead) return null;
        final cap = ring(_headRadius + 2, 26);
        final tuft = Path()
          ..moveTo(44, 20)
          ..quadraticBezierTo(50, 4, 58, 18)
          ..quadraticBezierTo(50, 12, 46, 24)
          ..close();
        return Path.combine(PathOperation.union, cap, tuft);
    }
  }

  @override
  bool shouldRepaint(covariant PersonAvatarPainter oldDelegate) =>
      oldDelegate.spec != spec;
}
