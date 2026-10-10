import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/document.dart';
import '../../models/job.dart';
import '../../orchestration/document_parser.dart';
import '../../providers/quiz_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/generation_progress_dialog.dart';
import '../widgets/quiz_config_dialog.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/app_notification.dart';

class UploadDocumentScreen extends ConsumerStatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  ConsumerState<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends ConsumerState<UploadDocumentScreen> {
  bool _isPicking = false;
  bool _isProcessing = false;
  String? _statusText;

  Future<void> _pickAndProcessFile() async {
    if (_isPicking || _isProcessing) return;

    setState(() {
      _isPicking = true;
      _statusText = 'Opening file selector...';
    });

    try {
      final pickedFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'pptx', 'docx', 'txt', 'md'],
      );

      if (pickedFile == null) return;

      final fileName = pickedFile.name;
      setState(() {
        _isProcessing = true;
        _statusText = 'Reading $fileName...';
      });

      final bytes = await pickedFile.readAsBytes();

      if (bytes.isEmpty) {
        if (mounted) {
          AppNotification.showWarning(context, 'Could not read file data. Please try another file.');
        }
        return;
      }

      setState(() {
        _statusText = 'Extracting text from $fileName...';
      });

      final docType = DocumentType.fromPath(fileName);
      final extractedText = await DocumentParser.parseBytesAsync(bytes, docType);

      if (extractedText.trim().isEmpty) {
        if (mounted) {
          AppNotification.showWarning(context, 'No readable text could be extracted from this document.');
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
        AppNotification.showSuccess(context, 'Uploaded "$fileName" successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppNotification.showError(context, 'Error uploading document: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
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

        AppNotification.showSuccess(context, 'Generated "${quiz.title}" (${quiz.totalQuestions} items)');
        final isRootShell = ModalRoute.of(context)?.isFirst ?? true;
        if (!isRootShell && Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss dialog
        AppNotification.showError(context, 'Generation failed: $e');
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

  Color _colorForDocType(DocumentType type, bool isDark) {
    return AppTheme.forDocType(type.name, isDark: isDark);
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents & Slides', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Upload Action Header Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [
                            Color(0xFF1E1B4B),
                            Color(0xFF111827),
                          ]
                        : const [
                            Color(0xFFEEF2FF),
                            Colors.white,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withAlpha(50),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F4F46E5),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(minHeight: 6),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _statusText ?? 'Processing...',
                          key: ValueKey<String>(_statusText ?? ''),
                          style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ] else
                      TactilePressCard(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.file_open),
                            label: const Text('Choose File from Device'),
                            onPressed: (_isPicking || _isProcessing) ? null : _pickAndProcessFile,
                          ),
                        ),
                      ),
                  ],
                ),
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

          // Documents List with Staggered Cascades
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
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final color = _colorForDocType(doc.type, isDark);
                    final icon = _iconForDocType(doc.type);

                    return TweenAnimationBuilder<double>(
                      key: ValueKey(doc.id),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: (280 + (i * 50)).clamp(280, 700)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1.0 - value)),
                          child: child,
                        ),
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 1.2,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withAlpha(30),
                            child: Icon(icon, color: color),
                          ),
                          title: Text(doc.fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${(doc.fileSizeBytes / 1024).toStringAsFixed(1)} KB • Ready for Generation',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TactilePressCard(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _showGenerateFromDocDialog(doc),
                                child: IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                                  tooltip: 'Start Quiz Generation',
                                  onPressed: () => _showGenerateFromDocDialog(doc),
                                ),
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
