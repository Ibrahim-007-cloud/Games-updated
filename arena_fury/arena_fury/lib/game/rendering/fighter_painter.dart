import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../data/models/fighter_config.dart';
import 'pose.dart';

Color _lighten(Color c, double t) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;
Color _darken(Color c, double t) => Color.lerp(c, const Color(0xFF000000), t)!;

/// Colours for each body part, derived from costume + config colours.
class _Palette {
  _Palette({
    required this.torso,
    required this.trim,
    required this.sleeve,
    required this.forearm,
    required this.glove,
    required this.pants,
    required this.shin,
    required this.shoe,
    required this.skin,
    required this.hair,
    required this.belt,
    required this.outline,
  });

  final Color torso, trim, sleeve, forearm, glove, pants, shin, shoe, skin, hair, belt, outline;

  bool get bareUpperArm => sleeve == skin;
  bool get bareForearm => forearm == skin;

  factory _Palette.resolve(FighterConfig c, Color Function(Color) fx) {
    final p = c.primaryColor, s = c.secondaryColor, k = c.skinColor;
    late Color torso, trim, sleeve, forearm, glove, pants, shin, shoe, belt;
    switch (c.costume) {
      case Costume.gi: // martial-arts gi, short sleeves, cloth foot wraps
        torso = p;
        trim = _lighten(s, 0.1);
        sleeve = p;
        forearm = k;
        glove = s;
        pants = p;
        shin = p;
        shoe = const Color(0xFFEFEBE9);
        belt = s;
      case Costume.street: // zip hoodie, jeans, sneakers
        torso = p;
        trim = s;
        sleeve = p;
        forearm = p;
        glove = k;
        pants = const Color(0xFF2E3B55);
        shin = const Color(0xFF2E3B55);
        shoe = const Color(0xFFF5F5F5);
        belt = const Color(0xFF3E2723);
      case Costume.armor: // sleeveless plate, bracers, greaves
        torso = s;
        trim = p;
        sleeve = k;
        forearm = p;
        glove = _darken(p, 0.3);
        pants = s;
        shin = p;
        shoe = _darken(p, 0.35);
        belt = p;
      case Costume.ninja: // hooded wraps
        torso = p;
        trim = s;
        sleeve = p;
        forearm = p;
        glove = _darken(p, 0.4);
        pants = p;
        shin = s;
        shoe = _darken(p, 0.4);
        belt = s;
      case Costume.coat: // long high-collared storm coat, boots
        torso = p;
        trim = s;
        sleeve = p;
        forearm = p;
        glove = const Color(0xFF1B1B1B);
        pants = const Color(0xFF263238);
        shin = const Color(0xFF263238);
        shoe = const Color(0xFF1B1B1B);
        belt = s;
    }
    return _Palette(
      torso: fx(torso),
      trim: fx(trim),
      sleeve: fx(sleeve),
      forearm: fx(forearm),
      glove: fx(glove),
      pants: fx(pants),
      shin: fx(shin),
      shoe: fx(shoe),
      skin: fx(k),
      hair: fx(c.hairColor),
      belt: fx(belt),
      outline: const Color(0xFF111118),
    );
  }

  /// Darker copy for the limbs on the far side of the body.
  _Palette shaded() => _Palette(
        torso: _darken(torso, 0.22),
        trim: _darken(trim, 0.22),
        sleeve: bareUpperArm ? _darken(skin, 0.22) : _darken(sleeve, 0.22),
        forearm: bareForearm ? _darken(skin, 0.22) : _darken(forearm, 0.22),
        glove: _darken(glove, 0.22),
        pants: _darken(pants, 0.22),
        shin: _darken(shin, 0.22),
        shoe: _darken(shoe, 0.22),
        skin: _darken(skin, 0.22),
        hair: hair,
        belt: belt,
        outline: outline,
      );
}

/// Draws a fighter from shaded, tapered shapes, driven by a [Pose].
///
/// The canvas origin must be at the fighter's FEET, facing RIGHT (+x).
/// Callers mirror the canvas for left-facing fighters. Because this only
/// uses dart:ui, the same painter renders inside Flame components and inside
/// regular Flutter [CustomPainter]s (roster cards, studio preview).
abstract final class FighterPainter {
  static const double thighLen = 46;
  static const double shinLen = 44;
  static const double torsoLen = 60;
  static const double upperArmLen = 32;
  static const double foreArmLen = 31;
  static const double headRadius = 17;
  static const double neckLen = 6;

