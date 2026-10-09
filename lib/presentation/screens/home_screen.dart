import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/job.dart';
import '../../providers/quiz_providers.dart';
import 'quiz_play_screen.dart';
import 'upload_document_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _topicController = TextEditingController();
  bool _isGenerating = false;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _showGenerateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate New Quiz',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a study topic or concept. On-device AI will generate questions completely offline.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                hintText: 'e.g., Computer Science Data Structures, Cellular Biology...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.psychology),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: const Icon(Icons.bolt),
                label: const Text('Start Offline Generation', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  final topic = _topicController.text.trim();
                  if (topic.isNotEmpty) {
                    Navigator.pop(ctx);
                    _startGeneration(topic);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startGeneration(String topic) async {
    setState(() => _isGenerating = true);

    final queue = ref.read(jobQueueManagerProvider);
    final job = GenerationJob(
      topic: topic,
      questionCount: 3,
      difficulty: 'medium',
      questionTypes: ['multiple_choice', 'true_false', 'identification'],
    );

    // Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => Consumer(
        builder: (context, ref, _) {
          final jobAsync = ref.watch(activeJobStreamProvider);
          final currentJob = jobAsync.value;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.memory, color: Colors.indigoAccent),
                SizedBox(width: 10),
                Text('Local AI Generating...'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: currentJob?.progress ?? 0.05,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 8,
                ),
                const SizedBox(height: 16),
                Text(
                  currentJob?.statusMessage ?? 'Preparing AI pipeline...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Stage: ${currentJob?.stage.label ?? "Starting"}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  queue.cancelJob(job.id);
                  Navigator.pop(dlgCtx);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );

    try {
      final quiz = await queue.runQuizGeneration(job);
      if (mounted) {
        Navigator.pop(context); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated: "${quiz.title}" with ${quiz.totalQuestions} questions!')),
        );
        ref.read(quizzesProvider.notifier).refresh();
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
            tooltip: 'Upload Study Material (PDF, PPTX)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
              );
            },
          ),
          hwAsync.when(
            data: (hw) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: const Icon(Icons.memory, size: 16),
                label: Text(hw.tier.label, style: const TextStyle(fontSize: 12)),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: quizzesAsync.when(
        data: (quizzes) {
          if (quizzes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No Quizzes Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Generate from topic or upload lecture slides (PDF/PPTX).'),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _showGenerateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('From Topic'),
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
                        label: const Text('Upload PDF/PPTX'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: quizzes.length,
            itemBuilder: (ctx, i) {
              final quiz = quizzes[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(quiz.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${quiz.totalQuestions} Questions • ${quiz.category} • ${quiz.difficulty.value}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.indigoAccent),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizPlayScreen(quiz: quiz),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () {
                          ref.read(quizzesProvider.notifier).deleteQuiz(quiz.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading quizzes: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _showGenerateDialog,
        icon: const Icon(Icons.bolt),
        label: const Text('Generate Quiz'),
      ),
    );
  }
}
