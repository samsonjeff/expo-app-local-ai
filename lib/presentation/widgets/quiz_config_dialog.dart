import 'app_notification.dart';
import 'package:flutter/material.dart';
import '../../models/document.dart';
import '../../models/job.dart';
import '../../models/quiz.dart';

class QuizConfigDialog extends StatefulWidget {
  final DocumentMetadata? document;
  final String? initialTopic;
  final Function(GenerationJob job) onStartGeneration;

  const QuizConfigDialog({
    super.key,
    this.document,
    this.initialTopic,
    required this.onStartGeneration,
  });

  static Future<void> show({
    required BuildContext context,
    DocumentMetadata? document,
    String? initialTopic,
    required Function(GenerationJob job) onStartGeneration,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => QuizConfigDialog(
        document: document,
        initialTopic: initialTopic,
        onStartGeneration: onStartGeneration,
      ),
    );
  }

  @override
  State<QuizConfigDialog> createState() => _QuizConfigDialogState();
}

class _QuizConfigDialogState extends State<QuizConfigDialog> {
  late final TextEditingController _topicController;
  AssessmentMode _mode = AssessmentMode.quiz;
  int _itemCount = 10;
  QuizDifficulty _difficulty = QuizDifficulty.medium;
  int _passingScore = 70;
  final Set<QuestionType> _selectedQuestionTypes = {
    QuestionType.multipleChoice,
    QuestionType.trueFalse,
    QuestionType.identification,
  };

  final List<int> _itemCountOptions = [5, 10, 20, 40, 50, 60, 80, 100];

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(
      text: widget.initialTopic ?? widget.document?.fileName ?? '',
    );
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _submit() {
    final topic = _topicController.text.trim();
    if (widget.document == null && topic.isEmpty) {
      AppNotification.showWarning(context, 'Please enter a topic or concept.', bottomMargin: 24);
      return;
    }

    if (_selectedQuestionTypes.isEmpty) {
      AppNotification.showWarning(context, 'Please select at least one question type.', bottomMargin: 24);
      return;
    }

    final job = GenerationJob(
      documentId: widget.document?.id,
      topic: topic.isNotEmpty ? topic : (widget.document?.fileName ?? 'Quiz'),
      questionCount: _itemCount,
      difficulty: _difficulty.value,
      assessmentMode: _mode.value,
      passingScore: _passingScore,
      questionTypes: _selectedQuestionTypes.map((t) => t.value).toList(),
    );

    Navigator.pop(context);
    widget.onStartGeneration(job);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: ListView(
          controller: scrollController,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Header Title
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.tune, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.document != null ? 'Generate from Document' : 'Configure Assessment',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.document != null
                            ? 'Source: ${widget.document!.fileName}'
                            : 'Set parameters for offline local AI generation',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Topic / Title Input (if not generating from document or allows renaming)
            if (widget.document == null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Topic or Concept / Plain Text',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Max 300 chars',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _topicController,
                maxLength: 300,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'e.g., Computer Science Data Structures, Cellular Biology, or paste notes (max 300 chars)...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 44),
                    child: Icon(Icons.psychology_outlined),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. Assessment Mode: Quiz | Exam
            Text(
              'Assessment Mode',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AssessmentMode>(
              segments: const [
                ButtonSegment(
                  value: AssessmentMode.quiz,
                  label: Text('Quiz'),
                  icon: Icon(Icons.quiz_outlined),
                ),
                ButtonSegment(
                  value: AssessmentMode.exam,
                  label: Text('Exam'),
                  icon: Icon(Icons.school_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (set) => setState(() => _mode = set.first),
            ),
            const SizedBox(height: 20),

            // 2. Total Items: 10 | 20 | 40 | 50 | 60 | 80 | 100
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Items',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_itemCount Questions',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _itemCountOptions.map((count) {
                final isSelected = _itemCount == count;
                return ChoiceChip(
                  label: Text('$count'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _itemCount = count);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 3. Difficulty Level: Easy | Medium | Hard
            Text(
              'Difficulty Level',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<QuizDifficulty>(
              segments: const [
                ButtonSegment(value: QuizDifficulty.easy, label: Text('Easy')),
                ButtonSegment(value: QuizDifficulty.medium, label: Text('Medium')),
                ButtonSegment(value: QuizDifficulty.hard, label: Text('Hard')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (set) => setState(() => _difficulty = set.first),
            ),
            const SizedBox(height: 20),

            // 4. Question Types: Multiple Choice, True or False, Identification, Enumeration, Essay
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question Types',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_selectedQuestionTypes.length} selected',
                  style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeChip(QuestionType.multipleChoice, Icons.format_list_bulleted),
                _buildTypeChip(QuestionType.trueFalse, Icons.check_box_outlined),
                _buildTypeChip(QuestionType.identification, Icons.search),
                _buildTypeChip(QuestionType.enumeration, Icons.format_list_numbered),
                _buildTypeChip(QuestionType.essay, Icons.edit_note),
              ],
            ),
            const SizedBox(height: 20),

            // 5. Passing Score: 50% – 100% (Adjustable via slider)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Passing Score Threshold',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _passingScore >= 75
                        ? Colors.green.withAlpha(40)
                        : theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_passingScore%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _passingScore >= 75 ? Colors.green.shade700 : theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _passingScore.toDouble(),
              min: 50.0,
              max: 100.0,
              divisions: 10,
              label: '$_passingScore%',
              onChanged: (val) => setState(() => _passingScore = val.round()),
            ),
            const SizedBox(height: 24),

            // Generate Action Button
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.bolt),
                label: Text(
                  'Start Offline Generation ($_itemCount Items)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(QuestionType type, IconData icon) {
    final isSelected = _selectedQuestionTypes.contains(type);
    return FilterChip(
      avatar: Icon(icon, size: 16),
      label: Text(type.label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedQuestionTypes.add(type);
          } else {
            if (_selectedQuestionTypes.length > 1) {
              _selectedQuestionTypes.remove(type);
            }
          }
        });
      },
    );
  }
}
