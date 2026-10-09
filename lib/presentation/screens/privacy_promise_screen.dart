import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/motion_widgets.dart';
import 'main_navigation_shell.dart';

class PrivacyPromiseScreen extends StatefulWidget {
  final bool isReviewMode;
  const PrivacyPromiseScreen({super.key, this.isReviewMode = false});

  @override
  State<PrivacyPromiseScreen> createState() => _PrivacyPromiseScreenState();
}

class _PrivacyPromiseScreenState extends State<PrivacyPromiseScreen> {
  bool _isSaving = false;
  bool _hasAgreed = false;

  Future<void> _acceptAndContinue() async {
    if (widget.isReviewMode) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_accepted_offline_privacy_policy_v1', true);
      await prefs.setBool('has_accepted_privacy_promise', true);
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => const MainNavigationShell(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showFullTermsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'MaQui Terms of Use & Offline Policy',
                style: AppTheme.appNameStyle(fontSize: 18),
              ),
              const SizedBox(height: 14),
              const Text(
                '1. Offline Processing & Zero Telemetry\n'
                'MaQui operates 100% locally on your device. No document contents, prompt texts, generated quizzes, or usage metrics are transmitted across any network or cloud infrastructure.\n\n'
                '2. AI Output & Educational Intent\n'
                'Quizzes and flashcards are generated via on-device machine learning models for personal study review. While optimized for factual accuracy, AI-generated questions may occasionally contain inaccuracies. Users should cross-reference study materials with primary academic curriculum.\n\n'
                '3. Local Device Resource Utilization\n'
                'Inference execution utilizes local system RAM and CPU resources. Performance varies according to hardware specifications (e.g., 4GB vs. 8GB device tiers).\n\n'
                '4. Content Ownership\n'
                'You retain total ownership of all uploaded study materials and created quizzes stored in your local application directory.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.isReviewMode
          ? AppBar(
              title: const Text('Privacy & Terms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Top Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),

                    // Official MaQui Logo
                    Hero(
                      tag: 'maqui_app_logo',
                      child: Image.asset(
                        isDark ? 'assets/MaQui-dark-mode.png' : 'assets/MaQui-light-mode.png',
                        height: 76,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(Icons.school, size: 54, color: Color(0xFF4F46E5)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Combined Notice Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF4F46E5).withAlpha(40)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: Color(0xFF4F46E5)),
                          SizedBox(width: 6),
                          Text(
                            'Combined Notice',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Exact Requested Header Title
                    Text(
                      'Welcome & Offline Privacy Promise',
                      textAlign: TextAlign.center,
                      style: AppTheme.appNameStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '100% On-Device AI • No Cloud Telemetry • No Accounts Required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4 Value & Trust Cards with Staggered Entrance
                    _buildPromiseCard(
                      index: 0,
                      icon: Icons.verified_user_outlined,
                      iconColor: const Color(0xFF16A34A),
                      containerColor: const Color(0xFFF0FDF4),
                      title: '100% On-Device & Zero Cloud Data',
                      description:
                          'Your documents, notes, quizzes, and score history never leave this device. Zero cloud data leakage, no trackers, and no external servers.',
                    ),
                    const SizedBox(height: 12),

                    _buildPromiseCard(
                      index: 1,
                      icon: Icons.memory_outlined,
                      iconColor: const Color(0xFF4F46E5),
                      containerColor: const Color(0xFFEEF2FF),
                      title: 'Local Hardware Processing',
                      description:
                          'All AI quiz generation runs entirely on your device processor and RAM using on-device models. Works anywhere without an internet connection.',
                    ),
                    const SizedBox(height: 12),

                    _buildPromiseCard(
                      index: 2,
                      icon: Icons.auto_stories_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      containerColor: const Color(0xFFF5F3FF),
                      title: 'Educational Study Aid',
                      description:
                          'MaQui is built to reinforce memory through active recall. While generated with precision, please verify facts with textbooks for official exams.',
                    ),
                    const SizedBox(height: 12),

                    _buildPromiseCard(
                      index: 3,
                      icon: Icons.no_accounts_outlined,
                      iconColor: const Color(0xFFD97706),
                      containerColor: const Color(0xFFFFFBEB),
                      title: 'No Accounts & Complete Ownership',
                      description:
                          'No email, passwords, or account creation required. All flashcards and reviewer data remain securely in your local app sandbox.',
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Action Area
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isReviewMode) ...[
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        value: _hasAgreed,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _hasAgreed = val ?? false);
                        },
                        title: const Text(
                          'I understand and agree to the 100% Offline Privacy Policy and acknowledge my data is kept strictly on-device.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                            height: 1.35,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        activeColor: const Color(0xFF4F46E5),
                        checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TactilePressCard(
                    borderRadius: BorderRadius.circular(16),
                    onTap: (_isSaving || (!widget.isReviewMode && !_hasAgreed))
                        ? null
                        : _acceptAndContinue,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: (_isSaving || (!widget.isReviewMode && !_hasAgreed))
                            ? null
                            : _acceptAndContinue,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_forward_rounded, size: 20),
                        label: Text(
                          _isSaving
                              ? 'Initializing...'
                              : (widget.isReviewMode ? 'Close Notice' : 'Agree & Get Started'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'By continuing, you agree to our ',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      GestureDetector(
                        onTap: _showFullTermsModal,
                        child: const Text(
                          'Terms & Disclaimers',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromiseCard({
    required int index,
    required IconData icon,
    required Color iconColor,
    required Color containerColor,
    required String title,
    required String description,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: (300 + (index * 70)).clamp(300, 700)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1.0 - value)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
