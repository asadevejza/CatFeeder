import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Kratka animirana potvrda preko cijelog ekrana (npr. "Nahranjeno! 🐾"),
// umjesto obične snackbar poruke. Sama se ukloni poslije kratke pauze.
class FeedbackOverlay {
  static void show(
    BuildContext context, {
    required String message,
    bool success = true,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FeedbackOverlayWidget(
        message: message,
        success: success,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _FeedbackOverlayWidget extends StatefulWidget {
  final String message;
  final bool success;
  final VoidCallback onDone;
  const _FeedbackOverlayWidget({required this.message, required this.success, required this.onDone});

  @override
  State<_FeedbackOverlayWidget> createState() => _FeedbackOverlayWidgetState();
}

class _FeedbackOverlayWidgetState extends State<_FeedbackOverlayWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.12).chain(CurveTween(curve: Curves.easeOutBack)), weight: 65),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.success ? AppColors.primary : Colors.redAccent;
    final colorLight = widget.success ? AppColors.primaryLight : const Color(0xFFFF8A80);
    final icon = widget.success ? Icons.check_rounded : Icons.close_rounded;

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Opacity(
              opacity: _controller.value.clamp(0.0, 1.0),
              child: Transform.scale(scale: _scale.value, child: child),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 26, offset: const Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [colorLight, color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: Icon(icon, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