  static void paint(
    Canvas canvas, {
    required FighterConfig config,
    required Pose pose,
    ui.Image? face,
    double flash = 0,
    Color? aura,
  }) {
    final w = config.bodyType.widthScale;
    final hs = config.bodyType.heightScale;
    final tl = thighLen * hs, sl = shinLen * hs, tor = torsoLen * hs;
    final ua = upperArmLen * hs, fa = foreArmLen * hs;
    const hr = headRadius;

    Color fx(Color c) =>
        flash > 0 ? Color.lerp(c, const Color(0xFFFFFFFF), flash * 0.75)! : c;
    final pal = _Palette.resolve(config, fx);
    final back = pal.shaded();

    double legExtent(double thigh, double shin) =>
        tl * math.cos(thigh) + sl * math.cos(shin);

    // Auto-grounding: the lower of the two feet touches y = 0.
    final hipHeight = math.max(
          12.0,
          math.max(legExtent(pose.frontThigh, pose.frontShin),
              legExtent(pose.backThigh, pose.backShin)),
        ) +
        pose.lift;

    final hip = Offset(0, -hipHeight);
    final up = Offset(math.sin(pose.lean), -math.cos(pose.lean));
    final side = Offset(math.cos(pose.lean), math.sin(pose.lean));
    final shoulder = hip + up * tor;
    final neck = shoulder + up * neckLen;
    final headC = neck + up * (hr * 1.1);

    Offset dir(double a) => Offset(math.sin(a), math.cos(a));

    final frontHip = hip + side * (5 * w);
    final backHip = hip - side * (5 * w);
    final frontShoulder = shoulder + side * (6 * w) - up * 3;
    final backShoulder = shoulder - side * (8 * w) - up * 3;

    final bKnee = backHip + dir(pose.backThigh) * tl;
    final bFoot = bKnee + dir(pose.backShin) * sl;
    final fKnee = frontHip + dir(pose.frontThigh) * tl;
    final fFoot = fKnee + dir(pose.frontShin) * sl;
    final bElbow = backShoulder + dir(pose.backUpper) * ua;
    final bHand = bElbow + dir(pose.backFore) * fa;
    final fElbow = frontShoulder + dir(pose.frontUpper) * ua;
    final fHand = fElbow + dir(pose.frontFore) * fa;

    if (aura != null) {
      final center = Offset.lerp(hip, shoulder, 0.4)!;
      canvas.drawCircle(
        center,
        95,
        Paint()
          ..shader = ui.Gradient.radial(center, 95, [
            aura.withValues(alpha: 0.45),
            aura.withValues(alpha: 0.0),
          ]),
      );
    }

    final costume = config.costume;

    // Painter's order: far limbs -> coat tail -> torso -> near leg -> head -> near arm.
    if (costume == Costume.coat) _coatBackPanel(canvas, hip, up, side, pal, w);
    _arm(canvas, backShoulder, bElbow, bHand, back, w);
    _leg(canvas, backHip, bKnee, bFoot, pose.backShin, back, w, costume);
    if (costume == Costume.street) _hood(canvas, shoulder, up, side, pal, w);
    _torso(canvas, hip, shoulder, side, up, pal, w, costume);
    _leg(canvas, frontHip, fKnee, fFoot, pose.frontShin, pal, w, costume);
    if (costume == Costume.coat) _coatFrontPanel(canvas, hip, up, side, fKnee, pal, w);
    _seg(canvas, shoulder, neck + up * 2, 12 * w, 10 * w, pal.skin, pal.outline);
    if (costume == Costume.coat) _collar(canvas, shoulder, neck, up, side, pal, w);
    _head(canvas, headC, hr, pal, config, face, flash, pose.lean);
    _arm(canvas, frontShoulder, fElbow, fHand, pal, w);
    if (costume == Costume.armor) {
      _pauldron(canvas, frontShoulder + up * 2, up, side, pal, w);
    }
  }

