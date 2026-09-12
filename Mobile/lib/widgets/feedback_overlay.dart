import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Kratka animirana potvrda preko cijelog ekrana (npr. "Nahranjeno! 🐾"),
// umjesto obične snackbar poruke. Sama se ukloni poslije kratke pauze.
class FeedbackOverlay {
  static void show(
    BuildContext context, {
    String? message,
    String? title,
    String? subtitle,
    bool success = true,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FeedbackOverlayWidget(
        title: title ?? message ?? '',
        subtitle: subtitle,
        success: success,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _FeedbackOverlayWidget extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool success;
  final VoidCallback onDone;
  const _FeedbackOverlayWidget({required this.title, this.subtitle, required this.success, required this.onDone});

  @override
  State<_FeedbackOverlayWidget> createState() => _FeedbackOverlayWidgetState();
}

class _FeedbackOverlayWidgetState extends State<_FeedbackOverlayWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final AnimationController _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
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
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.success ? AppColors.primary : Colors.redAccent;
    final colorLight = widget.success ? AppColors.primaryLight : const Color(0xFFFF8A80);
    final icon = widget.success ? Icons.pets_rounded : Icons.close_rounded;

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
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 28, offset: const Offset(0, 14))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 78,
                    height: 78,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (widget.success)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              final t = _pulseController.value;
                              return Opacity(
                                opacity: (1 - t).clamp(0.0, 1.0) * 0.35,
                                child: Transform.scale(
                                  scale: 0.8 + t * 0.6,
                                  child: Container(
                                    width: 66,
                                    height: 66,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                                  ),
                                ),
                              );
                            },
                          ),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [colorLight, color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
                          ),
                          child: Icon(icon, color: Colors.white, size: 32),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
