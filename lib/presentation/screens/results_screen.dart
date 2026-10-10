import 'package:flutter/material.dart';
import '../../models/attempt.dart';
import '../../models/quiz.dart';
import '../theme/app_theme.dart';
import '../widgets/motion_widgets.dart';
import 'flashcard_review_screen.dart';
import 'quiz_play_screen.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final passingThreshold = quiz.passingScore.toDouble();
    final passed = attempt.percentage >= passingThreshold;

    return Scaffold(
      appBar: AppBar(
        title: Text('${quiz.assessmentMode.label} Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.style_outlined),
            tooltip: 'Review with Flashcards',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FlashcardReviewScreen(quiz: quiz)),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Score Summary Card with Spring Pop
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.85, end: 1.0),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark
                        ? (passed ? const Color(0xFF22C55E).withAlpha(100) : const Color(0xFFF59E0B).withAlpha(100))
                        : (passed ? Colors.green.withAlpha(80) : Colors.amber.withAlpha(80)),
                    width: 1.5,
                  ),
                ),
                color: isDark
                    ? (passed ? const Color(0xFF064E3B).withAlpha(140) : const Color(0xFF78350F).withAlpha(140))
                    : (passed ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.elasticOut,
                        builder: (context, iconScale, child) => Transform.scale(
                          scale: iconScale,
                          child: child,
                        ),
                        child: Icon(
                          passed ? Icons.emoji_events : Icons.refresh,
                          size: 64,
                          color: passed
                              ? (isDark ? AppTheme.successDark : AppTheme.success)
                              : (isDark ? AppTheme.warningDark : AppTheme.warning),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        passed ? 'Assessment Passed!' : 'Need More Practice',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Passing Score Requirement: ${quiz.passingScore}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: attempt.percentage),
                        duration: const Duration(milliseconds: 850),
                        curve: Curves.easeOutCubic,
                        builder: (context, animPct, _) {
                          final animScore = (animPct / 100 * attempt.totalPossibleScore).round();
                          return Text(
                            '$animScore / ${attempt.totalPossibleScore} Points (${animPct.toStringAsFixed(1)}%)',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: passed
                                  ? (isDark ? AppTheme.successDark : AppTheme.success)
                                  : (isDark ? AppTheme.warningDark : AppTheme.warning),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Time Spent: ${attempt.timeSpentSeconds ~/ 60}m ${attempt.timeSpentSeconds % 60}s',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick Action Buttons with Tactile Feedback
            Row(
              children: [
                Expanded(
                  child: TactilePressCard(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => FlashcardReviewScreen(quiz: quiz)),
                      );
                    },
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.style_outlined),
                      label: const Text('Flashcards'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FlashcardReviewScreen(quiz: quiz)),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TactilePressCard(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => QuizPlayScreen(quiz: quiz)),
                      );
                    },
                    child: FilledButton.icon(
                      icon: const Icon(Icons.replay),
                      label: const Text('Retake'),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => QuizPlayScreen(quiz: quiz)),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Detailed Item Review Header
            Text(
              'Detailed Review & AI Explanations',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Questions List with Explanations
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

                return _buildResultQuestionCard(context, q, answer, i);
              },
            ),
            const SizedBox(height: 20),

            TactilePressCard(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.pop(context),
              child: FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.home),
                label: const Text('Return to Home'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildResultQuestionCard(BuildContext context, QuizQuestion q, UserAnswer answer, int index) {
    final theme = Theme.of(context);
    final isCorrect = answer.isCorrect;

    return TweenAnimationBuilder<double>(
      key: ValueKey(q.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: (280 + (index * 50)).clamp(280, 700)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1.0 - value)),
          child: child,
        ),
      ),
      child: Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isCorrect ? Colors.green.withAlpha(80) : Colors.red.withAlpha(80),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Header
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        Text(
                          'Question ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(q.questionType.label, style: const TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${answer.earnedPoints} / ${q.points} pt',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCorrect ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Question Text
              Text(
                q.questionText,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Student Answer Display
              _buildAnswerComparison(q, answer),

              // AI Explanation / Rubric Key
              if (q.explanation.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology, size: 16, color: Colors.indigo),
                          const SizedBox(width: 6),
                          Text(
                            q.questionType == QuestionType.essay
                                ? 'AI Rubric Key & Model Criteria'
                                : 'Local AI Concept Explanation',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        q.explanation,
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.35),
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
  }

  Widget _buildAnswerComparison(QuizQuestion q, UserAnswer answer) {
    if (q.questionType == QuestionType.multipleChoice || q.questionType == QuestionType.trueFalse) {
      final selectedOpt = q.options.where((o) => o.id == answer.selectedOptionId).firstOrNull;
      final correctOpt = q.options.where((o) => o.isCorrect).firstOrNull;

      final userAnsText = selectedOpt?.optionText ??
          (answer.textAnswer?.isNotEmpty == true ? answer.textAnswer! : 'No answer selected');
      final correctAnsText = correctOpt?.optionText ??
          (q.acceptableAnswers.isNotEmpty ? q.acceptableAnswers.first : (q.questionType == QuestionType.trueFalse ? (answer.isCorrect ? userAnsText : (userAnsText == 'True' ? 'False' : 'True')) : ''));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Answer: $userAnsText',
            style: TextStyle(
              color: answer.isCorrect ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!answer.isCorrect && correctAnsText.isNotEmpty)
            Text(
              'Correct Answer: $correctAnsText',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
        ],
      );
    } else if (q.questionType == QuestionType.essay) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Written Essay Response:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            answer.textAnswer?.isNotEmpty == true ? answer.textAnswer! : '[No essay response provided]',
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      );
    } else {
      // Identification or Enumeration
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Answer: ${answer.textAnswer?.isNotEmpty == true ? answer.textAnswer! : "None"}',
            style: TextStyle(
              color: answer.isCorrect ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!answer.isCorrect && q.acceptableAnswers.isNotEmpty)
            Text(
              'Acceptable Answer(s): ${q.acceptableAnswers.join(" | ")}',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
        ],
      );
    }
  }
}
