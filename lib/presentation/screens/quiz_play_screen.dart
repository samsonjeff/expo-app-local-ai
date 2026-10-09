import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/attempt.dart';
import '../../models/quiz.dart';
import '../../providers/quiz_providers.dart';
import 'results_screen.dart';

class QuizPlayScreen extends ConsumerStatefulWidget {
  final Quiz quiz;
  final bool isPracticeMode;

  const QuizPlayScreen({
    super.key,
    required this.quiz,
    this.isPracticeMode = false,
  });

  @override
  ConsumerState<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends ConsumerState<QuizPlayScreen> {
  int _currentIndex = 0;
  final Map<String, String> _selectedOptionIds = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, List<TextEditingController>> _enumerationControllers = {};
  final Map<String, bool> _revealedAnswers = {}; // for real-time feedback in practice mode
  final DateTime _startedAt = DateTime.now();

  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    for (final list in _enumerationControllers.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    super.dispose();
  }

  TextEditingController _getController(String questionId) {
    return _textControllers.putIfAbsent(questionId, () => TextEditingController());
  }

  List<TextEditingController> _getEnumerationControllers(String questionId, int count) {
    return _enumerationControllers.putIfAbsent(
      questionId,
      () => List.generate(count > 0 ? count : 3, (_) => TextEditingController()),
    );
  }

  bool _isAnswered(QuizQuestion q) {
    if (q.questionType == QuestionType.multipleChoice || q.questionType == QuestionType.trueFalse) {
      return _selectedOptionIds[q.id] != null;
    } else if (q.questionType == QuestionType.enumeration) {
      final list = _enumerationControllers[q.id];
      return list != null && list.any((c) => c.text.trim().isNotEmpty);
    } else {
      return _textControllers[q.id]?.text.trim().isNotEmpty ?? false;
    }
  }

  void _submitQuiz() async {
    final quiz = widget.quiz;
    final answers = <UserAnswer>[];
    int score = 0;

    for (final q in quiz.questions) {
      bool isCorrect = false;
      String? selectedOptId;
      String? textAnswer;
      int earned = 0;

      if (q.questionType == QuestionType.multipleChoice || q.questionType == QuestionType.trueFalse) {
        selectedOptId = _selectedOptionIds[q.id];
        final chosenOpt = q.options.where((o) => o.id == selectedOptId).firstOrNull;
        if (chosenOpt != null && chosenOpt.isCorrect) {
          isCorrect = true;
          earned = q.points;
        }
      } else if (q.questionType == QuestionType.enumeration) {
        final list = _enumerationControllers[q.id] ?? [];
        final entered = list.map((c) => c.text.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
        final targets = q.acceptableAnswers.map((s) => s.toLowerCase()).toList();

        int matches = 0;
        for (final item in entered) {
          if (targets.any((t) => t.contains(item) || item.contains(t))) {
            matches++;
          }
        }
        if (matches > 0 && targets.isNotEmpty) {
          earned = ((matches / targets.length) * q.points).round();
          if (earned > q.points) earned = q.points;
          isCorrect = earned >= (q.points * 0.6);
        }
        textAnswer = entered.join(', ');
      } else if (q.questionType == QuestionType.essay) {
        textAnswer = _textControllers[q.id]?.text.trim() ?? '';
        // If student submitted a substantial response (> 15 words), award baseline score and invite self-rubric check
        final words = textAnswer.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        if (words >= 15) {
          earned = q.points; // Full credit provisionally, rubric shown on review
          isCorrect = true;
        } else if (words >= 5) {
          earned = (q.points * 0.5).round();
          isCorrect = false;
        }
      } else {
        // Identification / Fill in Blank
        textAnswer = _textControllers[q.id]?.text.trim() ?? '';
        final lower = textAnswer.toLowerCase();
        if (q.acceptableAnswers.any((ans) => ans.toLowerCase().trim() == lower)) {
          isCorrect = true;
          earned = q.points;
        }
      }

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

    final attempt = QuizAttempt(
      quizId: quiz.id,
      startedAt: _startedAt,
      completedAt: DateTime.now(),
      score: score,
      totalPossibleScore: totalPoints,
      percentage: percentage,
      timeSpentSeconds: _elapsedSeconds,
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

  void _showQuestionGrid() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question Navigator',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(widget.quiz.questions.length, (idx) {
                final q = widget.quiz.questions[idx];
                final isAnswered = _isAnswered(q);
                final isCurrent = idx == _currentIndex;

                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _currentIndex = idx);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Theme.of(ctx).colorScheme.primary
                          : (isAnswered ? Colors.green.withAlpha(40) : Theme.of(ctx).colorScheme.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? Theme.of(ctx).colorScheme.primary
                            : (isAnswered ? Colors.green : Colors.grey.shade400),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCurrent
                              ? Colors.white
                              : (isAnswered ? Colors.green.shade800 : null),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(width: 12, height: 12, color: Colors.green),
                const SizedBox(width: 6),
                const Text('Answered', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Container(width: 12, height: 12, color: Colors.grey),
                const SizedBox(width: 6),
                const Text('Unanswered', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
    final isRevealed = _revealedAnswers[q.id] == true;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.quiz.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              '${widget.quiz.assessmentMode.label} • Question ${_currentIndex + 1} of ${questions.length}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Chip(
            avatar: const Icon(Icons.timer_outlined, size: 16),
            label: Text(_formatTimer(_elapsedSeconds), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view),
            tooltip: 'Question Navigator',
            onPressed: _showQuestionGrid,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentIndex + 1) / questions.length,
              borderRadius: BorderRadius.circular(8),
              minHeight: 6,
            ),
            const SizedBox(height: 16),

            // Question Type Badge & Points
            Row(
              children: [
                Chip(
                  label: Text(q.questionType.label, style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text('${q.points} pt${q.points > 1 ? "s" : ""}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                if (widget.isPracticeMode && !isRevealed)
                  TextButton.icon(
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('Check Answer'),
                    onPressed: () => setState(() => _revealedAnswers[q.id] = true),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Question Text
            Text(
              q.questionText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
            ),
            const SizedBox(height: 16),

            // Interactive Input Area (all 5 types supported)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputArea(q),

                    // Real-time AI explanation if revealed in practice mode
                    if (isRevealed) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.withAlpha(80)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.psychology, color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Local AI Real-Time Feedback',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (q.questionType == QuestionType.essay)
                              Text(q.explanation, style: const TextStyle(fontSize: 13, height: 1.4))
                            else ...[
                              Text(
                                'Correct Answer: ${_getCorrectAnswerText(q)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (q.explanation.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(q.explanation, style: const TextStyle(fontSize: 13)),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Navigation Controls
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  if (_currentIndex > 0) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Prev'),
                      onPressed: () => setState(() => _currentIndex--),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(isLast ? Icons.check_circle : Icons.arrow_forward),
                      label: Text(
                        isLast ? 'Submit Assessment' : 'Next Question',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        if (isLast) {
                          _showSubmitConfirmation();
                        } else {
                          setState(() => _currentIndex++);
                        }
                      },
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

  void _showSubmitConfirmation() {
    final unanswered = widget.quiz.questions.where((q) => !_isAnswered(q)).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Assessment?'),
        content: Text(
          unanswered > 0
              ? 'You have $unanswered unanswered questions. Are you sure you want to finalize and grade your assessment now?'
              : 'You have answered all questions. Submit now to generate your results and review AI feedback?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Review Questions'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitQuiz();
            },
            child: const Text('Submit & Grade'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(QuizQuestion q) {
    final theme = Theme.of(context);

    switch (q.questionType) {
      case QuestionType.multipleChoice:
        return Column(
          children: List.generate(q.options.length, (optIdx) {
            final opt = q.options[optIdx];
            final prefix = String.fromCharCode(65 + optIdx);
            final isSelected = _selectedOptionIds[q.id] == opt.id;

            return Card(
              elevation: isSelected ? 2 : 0,
              color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.5 : 1.2,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _selectedOptionIds[q.id] = opt.id),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isSelected ? theme.colorScheme.primary : const Color(0xFFF1F5F9),
                        child: Text(
                          prefix,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          opt.optionText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );

      case QuestionType.trueFalse:
        final selected = _selectedOptionIds[q.id];
        final trueOpt = q.options.where((o) => o.optionText.toLowerCase() == 'true').firstOrNull;
        final falseOpt = q.options.where((o) => o.optionText.toLowerCase() == 'false').firstOrNull;

        return Row(
          children: [
            Expanded(
              child: Card(
                elevation: selected == trueOpt?.id ? 2 : 0,
                color: selected == trueOpt?.id ? const Color(0xFFEEF2FF) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: selected == trueOpt?.id ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                    width: selected == trueOpt?.id ? 1.5 : 1.2,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    if (trueOpt != null) setState(() => _selectedOptionIds[q.id] = trueOpt.id);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('True', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                elevation: selected == falseOpt?.id ? 2 : 0,
                color: selected == falseOpt?.id ? const Color(0xFFEEF2FF) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: selected == falseOpt?.id ? theme.colorScheme.primary : const Color(0xFFE2E8F0),
                    width: selected == falseOpt?.id ? 1.5 : 1.2,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    if (falseOpt != null) setState(() => _selectedOptionIds[q.id] = falseOpt.id);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('False', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

      case QuestionType.identification:
      case QuestionType.fillInBlank:
        final controller = _getController(q.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Identification Term / Answer',
                hintText: 'Type the specific term, concept, or name...',
                prefixIcon: const Icon(Icons.edit),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );

      case QuestionType.enumeration:
        final expectedCount = q.acceptableAnswers.isNotEmpty ? q.acceptableAnswers.length : 3;
        final controllers = _getEnumerationControllers(q.id, expectedCount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enumerate $expectedCount item${expectedCount > 1 ? "s" : ""}:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...List.generate(controllers.length, (idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: controllers[idx],
                  decoration: InputDecoration(
                    labelText: 'Item ${idx + 1}',
                    prefixIcon: CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      child: Text('${idx + 1}', style: const TextStyle(fontSize: 11)),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              );
            }),
          ],
        );

      case QuestionType.essay:
        final controller = _getController(q.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'Essay Response',
                hintText: 'Discuss key concepts, implications, and explanations...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Word count: ${controller.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words',
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
            ),
          ],
        );
    }
  }

  String _getCorrectAnswerText(QuizQuestion q) {
    if (q.questionType == QuestionType.multipleChoice || q.questionType == QuestionType.trueFalse) {
      return q.options.where((o) => o.isCorrect).firstOrNull?.optionText ?? 'N/A';
    }
    return q.acceptableAnswers.join(' / ');
  }
}
