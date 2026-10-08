import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final Color? color;
  const AppLogo({super.key, this.size = 56, this.showWordmark = false, this.color});

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(width: size, height: size, child: CustomPaint(painter: _CatLogoPainter(color ?? AppColors.primary)));
    if (!showWordmark) return mark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      const SizedBox(width: 12),
      Text('CatFeeder', style: TextStyle(fontSize: size * .38, fontWeight: FontWeight.w900, letterSpacing: -.7, color: color ?? AppColors.primary)),
    ]);
  }
}

class _CatLogoPainter extends CustomPainter {
  final Color color;
  _CatLogoPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final stroke = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 7*s..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    final accent = Paint()..color = AppColors.lavenderStrong;
    final cat = Path()
      ..moveTo(20*s,42*s)..lineTo(22*s,18*s)..lineTo(38*s,29*s)
      ..cubicTo(45*s,26*s,55*s,26*s,62*s,29*s)..lineTo(78*s,18*s)..lineTo(80*s,42*s)
      ..cubicTo(82*s,65*s,69*s,81*s,50*s,81*s)..cubicTo(31*s,81*s,18*s,65*s,20*s,42*s);
    canvas.drawPath(cat, stroke);
    canvas.drawCircle(Offset(38*s,48*s),3*s,fill); canvas.drawCircle(Offset(62*s,48*s),3*s,fill);
    final heart = Path()..moveTo(69*s,68*s)..cubicTo(61*s,60*s,50*s,69*s,69*s,84*s)..cubicTo(88*s,69*s,77*s,60*s,69*s,68*s)..close();
    canvas.drawPath(heart, accent);
  }
  @override bool shouldRepaint(covariant _CatLogoPainter oldDelegate) => oldDelegate.color != color;
}
