import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/job.dart';
import '../../models/quiz.dart';
import '../../providers/quiz_providers.dart';
import '../../services/quiz_export_service.dart';
import '../widgets/generation_progress_dialog.dart';
import '../widgets/quiz_config_dialog.dart';
import 'flashcard_review_screen.dart';
import 'quiz_play_screen.dart';
import 'teacher_review_screen.dart';
import 'upload_document_screen.dart';

enum HomeTabFilter { all, teacher, student }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HomeTabFilter _tabFilter = HomeTabFilter.all;
  bool _isGenerating = false;

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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated: "${quiz.title}" with ${quiz.totalQuestions} questions!'),
            action: SnackBarAction(
              label: 'Review & Edit',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TeacherReviewScreen(quiz: quiz)),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e'), backgroundColor: Colors.red),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local AI Quiz App', style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: Column(
        children: [
          // Filter Header: All | Teacher Hub | Student Hub
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<HomeTabFilter>(
                    segments: const [
                      ButtonSegment(value: HomeTabFilter.all, label: Text('All')),
                      ButtonSegment(
                        value: HomeTabFilter.teacher,
                        label: Text('Teacher Hub'),
                        icon: Icon(Icons.edit_note),
                      ),
                      ButtonSegment(
                        value: HomeTabFilter.student,
                        label: Text('Student Hub'),
                        icon: Icon(Icons.school),
                      ),
                    ],
                    selected: {_tabFilter},
                    onSelectionChanged: (set) => setState(() => _tabFilter = set.first),
                  ),
                ),
              ],
            ),
          ),

          // Main Quizzes List
          Expanded(
            child: quizzesAsync.when(
              data: (quizzes) {
                if (quizzes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_stories_outlined, size: 70, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No Assessments Created Yet',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Generate customized quizzes & exams from lesson modules (.pdf, .pptx, .docx) or any topic completely offline.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: _openConfigDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Generate from Topic'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
                                  );
                                },
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Upload Materials'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: quizzes.length,
                  itemBuilder: (ctx, i) {
                    final quiz = quizzes[i];
                    return _buildQuizCard(context, quiz);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading quizzes: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _openConfigDialog,
        icon: const Icon(Icons.bolt),
        label: const Text('New Assessment'),
      ),
    );
  }

  Widget _buildQuizCard(BuildContext context, Quiz quiz) {
    final theme = Theme.of(context);
    final isExam = quiz.assessmentMode == AssessmentMode.exam;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badges Row
            Row(
              children: [
                // Mode Badge: Quiz | Exam
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExam ? Colors.deepPurple.withAlpha(35) : Colors.indigo.withAlpha(35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExam ? Icons.school : Icons.quiz,
                        size: 14,
                        color: isExam ? Colors.deepPurple : Colors.indigo,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        quiz.assessmentMode.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isExam ? Colors.deepPurple : Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Difficulty Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    quiz.difficulty.label,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),

                // Passing Score Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pass: ${quiz.passingScore}%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                  ),
                ),
                const Spacer(),

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

            // Action Buttons based on Tab Filter or Unified Bar
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Student Actions
                if (_tabFilter == HomeTabFilter.all || _tabFilter == HomeTabFilter.student) ...[
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
                ],

                // Teacher Actions
                if (_tabFilter == HomeTabFilter.all || _tabFilter == HomeTabFilter.teacher) ...[
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
    );
  }

  void _showStudentModeSheet(Quiz quiz) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quiz.title,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Select assessment study mode:',
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            ListTile(
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
