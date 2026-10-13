import 'package:flutter/material.dart';

// Siva "pulsirajuća" pravougaona forma koja se prikazuje dok se pravi
// sadržaj još učitava — umjesto praznog ekrana ili jednog spinnera.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  const SkeletonBox({super.key, this.width, required this.height, this.borderRadius = const BorderRadius.all(Radius.circular(12))});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dx = _controller.value * 2 - 1; // -1 .. 1
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(-1 + dx, 0),
              end: Alignment(1 + dx, 0),
              colors: [Colors.grey.shade300, Colors.grey.shade100, Colors.grey.shade300],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(rect),
            child: Container(width: widget.width, height: widget.height, color: Colors.grey.shade300),
          ),
        );
      },
    );
  }
}
