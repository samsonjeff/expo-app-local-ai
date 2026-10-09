import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/document.dart';
import '../../models/job.dart';
import '../../orchestration/document_parser.dart';
import '../../providers/quiz_providers.dart';
import '../widgets/generation_progress_dialog.dart';
import '../widgets/quiz_config_dialog.dart';
import 'teacher_review_screen.dart';

class UploadDocumentScreen extends ConsumerStatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  ConsumerState<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends ConsumerState<UploadDocumentScreen> {
  bool _isProcessing = false;
  String? _statusText;

  Future<void> _pickAndProcessFile() async {
    try {
      final pickedFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'pptx', 'docx', 'txt', 'md'],
      );

      if (pickedFile == null) return;

      final fileName = pickedFile.name;
      final bytes = await pickedFile.readAsBytes();

      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file data. Please try another file.')),
          );
        }
        return;
      }

      setState(() {
        _isProcessing = true;
        _statusText = 'Extracting text from $fileName...';
      });

      final docType = DocumentType.fromPath(fileName);
      final extractedText = await DocumentParser.parseBytesAsync(bytes, docType);

      if (extractedText.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No readable text could be extracted from this document.')),
          );
        }
        return;
      }

      final doc = DocumentMetadata(
        fileName: fileName,
        filePath: pickedFile.path ?? fileName,
        type: docType,
        fileSizeBytes: bytes.length,
        characterCount: extractedText.length,
        estimatedTokens: extractedText.length ~/ 4,
        extractedText: extractedText,
      );

      await ref.read(documentsProvider.notifier).addDocument(doc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded "$fileName" successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading document: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = null;
        });
      }
    }
  }

  void _showGenerateFromDocDialog(DocumentMetadata doc) {
    QuizConfigDialog.show(
      context: context,
      document: doc,
      onStartGeneration: (job) => _generateQuizFromDoc(job),
    );
  }

  Future<void> _generateQuizFromDoc(GenerationJob job) async {
    final queue = ref.read(jobQueueManagerProvider);

    // Show progress dialog
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
        Navigator.pop(context); // Return to home
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  IconData _iconForDocType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.pptx:
        return Icons.slideshow;
      case DocumentType.docx:
        return Icons.description;
      case DocumentType.txt:
      case DocumentType.md:
        return Icons.article;
    }
  }

  Color _colorForDocType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Colors.redAccent;
      case DocumentType.pptx:
        return Colors.orangeAccent;
      case DocumentType.docx:
        return Colors.blueAccent;
      case DocumentType.txt:
      case DocumentType.md:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents & Slides', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Upload Action Header Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                  Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      child: Icon(Icons.upload_file, size: 28, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload Study Material',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports PDF, PPTX (PowerPoint), DOCX, TXT',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isProcessing) ...[
                  LinearProgressIndicator(borderRadius: BorderRadius.circular(8)),
                  const SizedBox(height: 8),
                  Text(_statusText ?? 'Processing...', style: const TextStyle(fontSize: 12, color: Colors.indigo)),
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.file_open),
                      label: const Text('Choose File from Device'),
                      onPressed: _pickAndProcessFile,
                    ),
                  ),
              ],
            ),
          ),

          // Uploaded Documents List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Uploaded Documents',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                docsAsync.when(
                  data: (docs) => Text('${docs.length} items', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Documents List
          Expanded(
            child: docsAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('No documents uploaded yet', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Upload a PDF lecture note or PowerPoint slide to begin.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final color = _colorForDocType(doc.type);
                    final icon = _iconForDocType(doc.type);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(icon, color: color),
                        ),
                        title: Text(doc.fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${(doc.fileSizeBytes / 1024).toStringAsFixed(1)} KB • Ready for Generation',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.play_arrow_rounded, color: Colors.indigoAccent, size: 22),
                              tooltip: 'Start Quiz Generation',
                              onPressed: () => _showGenerateFromDocDialog(doc),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: 'Delete Document',
                              onPressed: () {
                                ref.read(documentsProvider.notifier).deleteDocument(doc.id);
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
              error: (err, _) => Center(child: Text('Error loading documents: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