  // ---------------------------------------------------------------------------
  // Primitive: a tapered, shaded limb segment
  // ---------------------------------------------------------------------------

  static void _seg(
    Canvas canvas,
    Offset a,
    Offset b,
    double wa,
    double wb,
    Color color,
    Color outline, {
    bool muscle = false,
  }) {
    final d = b - a;
    final len = d.distance;
    if (len < 0.01) {
      canvas.drawCircle(a, wa / 2, Paint()..color = color);
      return;
    }
    final n = Offset(-d.dy / len, d.dx / len);

    void shape(double grow, Paint paint) {
      final ra = wa / 2 + grow, rb = wb / 2 + grow;
      final p1 = a + n * ra, p2 = b + n * rb, p3 = b - n * rb, p4 = a - n * ra;
      canvas.drawPath(
        Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..lineTo(p4.dx, p4.dy)
          ..close(),
        paint,
      );
      canvas.drawCircle(a, ra, paint);
      canvas.drawCircle(b, rb, paint);
    }

    shape(1.8, Paint()..color = outline);
    final half = math.max(wa, wb) / 2;
    shape(
      0,
      Paint()
        ..shader = ui.Gradient.linear(
          a + n * half,
          a - n * half,
          [_lighten(color, 0.18), color, _darken(color, 0.28)],
          const [0.0, 0.45, 1.0],
        ),
    );

    if (muscle) {
      // Soft highlight on the bulge of bare arms.
      canvas.save();
      final mid = a + d * 0.42 + n * (wa * 0.12);
      canvas.translate(mid.dx, mid.dy);
      canvas.rotate(math.atan2(d.dy, d.dx));
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: len * 0.55, height: wa * 0.32),
        Paint()..color = const Color(0x2EFFFFFF),
      );
      canvas.restore();
    }
  }

  static void _arm(Canvas canvas, Offset sh, Offset el, Offset hand, _Palette pal, double w) {
    _seg(canvas, sh, el, 15 * w, 12 * w, pal.sleeve, pal.outline, muscle: pal.bareUpperArm);
    _seg(canvas, el, hand, 12 * w, 9.5 * w, pal.forearm, pal.outline, muscle: pal.bareForearm);
    // Fist
    final r = 8 * math.sqrt(w);
    canvas.drawCircle(hand, r + 1.8, Paint()..color = pal.outline);
    canvas.drawCircle(
      hand,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          hand - Offset(r * 0.3, r * 0.3),
          r * 1.3,
          [_lighten(pal.glove, 0.25), _darken(pal.glove, 0.2)],
        ),
    );
  }

  static void _leg(Canvas canvas, Offset hip, Offset knee, Offset foot, double shinAngle,
      _Palette pal, double w, Costume costume) {
    _seg(canvas, hip, knee, 19 * w, 14 * w, pal.pants, pal.outline);
    // Gi trousers flare at the ankle; boots and greaves stay straight.
    final ankleW = costume == Costume.gi ? 16 * w : 11 * w;
    _seg(canvas, knee, foot, 14 * w, ankleW, pal.shin, pal.outline);
    final tip = foot + Offset(math.cos(shinAngle), -math.sin(shinAngle)) * 15;
    _seg(canvas, foot, tip, 10 * w, 7 * w, pal.shoe, pal.outline);
  }

  // ---------------------------------------------------------------------------
  // Torso + costume details
  // ---------------------------------------------------------------------------

  static void _torso(Canvas canvas, Offset hip, Offset shoulder, Offset side, Offset up,
      _Palette pal, double w, Costume costume) {
    final waist = Offset.lerp(hip, shoulder, 0.3)!;
    final chest = Offset.lerp(hip, shoulder, 0.72)!;
    final hipH = 13 * w, waistH = 11.5 * w, chestH = 18.5 * w, shH = 20 * w;

    final hipL = hip - side * hipH, hipR = hip + side * hipH;
    final chestL = chest - side * chestH, chestR = chest + side * chestH;
    final shL = shoulder - side * shH, shR = shoulder + side * shH;
    final wL = waist - side * waistH, wR = waist + side * waistH;
    final top = shoulder + up * 7;

    final body = Path()
      ..moveTo(hipL.dx, hipL.dy)
      ..quadraticBezierTo(wL.dx, wL.dy, chestL.dx, chestL.dy)
      ..lineTo(shL.dx, shL.dy)
      ..quadraticBezierTo(top.dx, top.dy, shR.dx, shR.dy)
      ..lineTo(chestR.dx, chestR.dy)
      ..quadraticBezierTo(wR.dx, wR.dy, hipR.dx, hipR.dy)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeJoin = StrokeJoin.round
        ..color = pal.outline,
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          chestL,
          chestR,
          [_darken(pal.torso, 0.28), pal.torso, _lighten(pal.torso, 0.14)],
          const [0.0, 0.55, 1.0],
        ),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (costume) {
      case Costume.gi:
        // Crossed lapels
        final l1 = shoulder - side * (11 * w), l2 = shoulder + side * (11 * w);
        final v = Offset.lerp(shoulder, hip, 0.55)!;
        canvas.drawPath(
          Path()
            ..moveTo(l1.dx, l1.dy)
            ..lineTo(v.dx, v.dy)
            ..lineTo(l2.dx, l2.dy),
          stroke
            ..color = pal.trim
            ..strokeWidth = 4.5,
        );
      case Costume.street:
        // Zip line, pocket and drawstrings
        final z1 = shoulder + up * 2, z2 = hip + up * 4;
        canvas.drawLine(z1, z2, stroke
          ..color = pal.trim
          ..strokeWidth = 2.5);
        final pocket = Offset.lerp(hip, shoulder, 0.2)!;
        canvas.drawLine(pocket - side * (10 * w), pocket + side * (10 * w),
            stroke..color = _darken(pal.torso, 0.35));
        for (final dx in [-4.0, 4.0]) {
          final s0 = shoulder + side * dx;
          canvas.drawLine(s0, s0 - up * 14, stroke
            ..color = pal.trim
            ..strokeWidth = 1.6);
        }
      case Costume.armor:
        // Breastplate with plate seams
        final pt = Offset.lerp(shoulder, hip, 0.08)!;
        final pb = Offset.lerp(shoulder, hip, 0.62)!;
        final plate = Path()
          ..moveTo((pt - side * (15 * w)).dx, (pt - side * (15 * w)).dy)
          ..lineTo((pt + side * (15 * w)).dx, (pt + side * (15 * w)).dy)
          ..quadraticBezierTo((pb + side * (16 * w)).dx, (pb + side * (16 * w)).dy, pb.dx, pb.dy)
          ..quadraticBezierTo((pb - side * (16 * w)).dx, (pb - side * (16 * w)).dy,
              (pt - side * (15 * w)).dx, (pt - side * (15 * w)).dy)
          ..close();
        canvas.drawPath(
          plate,
          Paint()
            ..shader = ui.Gradient.linear(
              pt - side * (15 * w),
              pt + side * (15 * w),
              [_darken(pal.trim, 0.3), pal.trim, _lighten(pal.trim, 0.35)],
              const [0.0, 0.5, 1.0],
            ),
        );
        canvas.drawPath(plate, stroke
          ..color = pal.outline
          ..strokeWidth = 2);
        final seam = Offset.lerp(pt, pb, 0.45)!;
        canvas.drawLine(seam - side * (13 * w), seam + side * (13 * w), stroke
          ..color = _darken(pal.trim, 0.45)
          ..strokeWidth = 1.5);
        _pauldron(canvas, shoulder - side * (8 * w) - up * 1, up, side, pal, w, far: true);
      case Costume.ninja:
        canvas.drawLine(shL, hipR, stroke
          ..color = pal.trim
          ..strokeWidth = 6);
      case Costume.coat:
        // Clasp line down the front
        final c1 = shoulder + side * (4 * w), c2 = hip + side * (5 * w);
        canvas.drawLine(c1, c2, stroke
          ..color = _darken(pal.torso, 0.4)
          ..strokeWidth = 2);
        for (var i = 1; i <= 3; i++) {
          final c = Offset.lerp(c1, c2, i / 4)!;
          canvas.drawCircle(c, 2.2, Paint()..color = pal.trim);
        }
    }

    // Belt / sash
    final belt = hip + up * 7;
    canvas.drawLine(belt - side * (13.5 * w), belt + side * (13.5 * w), stroke
      ..color = pal.belt
      ..strokeWidth = costume == Costume.street ? 4 : 7);
    if (costume == Costume.gi || costume == Costume.ninja) {
      final knot = belt + side * (5 * w);
      canvas.drawLine(knot, knot + side * (3 * w) + const Offset(0, 17), stroke..strokeWidth = 5);
      canvas.drawLine(knot, knot - side * (2 * w) + const Offset(0, 15), stroke..strokeWidth = 4);
    }
  }

  static void _pauldron(Canvas canvas, Offset at, Offset up, Offset side, _Palette pal, double w,
      {bool far = false}) {
    final color = far ? _darken(pal.trim, 0.25) : pal.trim;
    final r = 12 * w;
    final rect = Rect.fromCenter(center: at, width: r * 2.1, height: r * 1.6);
    canvas.drawOval(rect.inflate(1.8), Paint()..color = pal.outline);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          at - Offset(r * 0.3, r * 0.4),
          r * 1.4,
          [_lighten(color, 0.35), _darken(color, 0.25)],
        ),
    );
  }

  static void _hood(Canvas canvas, Offset shoulder, Offset up, Offset side, _Palette pal, double w) {
    // Bunched-up hood resting behind the neck.
    final c = shoulder + up * 6 - side * (9 * w);
    final rect = Rect.fromCenter(center: c, width: 26 * w, height: 16);
    canvas.drawOval(rect.inflate(1.8), Paint()..color = pal.outline);
    canvas.drawOval(rect, Paint()..color = _darken(pal.torso, 0.2));
  }

  static void _collar(Canvas canvas, Offset shoulder, Offset neck, Offset up, Offset side,
      _Palette pal, double w) {
    final bl = shoulder - side * (11 * w), br = shoulder + side * (9 * w);
    final tl = neck + up * 7 - side * (12 * w), tr = neck + up * 3 + side * (8 * w);
    final path = Path()
      ..moveTo(bl.dx, bl.dy)
      ..lineTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = _darken(pal.torso, 0.15));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = pal.trim,
    );
  }

  static Path _coatPanel(Offset topL, Offset topR, Offset botR, Offset botL) => Path()
    ..moveTo(topL.dx, topL.dy)
    ..lineTo(topR.dx, topR.dy)
    ..lineTo(botR.dx, botR.dy)
    ..lineTo(botL.dx, botL.dy)
    ..close();

  static void _drawCoatPanel(Canvas canvas, Path panel, Color color, _Palette pal) {
    canvas.drawPath(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round
        ..color = pal.outline,
    );
    canvas.drawPath(panel, Paint()..color = color);
  }

  /// Rear coat tail: hangs behind the legs and flares backwards.
  static void _coatBackPanel(Canvas canvas, Offset hip, Offset up, Offset side, _Palette pal, double w) {
    final down = -up;
    final topL = hip - side * (14 * w), topR = hip + side * (6 * w);
    final botL = hip + down * 66 - side * (30 * w);
    final botR = hip + down * 70 + side * (2 * w);
    final panel = _coatPanel(topL, topR, botR, botL);
    _drawCoatPanel(canvas, panel, _darken(pal.torso, 0.3), pal);
    canvas.drawLine(botL, botR, Paint()
      ..strokeWidth = 3
      ..color = pal.trim);
  }

  /// Front coat flap: follows the front knee so kicks swing it open.
  static void _coatFrontPanel(Canvas canvas, Offset hip, Offset up, Offset side, Offset fKnee,
      _Palette pal, double w) {
    final topL = hip - side * (2 * w), topR = hip + side * (14 * w);
    final kneeDir = fKnee - hip;
    final kd = kneeDir.distance == 0 ? const Offset(0, 1) : kneeDir / kneeDir.distance;
    final botR = hip + kd * 66 + side * (10 * w);
    final botL = hip + kd * 62 - side * (6 * w);
    final panel = _coatPanel(topL, topR, botR, botL);
    _drawCoatPanel(canvas, panel, pal.torso, pal);
    canvas.drawLine(botL, botR, Paint()
      ..strokeWidth = 3
      ..color = pal.trim);
  }

  // ---------------------------------------------------------------------------
  // Head, hair and selfie compositing
  // ---------------------------------------------------------------------------

  static void _head(Canvas canvas, Offset c, double r, _Palette pal, FighterConfig config,
      ui.Image? face, double flash, double lean) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(lean * 0.4);
    canvas.translate(-c.dx, -c.dy);

    final costume = config.costume;
    final rect = Rect.fromCenter(center: c, width: r * 2 * 0.92, height: r * 2 * 1.12);
    final oval = Path()..addOval(rect);

    // Hair that sits BEHIND the head (ponytail, topknot)
    if (face == null) _hairBack(canvas, c, r, pal, costume);
    if (costume == Costume.ninja) {
      // Hood shell behind/around the head
      final hood = rect.inflate(4);
      canvas.drawOval(hood.inflate(1.8), Paint()..color = pal.outline);
      canvas.drawOval(hood, Paint()..color = _darken(pal.torso, 0.1));
    }

    // Ear + face shape
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(-r * 0.45, r * 0.05), width: 7, height: 10),
      Paint()..color = _darken(pal.skin, 0.15),
    );
    canvas.drawOval(rect.inflate(1.8), Paint()..color = pal.outline);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(r * 0.25, -r * 0.2),
          r * 1.5,
          [_lighten(pal.skin, 0.12), _darken(pal.skin, 0.18)],
        ),
    );

    if (face != null) {
      // ---- Selfie compositing: crop-to-cover and clip into the head oval ----
      final iw = face.width.toDouble(), ih = face.height.toDouble();
      final dstAspect = rect.width / rect.height;
      Rect src;
      if (iw / ih > dstAspect) {
        final sw = ih * dstAspect;
        src = Rect.fromLTWH((iw - sw) / 2, 0, sw, ih);
      } else {
        final sh = iw / dstAspect;
        src = Rect.fromLTWH(0, (ih - sh) * 0.4, iw, sh);
      }
      canvas.save();
      canvas.clipPath(oval);
      final paint = Paint()..filterQuality = FilterQuality.medium;
      if (flash > 0) {
        paint.colorFilter = ColorFilter.mode(
          const Color(0xFFFFFFFF).withValues(alpha: flash * 0.7),
          BlendMode.srcATop,
        );
      }
      canvas.drawImageRect(face, src, rect, paint);
      canvas.restore();
    } else {
      _defaultFace(canvas, c, r, pal, costume);
      _hairFront(canvas, c, r, rect, oval, pal, costume);
    }

    // Costume headwear drawn on top of the face.
    switch (costume) {
      case Costume.gi:
        _headband(canvas, c, r, rect, config.secondaryColor);
      case Costume.ninja:
        if (face == null) {
          // Mask over the lower face
          canvas.save();
          canvas.clipPath(oval);
          canvas.drawRect(
            Rect.fromLTRB(rect.left, c.dy + r * 0.15, rect.right, rect.bottom),
            Paint()..color = pal.torso,
          );
          canvas.restore();
        }
        _headband(canvas, c, r, rect, config.secondaryColor);
      case Costume.armor:
        canvas.drawArc(rect.inflate(2), math.pi * 1.05, math.pi * 0.9, false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..color = pal.trim);
      case Costume.street:
      case Costume.coat:
        break;
    }
    canvas.restore();
  }

  static void _hairBack(Canvas canvas, Offset c, double r, _Palette pal, Costume costume) {
    final hair = Paint()..color = pal.hair;
    final outline = Paint()..color = pal.outline;
    switch (costume) {
      case Costume.gi:
        // Topknot
        final knot = c + Offset(-r * 0.35, -r * 1.05);
        canvas.drawCircle(knot, 6.5, outline);
        canvas.drawCircle(knot, 5, hair);
      case Costume.coat:
        // Long ponytail sweeping back
        final start = c + Offset(-r * 0.7, -r * 0.2);
        final path = Path()
          ..moveTo(start.dx, start.dy - 4)
          ..quadraticBezierTo(start.dx - 22, start.dy + 6, start.dx - 16, start.dy + 34)
          ..quadraticBezierTo(start.dx - 8, start.dy + 14, start.dx + 2, start.dy + 6)
          ..close();
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeJoin = StrokeJoin.round
              ..color = pal.outline);
        canvas.drawPath(path, hair);
      case Costume.street:
      case Costume.armor:
      case Costume.ninja:
        break;
    }
  }

  static void _hairFront(Canvas canvas, Offset c, double r, Rect rect, Path oval, _Palette pal,
      Costume costume) {
    final hair = Paint()..color = pal.hair;
    canvas.save();
    canvas.clipPath(oval);
    switch (costume) {
      case Costume.gi:
      case Costume.coat:
        // Neat cap of hair pulled back
        canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, rect.right, c.dy - r * 0.42), hair);
        canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, c.dx - r * 0.15, c.dy + r * 0.1), hair);
      case Costume.street:
        // Swept fringe falling toward the front
        canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, rect.right, c.dy - r * 0.5), hair);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - r * 0.4, c.dy - r * 0.6)
            ..lineTo(c.dx + r * 1.0, c.dy - r * 0.55)
            ..lineTo(c.dx + r * 0.25, c.dy - r * 0.1)
            ..close(),
          hair,
        );
        canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, c.dx - r * 0.2, c.dy + r * 0.15), hair);
      case Costume.armor:
        // Shaved head + full beard
        canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, rect.right, c.dy - r * 0.45),
            Paint()..color = pal.hair.withValues(alpha: 0.45));
        canvas.drawPath(
          Path()
            ..moveTo(rect.left, c.dy + r * 0.05)
            ..lineTo(c.dx + r * 0.95, c.dy + r * 0.35)
            ..lineTo(c.dx + r * 0.5, rect.bottom + 2)
            ..lineTo(rect.left, rect.bottom)
            ..close(),
          hair,
        );
        // keep the mouth visible
        canvas.drawLine(c + Offset(r * 0.3, r * 0.5), c + Offset(r * 0.7, r * 0.5),
            Paint()
              ..strokeWidth = 1.6
              ..color = _darken(pal.skin, 0.3));
      case Costume.ninja:
        break;
    }
    canvas.restore();
  }

  static void _headband(Canvas canvas, Offset c, double r, Rect rect, Color color) {
    final y = c.dy - r * 0.45;
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = color;
    canvas.drawLine(Offset(rect.left + 1, y + 1), Offset(rect.right - 1, y - 1), p);
    // Tails flowing behind the head.
    canvas.drawLine(Offset(rect.left + 2, y), Offset(rect.left - 15, y + 9), p..strokeWidth = 4);
    canvas.drawLine(Offset(rect.left + 2, y), Offset(rect.left - 11, y + 16), p);
  }

  static void _defaultFace(Canvas canvas, Offset c, double r, _Palette pal, Costume costume) {
    final eyeWhite = Paint()..color = const Color(0xFFFFFFFF);
    final iris = Paint()..color = const Color(0xFF3E2723);
    // Eyes looking forward (to the right), 3/4 view
    for (final dx in [2.0, 10.0]) {
      final e = c + Offset(dx, -1);
      canvas.drawOval(Rect.fromCenter(center: e, width: 6.5, height: 4.2), eyeWhite);
      canvas.drawCircle(e + const Offset(1.3, 0.2), 1.7, iris);
    }
    final ink = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = pal.outline;
    // Determined brows
    canvas.drawLine(c + const Offset(-1.5, -5.5), c + const Offset(5, -4), ink);
    canvas.drawLine(c + const Offset(8, -4), c + const Offset(13.5, -5.8), ink);
    if (costume != Costume.ninja) {
      // Nose + mouth
      canvas.drawLine(c + const Offset(13, 0), c + const Offset(15, 5),
          ink
            ..strokeWidth = 1.5
            ..color = _darken(pal.skin, 0.35));
      canvas.drawLine(c + const Offset(14.5, 5), c + const Offset(11.5, 5.5), ink);
      canvas.drawLine(c + const Offset(6, 10), c + const Offset(12, 9.5),
          ink
            ..strokeWidth = 1.8
            ..color = _darken(pal.skin, 0.45));
    }
  }
}
