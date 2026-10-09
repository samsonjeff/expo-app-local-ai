import 'package:flutter/material.dart';
import '../../models/attempt.dart';
import '../../models/quiz.dart';

class ResultsScreen extends StatelessWidget {
  final Quiz quiz;
  final QuizAttempt attempt;

  const ResultsScreen({
    super.key,
    required this.quiz,
    required this.attempt,
  });

  @override
  Widget build(BuildContext context) {
    final passed = attempt.percentage >= 70.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Results'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: passed ? Colors.green.withAlpha(30) : Colors.amber.withAlpha(30),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      passed ? Icons.emoji_events : Icons.refresh,
                      size: 64,
                      color: passed ? Colors.green : Colors.amber,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      passed ? 'Great Job!' : 'Keep Practicing!',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${attempt.score} / ${attempt.totalPossibleScore} Points (${attempt.percentage.toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: quiz.questions.length,
              itemBuilder: (ctx, i) {
                final q = quiz.questions[i];
                final answer = attempt.answers.firstWhere(
                  (a) => a.questionId == q.id,
                  orElse: () => UserAnswer(
                    attemptId: attempt.id,
                    questionId: q.id,
                    isCorrect: false,
                    earnedPoints: 0,
                  ),
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              answer.isCorrect ? Icons.check_circle : Icons.cancel,
                              color: answer.isCorrect ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Q${i + 1}: ${q.questionText}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (q.explanation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Explanation: ${q.explanation}',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
