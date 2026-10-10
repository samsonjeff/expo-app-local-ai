import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/quiz.dart';
import '../../providers/quiz_providers.dart';
import '../../services/quiz_export_service.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/app_notification.dart';

enum TeacherViewMode {
  questionOnly('Question Only'),
  questionAndAnswer('Question & Answer');

  final String label;
  const TeacherViewMode(this.label);
}

class TeacherReviewScreen extends ConsumerStatefulWidget {
  final Quiz quiz;

  const TeacherReviewScreen({super.key, required this.quiz});

  @override
  ConsumerState<TeacherReviewScreen> createState() => _TeacherReviewScreenState();
}

class _TeacherReviewScreenState extends ConsumerState<TeacherReviewScreen> {
  late Quiz _currentQuiz;
  TeacherViewMode _viewMode = TeacherViewMode.questionAndAnswer;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentQuiz = widget.quiz;
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(quizRepositoryProvider);
      await repo.saveQuiz(_currentQuiz);
      ref.read(quizzesProvider.notifier).refresh();

      setState(() => _hasUnsavedChanges = false);

      if (mounted) {
        AppNotification.showSuccess(context, 'Quiz changes saved successfully!', bottomMargin: 24);
      }
    } catch (e) {
      if (mounted) {
        AppNotification.showError(context, 'Error saving quiz: $e', bottomMargin: 24);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showExportModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                    child: Icon(Icons.print_outlined, color: Theme.of(ctx).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Export & Print Assessment',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: Colors.blueAccent),
                title: const Text('Student Test Paper (Questions Only)'),
                subtitle: const Text('Formatted for student test taking with blank spaces & answer options.'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await QuizExportService.exportAndShare(_currentQuiz, includeAnswerKey: false);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.key_outlined, color: Colors.green),
                title: const Text('Teacher Key & Rubric (Questions & Answers)'),
                subtitle: const Text('Reveals all answers, explanations, and essay grading rubrics.'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await QuizExportService.exportAndShare(_currentQuiz, includeAnswerKey: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditQuestionDialog(QuizQuestion q, int index) {
    final textController = TextEditingController(text: q.questionText);
    final explanationController = TextEditingController(text: q.explanation);
    int points = q.points;
    QuestionType qType = q.questionType;

    // Options for Multiple Choice
    List<QuizOption> options = List.from(q.options);
    // Acceptable answers for Identification/Enumeration
    final acceptableController = TextEditingController(text: q.acceptableAnswers.join(', '));

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          title: Text('Edit Question ${index + 1}'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Question Text',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<QuestionType>(
                          initialValue: qType,
                          decoration: InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: QuestionType.values
                              .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => qType = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          initialValue: points.toString(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Points',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (v) => points = int.tryParse(v) ?? points,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (qType == QuestionType.multipleChoice) ...[
                    const Text('Options (select the radio for correct answer):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...List.generate(options.length, (optIdx) {
                      final opt = options[optIdx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                opt.isCorrect ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: opt.isCorrect ? Colors.green : Colors.grey,
                              ),
                              onPressed: () {
                                setDlgState(() {
                                  options = options.asMap().entries.map((entry) {
                                    return entry.value.copyWith(isCorrect: entry.key == optIdx);
                                  }).toList();
                                });
                              },
                            ),
                            Expanded(
                              child: TextFormField(
                                initialValue: opt.optionText,
                                decoration: InputDecoration(
                                  hintText: 'Option ${String.fromCharCode(65 + optIdx)}',
                                  isDense: true,
                                ),
                                onChanged: (text) {
                                  options[optIdx] = opt.copyWith(optionText: text);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else if (qType == QuestionType.trueFalse) ...[
                    const Text('Correct Answer:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('True'),
                          selected: options.where((o) => o.isCorrect).firstOrNull?.optionText.toLowerCase() == 'true',
                          onSelected: (sel) {
                            setDlgState(() {
                              options = [
                                QuizOption(optionText: 'True', isCorrect: true),
                                QuizOption(optionText: 'False', isCorrect: false),
                              ];
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('False'),
                          selected: options.where((o) => o.isCorrect).firstOrNull?.optionText.toLowerCase() == 'false',
                          onSelected: (sel) {
                            setDlgState(() {
                              options = [
                                QuizOption(optionText: 'True', isCorrect: false),
                                QuizOption(optionText: 'False', isCorrect: true),
                              ];
                            });
                          },
                        ),
                      ],
                    ),
                  ] else if (qType == QuestionType.identification || qType == QuestionType.enumeration) ...[
                    TextField(
                      controller: acceptableController,
                      decoration: InputDecoration(
                        labelText: qType == QuestionType.enumeration
                            ? 'Acceptable Items (comma separated)'
                            : 'Acceptable Answers (comma separated)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: explanationController,
                    maxLines: qType == QuestionType.essay ? 5 : 3,
                    decoration: InputDecoration(
                      labelText: qType == QuestionType.essay ? 'AI Rubric Key & Model Answer' : 'Explanation & Rationale',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final acceptableList = acceptableController.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                final updatedQ = q.copyWith(
                  questionText: textController.text.trim(),
                  points: points,
                  questionType: qType,
                  explanation: explanationController.text.trim(),
                  options: options,
                  acceptableAnswers: acceptableList,
                );

                setState(() {
                  final newQuestions = List<QuizQuestion>.from(_currentQuiz.questions);
                  newQuestions[index] = updatedQ;
                  _currentQuiz = _currentQuiz.copyWith(questions: newQuestions);
                  _hasUnsavedChanges = true;
                });

                Navigator.pop(dlgCtx);
              },
              child: const Text('Apply Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewQuestion() {
    final newQ = QuizQuestion(
      questionText: 'New question description...',
      questionType: QuestionType.multipleChoice,
      points: 1,
      explanation: 'Explanation for correct answer.',
      orderIndex: _currentQuiz.questions.length,
      options: [
        QuizOption(optionText: 'Option A (Correct)', isCorrect: true),
        QuizOption(optionText: 'Option B', isCorrect: false),
        QuizOption(optionText: 'Option C', isCorrect: false),
        QuizOption(optionText: 'Option D', isCorrect: false),
      ],
    );

    setState(() {
      _currentQuiz = _currentQuiz.copyWith(
        questions: [..._currentQuiz.questions, newQ],
      );
      _hasUnsavedChanges = true;
    });

    _showEditQuestionDialog(newQ, _currentQuiz.questions.length - 1);
  }

  void _deleteQuestion(int index) {
    setState(() {
      final updatedQuestions = List<QuizQuestion>.from(_currentQuiz.questions);
      updatedQuestions.removeAt(index);
      _currentQuiz = _currentQuiz.copyWith(questions: updatedQuestions);
      _hasUnsavedChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentQuiz.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '${_currentQuiz.assessmentMode.label} • ${_currentQuiz.questions.length} Items • Pass: ${_currentQuiz.passingScore}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Export & Print Assessment',
            onPressed: _showExportModal,
          ),
          if (_hasUnsavedChanges)
            TextButton.icon(
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Save'),
              onPressed: _isSaving ? null : _saveChanges,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // View Mode Control Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _viewMode == TeacherViewMode.questionAndAnswer ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'View Mode:',
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SegmentedButton<TeacherViewMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TeacherViewMode.questionOnly,
                      label: Text('Questions'),
                    ),
                    ButtonSegment(
                      value: TeacherViewMode.questionAndAnswer,
                      label: Text('Q & A'),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (set) => setState(() => _viewMode = set.first),
                ),
              ],
            ),
          ),

          // Question Items List
          Expanded(
            child: _currentQuiz.questions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.quiz_outlined, size: 60, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('No questions in this assessment.'),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _addNewQuestion,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Question'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _currentQuiz.questions.length,
                    itemBuilder: (ctx, i) {
                      final q = _currentQuiz.questions[i];
                      return _buildQuestionCard(q, i);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: TactilePressCard(
        borderRadius: BorderRadius.circular(16),
        onTap: _addNewQuestion,
        child: FloatingActionButton.extended(
          onPressed: _addNewQuestion,
          icon: const Icon(Icons.add),
          label: const Text('Add Question'),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion q, int index) {
    final theme = Theme.of(context);
    final showAnswerKey = _viewMode == TeacherViewMode.questionAndAnswer;

    return TweenAnimationBuilder<double>(
      key: ValueKey(q.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: (280 + (index * 45)).clamp(280, 650)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1.0 - value)),
          child: child,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
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
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            q.questionType.label,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${q.points} pt${q.points > 1 ? "s" : ""}',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit Item',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showEditQuestionDialog(q, index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                    tooltip: 'Delete Item',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _deleteQuestion(index),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Question Text
              Text(
                q.questionText,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),

              // Options / Answering Area
              _buildOptionsOrAnsweringArea(q, showAnswerKey),

              // Answer Key & Rationale (Revealed when Question & Answer is active)
              if (showAnswerKey) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildAnswerKeySection(q),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsOrAnsweringArea(QuizQuestion q, bool showAnswerKey) {
    final theme = Theme.of(context);

    switch (q.questionType) {
      case QuestionType.multipleChoice:
        return Column(
          children: List.generate(q.options.length, (optIdx) {
            final opt = q.options[optIdx];
            final prefix = String.fromCharCode(65 + optIdx);
            final isCorrect = opt.isCorrect;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (showAnswerKey && isCorrect)
                    ? Colors.green.withAlpha(25)
                    : theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (showAnswerKey && isCorrect)
                      ? Colors.green.shade400
                      : theme.colorScheme.outlineVariant.withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '($prefix)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (showAnswerKey && isCorrect) ? Colors.green.shade700 : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      opt.optionText,
                      style: TextStyle(
                        fontWeight: (showAnswerKey && isCorrect) ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (showAnswerKey && isCorrect) ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 4),
                    const Text('Answer', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            );
          }),
        );

      case QuestionType.trueFalse:
        final correctIs = q.options.where((o) => o.isCorrect).firstOrNull?.optionText.toLowerCase();

        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: (showAnswerKey && correctIs == 'true')
                      ? Colors.green.withAlpha(30)
                      : theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (showAnswerKey && correctIs == 'true')
                        ? Colors.green
                        : theme.colorScheme.outlineVariant.withAlpha(80),
                  ),
                ),
                child: Center(
                  child: Text(
                    'True',
                    style: TextStyle(
                      fontWeight: (showAnswerKey && correctIs == 'true') ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: (showAnswerKey && correctIs == 'false')
                      ? Colors.green.withAlpha(30)
                      : theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (showAnswerKey && correctIs == 'false')
                        ? Colors.green
                        : theme.colorScheme.outlineVariant.withAlpha(80),
                  ),
                ),
                child: Center(
                  child: Text(
                    'False',
                    style: TextStyle(
                      fontWeight: (showAnswerKey && correctIs == 'false') ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

      case QuestionType.identification:
      case QuestionType.fillInBlank:
        if (!showAnswerKey) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
            ),
            child: const Text('____________________________________________________', style: TextStyle(color: Colors.grey)),
          );
        }
        return const SizedBox.shrink();

      case QuestionType.enumeration:
        if (!showAnswerKey) {
          return Column(
            children: [
              for (int item = 1; item <= 3; item++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text('$item. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }
        return const SizedBox.shrink();

      case QuestionType.essay:
        if (!showAnswerKey) {
          return Container(
            height: 70,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
            ),
            child: const Text('[Student Essay Written Response Area]', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          );
        }
        return const SizedBox.shrink();
    }
  }

  Widget _buildAnswerKeySection(QuizQuestion q) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Answer Key & Rubric Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (q.questionType == QuestionType.identification || q.questionType == QuestionType.fillInBlank) ...[
            Text(
              'Acceptable Terms: ${q.acceptableAnswers.join(" | ")}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
            ),
            const SizedBox(height: 4),
          ],

          if (q.questionType == QuestionType.enumeration) ...[
            const Text('Expected Enumerated Items:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...q.acceptableAnswers.map((item) => Text('• $item', style: const TextStyle(color: Colors.green))),
            const SizedBox(height: 4),
          ],

          if (q.questionType == QuestionType.essay) ...[
            const Text('AI Rubric Key & Model Answer:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                q.explanation,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ] else if (q.explanation.isNotEmpty) ...[
            Text(
              'Explanation: ${q.explanation}',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
