import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'main_navigation_shell.dart';
import 'privacy_promise_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();
    _startNavigationSequence();
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _startNavigationSequence() {
    // Show splash screen every time on launch (2.0s hold before slow, buttery smooth 1100ms fade out)
    _navTimer = Timer(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;

      bool hasAcceptedTerms = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        hasAcceptedTerms = prefs.getBool('has_accepted_offline_privacy_policy_v1') ?? false;
      } catch (_) {}

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1100),
          pageBuilder: (_, _, _) =>
              hasAcceptedTerms ? const MainNavigationShell() : const PrivacyPromiseScreen(),
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            );
            return FadeTransition(opacity: curved, child: child);
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Center(
                  child: Hero(
                    tag: 'maqui_app_logo',
                    child: Image.asset(
                      isDark ? 'assets/MaQui-dark-mode.png' : 'assets/MaQui-light-mode.png',
                      height: 195,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school, size: 80, color: theme.colorScheme.primary),
                          const SizedBox(height: 16),
                          Text('MaQui', style: AppTheme.appNameStyle(fontSize: 32)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
