import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/quiz.dart';
import '../theme/app_theme.dart';
import '../widgets/motion_widgets.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final Quiz quiz;

  const FlashcardStudyScreen({super.key, required this.quiz});

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  int _currentIndex = 0;
  bool _isFlipped = false;
  int _learnedCount = 0;

  void _flipCard() {
    setState(() => _isFlipped = !_isFlipped);
    HapticFeedback.selectionClick();
  }

  void _gradeCard(int grade) {
    HapticFeedback.lightImpact();
    setState(() {
      _learnedCount++;
      if (_currentIndex < widget.quiz.questions.length - 1) {
        _currentIndex++;
        _isFlipped = false;
      } else {
        _showCompleteDialog();
      }
    });
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
        title: const Text('Session Complete!'),
        content: Text(
          'You reviewed all $_learnedCount cards in "${widget.quiz.title}". Great work reinforcing your memory offline!',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Exit study screen
            },
            child: const Text('Back to Decks'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = widget.quiz.questions;
    final currentQuestion = questions[_currentIndex];
    final progress = (_currentIndex + 1) / questions.length;

    // Find the correct answer text
    String answerText = '';
    if (currentQuestion.questionType == QuestionType.multipleChoice ||
        currentQuestion.questionType == QuestionType.trueFalse) {
      final correctOpt = currentQuestion.options.where((o) => o.isCorrect).firstOrNull;
      answerText = correctOpt?.optionText ?? 'Answer not specified';
    } else {
      answerText = currentQuestion.acceptableAnswers.isNotEmpty
          ? currentQuestion.acceptableAnswers.join(', ')
          : 'Answer not specified';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Card Counter & Tip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Card ${_currentIndex + 1} of ${questions.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    _isFlipped ? 'Tap to see prompt' : 'Tap to reveal answer',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3D Flip Card Container
              Expanded(
                child: GestureDetector(
                  onTap: _flipCard,
                  child: FlipCard3D(
                    isFlipped: _isFlipped,
                    front: _buildCardFace(
                      context,
                      isFront: true,
                      badge: 'PROMPT / CONCEPT',
                      content: currentQuestion.questionText,
                      subtext: 'Tap anywhere to flip card',
                    ),
                    back: _buildCardFace(
                      context,
                      isFront: false,
                      badge: 'ANSWER & EXPLANATION',
                      content: answerText,
                      subtext: currentQuestion.explanation.isNotEmpty
                          ? currentQuestion.explanation
                          : 'No additional explanation provided.',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // SM-2 Spaced Repetition Grading Controls
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isFlipped ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isFlipped,
                  child: Column(
                    children: [
                      Text(
                        'How well did you remember this?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGradeButton(
                              context,
                              label: 'Again',
                              interval: '<10m',
                              color: AppTheme.forSrsGrade(1),
                              onTap: () => _gradeCard(1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildGradeButton(
                              context,
                              label: 'Hard',
                              interval: '1d',
                              color: AppTheme.forSrsGrade(2),
                              onTap: () => _gradeCard(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildGradeButton(
                              context,
                              label: 'Good',
                              interval: '3d',
                              color: AppTheme.forSrsGrade(3),
                              onTap: () => _gradeCard(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildGradeButton(
                              context,
                              label: 'Easy',
                              interval: '7d',
                              color: AppTheme.forSrsGrade(4),
                              onTap: () => _gradeCard(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace(
    BuildContext context, {
    required bool isFront,
    required String badge,
    required String content,
    required String subtext,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: isFront ? Colors.white : const Color(0xFFF5F3FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isFront
              ? const Color(0xFFE2E8F0)
              : theme.colorScheme.primary.withAlpha(120),
          width: isFront ? 1.2 : 1.5,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  backgroundColor: isFront
                      ? const Color(0xFFF1F5F9)
                      : theme.colorScheme.primaryContainer,
                  label: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: isFront
                          ? const Color(0xFF475569)
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Icon(
                  Icons.sync,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Text(
                content,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                  color: isFront
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const Spacer(),
            if (!isFront)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subtext,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Text(
                  subtext,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeButton(
    BuildContext context, {
    required String label,
    required String interval,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TactilePressCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              interval,
              style: TextStyle(
                fontSize: 11,
                color: color.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
