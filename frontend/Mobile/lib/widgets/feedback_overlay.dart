import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FeedbackOverlay {
  static void show(
    BuildContext context, {
    String? message,
    String? title,
    String? subtitle,
    bool success = true,
    Duration duration = const Duration(milliseconds: 1700),
  }) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _FeedbackOverlayWidget(
        title: title ?? message ?? '',
        subtitle: subtitle,
        success: success,
        duration: duration,
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
  final Duration duration;
  final VoidCallback onDone;

  const _FeedbackOverlayWidget({
    required this.title,
    this.subtitle,
    required this.success,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_FeedbackOverlayWidget> createState() =>
      _FeedbackOverlayWidgetState();
}

class _FeedbackOverlayWidgetState extends State<_FeedbackOverlayWidget>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _pulseController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Glavna animacija za ulazak i izlazak
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Animacija pulziranja ikone
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Elastični skok pri ulasku
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeInBack,
      ),
    );

    // Glatki fade in / fade out
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _entryController.forward();
    _startTimer();
  }

  Future<void> _startTimer() async {
    await Future.delayed(widget.duration);
    if (!mounted) return;
    await _entryController.reverse();
    if (!mounted) return;
    widget.onDone();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.success ? AppColors.primary : Colors.redAccent;
    final lightColor = widget.success
        ? AppColors.primaryLight
        : const Color(0xFFFF8A80);
    final mainIcon =
        widget.success ? Icons.pets_rounded : Icons.close_rounded;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _entryController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Zamućena i blago zatamnjena pozadina
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 5.0 * _fadeAnimation.value,
                      sigmaY: 5.0 * _fadeAnimation.value,
                    ),
                    child: Container(
                      color: Colors.black.withOpacity(0.18 * _fadeAnimation.value),
                    ),
                  ),

                  // Glavni pop-up kontejner
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 30,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.9),
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 32,
                            spreadRadius: 2,
                            offset: const Offset(0, 16),
                          ),
                          BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 24,
                            spreadRadius: -4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sekcija za ikonu sa dvostrukim pulzirajućim talasima
                          SizedBox(
                            width: 90,
                            height: 90,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (widget.success) ...[
                                  // Prvi pulzirajući prsten
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, _) {
                                      final progress = _pulseController.value;
                                      return Opacity(
                                        opacity: (1 - progress).clamp(0.0, 1.0) * 0.45,
                                        child: Transform.scale(
                                          scale: 0.75 + (progress * 0.55),
                                          child: Container(
                                            width: 84,
                                            height: 84,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  // Drugi pulzirajući prsten (sa kašnjenjem)
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, _) {
                                      final progress = (_pulseController.value + 0.5) % 1.0;
                                      return Opacity(
                                        opacity: (1 - progress).clamp(0.0, 1.0) * 0.25,
                                        child: Transform.scale(
                                          scale: 0.75 + (progress * 0.45),
                                          child: Container(
                                            width: 84,
                                            height: 84,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],

                                // Glavni krug sa gradijentom i ikonicom
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [lightColor, primaryColor],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.4),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    mainIcon,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Naslov
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                              height: 1.2,
                              letterSpacing: -0.3,
                              color: AppColors.textDark,
                            ),
                          ),

                          // Podnaslov u vidu pill značke
                          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.success
                                        ? Icons.check_circle_rounded
                                        : Icons.info_rounded,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      widget.subtitle!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}