import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/job.dart';
import '../../models/quiz.dart';
import '../../providers/quiz_providers.dart';
import '../../services/quiz_export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/generation_progress_dialog.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/quiz_config_dialog.dart';
import 'flashcard_review_screen.dart';
import 'quiz_play_screen.dart';
import 'teacher_review_screen.dart';
import 'upload_document_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _pasteTextController;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _pasteTextController = TextEditingController();
  }

  @override
  void dispose() {
    _pasteTextController.dispose();
    super.dispose();
  }

  void _openConfigDialog() {
    QuizConfigDialog.show(
      context: context,
      onStartGeneration: _startGenerationWithJob,
    );
  }

  Future<void> _startGenerationWithJob(GenerationJob job) async {
    setState(() => _isGenerating = true);
    final queue = ref.read(jobQueueManagerProvider);

    // Show progress dialog with token streaming and isolate status
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => GenerationProgressDialog(
        job: job,
        onCancel: () {
          queue.cancelJob(job.id);
          Navigator.pop(dlgCtx);
        },
      ),
    );

    try {
      final quiz = await queue.runQuizGeneration(job);
      if (mounted) {
        Navigator.pop(context); // Dismiss progress dialog
        ref.read(quizzesProvider.notifier).refresh();

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 84, left: 24, right: 24),
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Generated "${quiz.title}" (${quiz.totalQuestions} items)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss dialog
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 84, left: 24, right: 24),
            duration: const Duration(seconds: 3),
            content: Text('Generation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizzesAsync = ref.watch(quizzesProvider);
    final hwAsync = ref.watch(hardwareProfileProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              isDark ? 'assets/MaQui-dark-mode.png' : 'assets/MaQui-light-mode.png',
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(Icons.school, size: 22, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 8),
            Text('MaQui', style: AppTheme.appNameStyle(fontSize: 20)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Uploaded Lesson Materials & Slides',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
              );
            },
          ),
          hwAsync.when(
            data: (hw) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: const Icon(Icons.memory, size: 16),
                label: Text(hw.tier.label, style: const TextStyle(fontSize: 11)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: quizzesAsync.when(
        data: (quizzes) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Core Feature Hero: Prominent Upload PDF/Material Card
            _buildUploadHeroCard(context),
            const SizedBox(height: 14),

            // Quick Paste Text Card (Max 300 characters)
            _buildPasteTextCard(context),
            const SizedBox(height: 18),

            // Recent Assessments Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Quizzes & Reviewers',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${quizzes.length} saved',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (quizzes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.auto_stories_outlined, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No Quizzes Created Yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Upload study material above or paste plain text to generate your first offline quiz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...quizzes.asMap().entries.map(
                    (entry) => _buildAnimatedQuizCard(context, entry.value, entry.key),
                  ),

            const SizedBox(height: 60), // Spacing for extended FAB
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading quizzes: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _openConfigDialog,
        icon: const Icon(Icons.bolt),
        label: const Text('New Assessment'),
      ),
    );
  }

  Widget _buildAnimatedQuizCard(BuildContext context, Quiz quiz, int index) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(quiz.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: (320 + (index * 50)).clamp(320, 700)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: _buildQuizCard(context, quiz),
    );
  }

  Widget _buildUploadHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    return TactilePressCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.colorScheme.primary.withAlpha(50), width: 1.5),
        ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFEEF2FF),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F4F46E5),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(90),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Upload Lesson Material',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'CORE FEATURE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supports PDF, PPTX slides, DOCX, and TXT. Auto-extracts content for offline quizzes.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.file_open_rounded),
                label: const Text(
                  'Choose File from Device',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildPasteTextCard(BuildContext context) {
    final theme = Theme.of(context);
    final currentLength = _pasteTextController.text.length;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields_rounded, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Or Paste Plain Text / Concept',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '$currentLength/300',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: currentLength >= 300 ? Colors.red : theme.colorScheme.outline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pasteTextController,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Paste lecture notes, study definitions, or type a topic (up to 300 characters)...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                counterText: '', // Hide default counter since we display live counter in header
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.2),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('Generate Reviewer from Text'),
                onPressed: _pasteTextController.text.trim().isEmpty
                    ? null
                    : () {
                        final text = _pasteTextController.text.trim();
                        QuizConfigDialog.show(
                          context: context,
                          initialTopic: text,
                          onStartGeneration: _startGenerationWithJob,
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(BuildContext context, Quiz quiz) {
    final theme = Theme.of(context);
    final isExam = quiz.assessmentMode == AssessmentMode.exam;

    final isDark = theme.brightness == Brightness.dark;
    final modeColor = AppTheme.forAssessmentMode(isExam, isDark: isDark);
    final diffColor = AppTheme.forDifficulty(quiz.difficulty.value, isDark: isDark);
    final passColor = AppTheme.forPassingScore(quiz.passingScore, isDark: isDark);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badges Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Mode Badge: Quiz | Exam
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: modeColor.withAlpha(35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: modeColor.withAlpha(60), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExam ? Icons.school : Icons.quiz,
                              size: 14,
                              color: modeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              quiz.assessmentMode.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: modeColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Difficulty Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: diffColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: diffColor.withAlpha(55), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              quiz.difficulty == QuizDifficulty.easy
                                  ? Icons.signal_cellular_alt_1_bar
                                  : (quiz.difficulty == QuizDifficulty.medium
                                      ? Icons.signal_cellular_alt_2_bar
                                      : Icons.signal_cellular_alt),
                              size: 13,
                              color: diffColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              quiz.difficulty.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: diffColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Passing Score Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: passColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: passColor.withAlpha(55), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              quiz.passingScore >= 75 ? Icons.verified_outlined : Icons.flag_outlined,
                              size: 13,
                              color: passColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pass: ${quiz.passingScore}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: passColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete Menu
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(quiz.id),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Quiz Title
            Text(
              quiz.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (quiz.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                quiz.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),

            // Items Count and Question Types Summary
            Text(
              '${quiz.totalQuestions} Questions • ${quiz.totalPoints} Total Points',
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(isExam ? 'Take Exam' : 'Take Quiz'),
                  onPressed: () => _showStudentModeSheet(quiz),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  icon: const Icon(Icons.style_outlined, size: 18),
                  label: const Text('Flashcards'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FlashcardReviewScreen(quiz: quiz)),
                    );
                  },
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Review & Edit'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TeacherReviewScreen(quiz: quiz)),
                    );
                  },
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Export / Print'),
                  onPressed: () => _showExportDialog(quiz),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(Quiz quiz) {
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
              Text(
                'Export & Print: ${quiz.title}',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: Colors.blueAccent),
                title: const Text('Student Test Paper (Questions Only)'),
                subtitle: const Text('Formatted for students with blank answer spaces.'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await QuizExportService.exportAndShare(quiz, includeAnswerKey: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined, color: Colors.green),
                title: const Text('Teacher Key & Rubric (Questions & Answers)'),
                subtitle: const Text('Includes complete answer key, explanations, and essay rubrics.'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await QuizExportService.exportAndShare(quiz, includeAnswerKey: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudentModeSheet(Quiz quiz) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
              Text(
                quiz.title,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                'Select assessment study mode:',
                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.school, color: Colors.white),
                ),
                title: const Text('Mock Exam', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Full examination test with timer. Passing threshold: ${quiz.passingScore}%.'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: Theme.of(ctx).colorScheme.surfaceContainerLow,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => QuizPlayScreen(quiz: quiz, isPracticeMode: false)),
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.lightbulb, color: Colors.white),
                ),
                title: const Text('Practice Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Instant answer verification & offline local AI explanations.'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: Theme.of(ctx).colorScheme.surfaceContainerLow,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => QuizPlayScreen(quiz: quiz, isPracticeMode: true)),
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.style, color: Colors.white),
                ),
                title: const Text('Flashcard Review', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Spaced repetition flip card study session for memory retention.'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: Theme.of(ctx).colorScheme.surfaceContainerLow,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FlashcardReviewScreen(quiz: quiz)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String quizId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Assessment?'),
        content: const Text('This will permanently delete this quiz and all its questions and attempt history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(quizzesProvider.notifier).deleteQuiz(quizId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
