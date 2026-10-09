import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/attempt.dart';
import '../../models/quiz.dart';
import '../widgets/motion_widgets.dart';
import 'flashcard_study_screen.dart';
import 'quiz_play_screen.dart';

class ResultsScreen extends StatefulWidget {
  final Quiz quiz;
  final QuizAttempt attempt;

  const ResultsScreen({
    super.key,
    required this.quiz,
    required this.attempt,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _filterMistakesOnly = false;

  void _shareSummary() {
    HapticFeedback.lightImpact();
    final p = widget.attempt.percentage.toStringAsFixed(1);
    final text = 'I scored $p% on "${widget.quiz.title}" using Local AI Quiz App completely offline!';
    SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attempt = widget.attempt;
    final quiz = widget.quiz;
    final passed = attempt.percentage >= 70.0;
    final minutes = attempt.timeSpentSeconds ~/ 60;
    final seconds = attempt.timeSpentSeconds % 60;
    final timeStr = '${minutes}m ${seconds}s';

    final incorrectCount = attempt.answers.where((a) => !a.isCorrect).length;

    final displayedQuestions = quiz.questions.where((q) {
      if (!_filterMistakesOnly) return true;
      final ans = attempt.answers.firstWhere(
        (a) => a.questionId == q.id,
        orElse: () => UserAnswer(
          attemptId: attempt.id,
          questionId: q.id,
          isCorrect: false,
          earnedPoints: 0,
        ),
      );
      return !ans.isCorrect;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Score',
            onPressed: _shareSummary,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. Hero Score Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: passed
                    ? [
                        Colors.green.withAlpha(40),
                        Colors.green.withAlpha(15),
                      ]
                    : [
                        Colors.amber.withAlpha(40),
                        Colors.amber.withAlpha(15),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: passed ? Colors.green.withAlpha(80) : Colors.amber.withAlpha(80),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  passed ? Icons.emoji_events : Icons.psychology,
                  size: 60,
                  color: passed ? Colors.green : Colors.amber,
                ),
                const SizedBox(height: 12),
                Text(
                  passed ? 'Mastery Achieved!' : 'Keep Practicing!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${attempt.percentage.toStringAsFixed(1)}% Score',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: passed ? Colors.green : Colors.amber.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),

                // Metrics Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCol('Score', '${attempt.score}/${attempt.totalPossibleScore}'),
                    Container(height: 28, width: 1, color: theme.colorScheme.outlineVariant),
                    _buildMetricCol('Time', timeStr),
                    Container(height: 28, width: 1, color: theme.colorScheme.outlineVariant),
                    _buildMetricCol('Mistakes', '$incorrectCount'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Quick Actions
          Row(
            children: [
              Expanded(
                child: TactilePressCard(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => QuizPlayScreen(quiz: quiz)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, size: 18, color: theme.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 6),
                        Text(
                          'Retake',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TactilePressCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FlashcardStudyScreen(quiz: quiz)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.style, size: 18, color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(width: 6),
                        Text(
                          'Flashcards',
                          style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Question Review Header & Filter Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUESTION REVIEW',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: !_filterMistakesOnly,
                    onSelected: (val) {
                      if (val) setState(() => _filterMistakesOnly = false);
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text('Mistakes ($incorrectCount)'),
                    selected: _filterMistakesOnly,
                    onSelected: (val) {
                      if (val) setState(() => _filterMistakesOnly = true);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Questions List
          ...displayedQuestions.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            final answer = attempt.answers.firstWhere(
              (a) => a.questionId == q.id,
              orElse: () => UserAnswer(
                attemptId: attempt.id,
                questionId: q.id,
                isCorrect: false,
                earnedPoints: 0,
              ),
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            answer.isCorrect ? Icons.check_circle : Icons.cancel,
                            color: answer.isCorrect ? Colors.green : Colors.red,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Q${i + 1}: ${q.questionText}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (answer.textAnswer != null && answer.textAnswer!.isNotEmpty)
                                  Text(
                                    'Your Answer: ${answer.textAnswer}',
                                    style: TextStyle(
                                      color: answer.isCorrect ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (q.explanation.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  q.explanation,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.4,
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
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}
