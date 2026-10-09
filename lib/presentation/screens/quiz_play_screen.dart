import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/attempt.dart';
import '../../models/quiz.dart';
import '../../providers/quiz_providers.dart';
import 'results_screen.dart';

class QuizPlayScreen extends ConsumerStatefulWidget {
  final Quiz quiz;

  const QuizPlayScreen({super.key, required this.quiz});

  @override
  ConsumerState<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends ConsumerState<QuizPlayScreen> {
  int _currentIndex = 0;
  final Map<String, String> _selectedOptionIds = {};
  final Map<String, TextEditingController> _textControllers = {};
  final DateTime _startedAt = DateTime.now();

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String questionId) {
    return _textControllers.putIfAbsent(questionId, () => TextEditingController());
  }

  void _submitQuiz() async {
    final quiz = widget.quiz;
    final answers = <UserAnswer>[];
    int score = 0;

    for (final q in quiz.questions) {
      bool isCorrect = false;
      String? selectedOptId;
      String? textAnswer;

      if (q.questionType == QuestionType.multipleChoice || q.questionType == QuestionType.trueFalse) {
        selectedOptId = _selectedOptionIds[q.id];
        final chosenOpt = q.options.where((o) => o.id == selectedOptId).firstOrNull;
        if (chosenOpt != null && chosenOpt.isCorrect) {
          isCorrect = true;
        }
      } else {
        textAnswer = _textControllers[q.id]?.text.trim() ?? '';
        final lower = textAnswer.toLowerCase();
        if (q.acceptableAnswers.any((ans) => ans.toLowerCase().trim() == lower)) {
          isCorrect = true;
        }
      }

      final earned = isCorrect ? q.points : 0;
      score += earned;

      answers.add(UserAnswer(
        attemptId: '',
        questionId: q.id,
        selectedOptionId: selectedOptId,
        textAnswer: textAnswer,
        isCorrect: isCorrect,
        earnedPoints: earned,
      ));
    }

    final totalPoints = quiz.totalPoints > 0 ? quiz.totalPoints : 1;
    final percentage = (score / totalPoints) * 100.0;
    final durationSeconds = DateTime.now().difference(_startedAt).inSeconds;

    final attempt = QuizAttempt(
      quizId: quiz.id,
      startedAt: _startedAt,
      completedAt: DateTime.now(),
      score: score,
      totalPossibleScore: totalPoints,
      percentage: percentage,
      timeSpentSeconds: durationSeconds,
      answers: answers,
    );

    final attemptRepo = ref.read(attemptRepositoryProvider);
    await attemptRepo.saveAttempt(attempt);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(quiz: quiz, attempt: attempt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.quiz.questions;
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quiz.title)),
        body: const Center(child: Text('This quiz has no questions.')),
      );
    }

    final q = questions[_currentIndex];
    final isLast = _currentIndex == questions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.quiz.title} (${_currentIndex + 1}/${questions.length})'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / questions.length,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 24),
            Text(
              q.questionText,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _buildAnswerInput(q),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentIndex > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _currentIndex--),
                    child: const Text('Previous'),
                  )
                else
                  const SizedBox.shrink(),
                FilledButton(
                  onPressed: () {
                    if (isLast) {
                      _submitQuiz();
                    } else {
                      setState(() => _currentIndex++);
                    }
                  },
                  child: Text(isLast ? 'Submit Quiz' : 'Next Question'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerInput(QuizQuestion q) {
    if (q.questionType == QuestionType.multipleChoice || q.questionType == QuestionType.trueFalse) {
      return ListView.builder(
        itemCount: q.options.length,
        itemBuilder: (ctx, i) {
          final opt = q.options[i];
          final isSelected = _selectedOptionIds[q.id] == opt.id;

          return Card(
            elevation: isSelected ? 4 : 1,
            color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _selectedOptionIds[q.id] = opt.id;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        opt.optionText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else {
      final controller = _getController(q.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Your Answer',
              hintText: 'Type your answer here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Self-graded or auto-validated against acceptable terms.'),
        ],
      );
    }
  }
}
