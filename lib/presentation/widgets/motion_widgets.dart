import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tactile pressable container with scale and haptic feedback.
class TactilePressCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final BorderRadius? borderRadius;

  const TactilePressCard({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.97,
    this.borderRadius,
  });

  @override
  State<TactilePressCard> createState() => _TactilePressCardState();
}

class _TactilePressCardState extends State<TactilePressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) {
          _ctrl.forward();
          HapticFeedback.selectionClick();
        }
      },
      onTapUp: (_) {
        if (widget.onTap != null) {
          _ctrl.reverse();
          widget.onTap!();
        }
      },
      onTapCancel: () {
        if (widget.onTap != null) {
          _ctrl.reverse();
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 3D Flip Card for Flashcards and answer reveals.
class FlipCard3D extends StatelessWidget {
  final Widget front;
  final Widget back;
  final bool isFlipped;
  final Duration duration;

  const FlipCard3D({
    super.key,
    required this.front,
    required this.back,
    required this.isFlipped,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isFlipped ? 180 : 0),
      duration: duration,
      curve: Curves.easeInOutCubicEmphasized,
      builder: (context, val, child) {
        final isFront = val < 90;
        final rotation = (val * math.pi) / 180;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(rotation),
          child: isFront
              ? front
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: back,
                ),
        );
      },
    );
  }
}

/// Staggered Entrance Item for smooth list animations.
class StaggeredEntranceItem extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;
  final double verticalOffset;

  const StaggeredEntranceItem({
    super.key,
    required this.index,
    required this.controller,
    required this.child,
    this.verticalOffset = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.06).clamp(0.0, 0.7);
    final end = (start + 0.35).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, staticChild) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, verticalOffset * (1.0 - animation.value)),
            child: staticChild,
          ),
        );
      },
      child: child,
    );
  }
}

/// Pulsing ambient glow for AI inference processing states.
class AiPulseGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;

  const AiPulseGlow({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF6366F1),
  });

  @override
  State<AiPulseGlow> createState() => _AiPulseGlowState();
}

class _AiPulseGlowState extends State<AiPulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 18.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withAlpha((_ctrl.value * 80).toInt()),
                blurRadius: _glowAnimation.value,
                spreadRadius: _glowAnimation.value * 0.4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
