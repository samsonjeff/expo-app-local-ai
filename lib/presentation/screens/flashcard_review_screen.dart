import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/quiz.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/app_notification.dart';

class FlashcardReviewScreen extends StatefulWidget {
  final Quiz quiz;

  const FlashcardReviewScreen({super.key, required this.quiz});

  @override
  State<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends State<FlashcardReviewScreen> with SingleTickerProviderStateMixin {
  late List<QuizQuestion> _questions;
  int _currentIndex = 0;
  bool _isFlipped = false;
  final Set<String> _knownQuestionIds = {};
  final Set<String> _needReviewQuestionIds = {};

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.quiz.questions);

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  void _nextCard() {
    if (_currentIndex < _questions.length - 1) {
      if (_isFlipped) {
        _flipController.reverse();
        _isFlipped = false;
      }
      setState(() => _currentIndex++);
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      if (_isFlipped) {
        _flipController.reverse();
        _isFlipped = false;
      }
      setState(() => _currentIndex--);
    }
  }

  void _markKnown(String questionId) {
    setState(() {
      _knownQuestionIds.add(questionId);
      _needReviewQuestionIds.remove(questionId);
    });
    _nextCard();
  }

  void _markNeedReview(String questionId) {
    setState(() {
      _needReviewQuestionIds.add(questionId);
      _knownQuestionIds.remove(questionId);
    });
    _nextCard();
  }

  void _shuffle() {
    setState(() {
      if (_isFlipped) {
        _flipController.reverse();
        _isFlipped = false;
      }
      _questions.shuffle(Random());
      _currentIndex = 0;
    });
    AppNotification.showInfo(context, 'Cards shuffled!', duration: const Duration(seconds: 1), bottomMargin: 24);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quiz.title)),
        body: const Center(child: Text('No questions available for flashcard review.')),
      );
    }

    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    final masteredCount = _knownQuestionIds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcard Reviewer', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Shuffle Cards',
            onPressed: _shuffle,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          // Top Progress & Mastery Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Card ${_currentIndex + 1} of ${_questions.length}',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Mastered: $masteredCount / ${_questions.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 6,
                ),
              ],
            ),
          ),

          // Central Flipping Flashcard
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GestureDetector(
                onTap: _flipCard,
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final isUnder = _flipAnimation.value > 0.5;
                    final angle = _flipAnimation.value * pi;

                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      alignment: Alignment.center,
                      child: isUnder
                          ? Transform(
                              transform: Matrix4.identity()..rotateY(pi),
                              alignment: Alignment.center,
                              child: _buildBackCard(q),
                            )
                          : _buildFrontCard(q),
                    );
                  },
                ),
              ),
            ),
          ),

          // Flip Hint
          Text(
            _isFlipped ? 'Tap card to view question prompt' : 'Tap card to flip & reveal answer key',
            style: TextStyle(
              color: theme.colorScheme.outline,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Action Controls: Need Review, Known, Nav
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Mark Need Review
                    Expanded(
                      child: TactilePressCard(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _markNeedReview(q.id),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A1B10) : const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.orange.shade800 : const Color(0xFFFDBA74),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                color: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Review Again',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Mark Mastered
                    Expanded(
                      child: TactilePressCard(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _markKnown(q.id),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x3316A34A),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Got It!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Navigation Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _currentIndex > 0 ? _prevCard : null,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Previous', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                    Text(
                      '${_currentIndex + 1} of ${_questions.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _currentIndex < _questions.length - 1 ? _nextCard : null,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      iconAlignment: IconAlignment.end,
                      label: const Text('Next', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  }

  Widget _buildFrontCard(QuizQuestion q) {
    final theme = Theme.of(context);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Container(
        padding: const EdgeInsets.all(28),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withAlpha(50),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(q.questionType.label),
                  avatar: const Icon(Icons.psychology, size: 16),
                ),
                const Spacer(),
                Icon(Icons.touch_app_outlined, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 4),
                Text('Tap to Flip', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      q.questionText,
                      textAlign: TextAlign.center,
                      style: (q.questionText.length > 120
                              ? theme.textTheme.titleMedium
                              : (q.questionText.length > 60
                                  ? theme.textTheme.titleLarge
                                  : theme.textTheme.headlineSmall))
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (q.questionType == QuestionType.multipleChoice) ...[
              Center(
                child: Text(
                  '${q.options.length} Choices Available',
                  style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBackCard(QuizQuestion q) {
    final theme = Theme.of(context);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.green.withAlpha(120)),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text('Answer Key', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                const Spacer(),
                Text('${q.points} Points', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            // Correct Answer Display
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBackAnswerContent(q),
                    const SizedBox(height: 16),
                    if (q.explanation.isNotEmpty && q.questionType != QuestionType.essay) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'AI Explanation:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        q.explanation,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackAnswerContent(QuizQuestion q) {
    switch (q.questionType) {
      case QuestionType.multipleChoice:
        final correctOpt = q.options.where((o) => o.isCorrect).firstOrNull;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withAlpha(80)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  correctOpt?.optionText ?? 'Option text',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

      case QuestionType.trueFalse:
        final correctText = q.options.where((o) => o.isCorrect).firstOrNull?.optionText ?? 'True';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.check, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Correct Answer: $correctText',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
            ],
          ),
        );

      case QuestionType.identification:
      case QuestionType.fillInBlank:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Correct Answer:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                q.acceptableAnswers.join(' / '),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
        );

      case QuestionType.enumeration:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Acceptable Items:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...q.acceptableAnswers.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                )),
          ],
        );

      case QuestionType.essay:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Rubric Key & Model Answer:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                q.explanation,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        );
    }
  }
}
