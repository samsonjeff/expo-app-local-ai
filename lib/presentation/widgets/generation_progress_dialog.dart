import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/job.dart';
import '../../providers/quiz_providers.dart';
import 'motion_widgets.dart';

class GenerationProgressDialog extends ConsumerWidget {
  final GenerationJob job;
  final VoidCallback onCancel;

  const GenerationProgressDialog({
    super.key,
    required this.job,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeJobAsync = ref.watch(activeJobStreamProvider);
    final currentJob = activeJobAsync.value ?? job;

    return Dialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing AI Core Indicator
            AiPulseGlow(
              glowColor: theme.colorScheme.primary,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.psychology,
                  size: 36,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'On-Device AI Generating',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Completely offline • Zero cloud data leakage',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: currentJob.progress > 0 ? currentJob.progress : null,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerLowest,
              ),
            ),
            const SizedBox(height: 12),

            // Stage Message
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    currentJob.statusMessage.isNotEmpty
                        ? currentJob.statusMessage
                        : 'Orchestrating inference pipeline...',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(currentJob.progress * 100).toInt()}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Pipeline Stage Steps
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(60)),
              ),
              child: Column(
                children: [
                  _buildStageRow(
                    context,
                    label: 'Document Parsing & Chunking',
                    isComplete: currentJob.stage.index > JobStage.chunkingText.index,
                    isActive: currentJob.stage == JobStage.parsingDocument ||
                        currentJob.stage == JobStage.chunkingText,
                  ),
                  const Divider(height: 16),
                  _buildStageRow(
                    context,
                    label: 'RAM Allocation & Weight Loading',
                    isComplete: currentJob.stage.index > JobStage.loadingModel.index,
                    isActive: currentJob.stage == JobStage.loadingModel,
                  ),
                  const Divider(height: 16),
                  _buildStageRow(
                    context,
                    label: 'Offline Token Streaming',
                    isComplete: currentJob.stage.index > JobStage.generatingInference.index,
                    isActive: currentJob.stage == JobStage.generatingInference,
                  ),
                  const Divider(height: 16),
                  _buildStageRow(
                    context,
                    label: 'JSON Schema Validation & Repair',
                    isComplete: currentJob.stage == JobStage.complete,
                    isActive: currentJob.stage == JobStage.validatingJson,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onCancel();
                },
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancel Generation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageRow(
    BuildContext context, {
    required String label,
    required bool isComplete,
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    IconData icon;
    Color color;

    if (isComplete) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (isActive) {
      icon = Icons.radio_button_checked;
      color = theme.colorScheme.primary;
    } else {
      icon = Icons.radio_button_unchecked;
      color = theme.colorScheme.outlineVariant;
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isComplete || isActive
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
