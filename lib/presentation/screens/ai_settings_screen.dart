import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../inference/model_catalog.dart';
import '../../models/inference.dart';
import '../../providers/quiz_providers.dart';
import '../../storage/filesystem/file_storage_manager.dart';
import '../../storage/filesystem/model_downloader.dart';
import '../theme/app_theme.dart';
import '../widgets/app_notification.dart';
import '../widgets/motion_widgets.dart';
import 'privacy_promise_screen.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};
  final Map<String, bool> _modelExists = {};
  bool _mockEngineForced = false;

  @override
  void initState() {
    super.initState();
    _checkModelFiles();
  }

  Future<void> _checkModelFiles() async {
    try {
      final modelsDir = await FileStorageManager.instance.getModelsDir();
      for (final model in ModelCatalog.allModels) {
        final f = File(p.join(modelsDir.path, model.filename));
        final exists = await f.exists();
        if (mounted) {
          setState(() {
            _modelExists[model.id] = exists;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _startDownload(ModelSpec model) async {
    setState(() {
      _isDownloading[model.id] = true;
      _downloadProgress[model.id] = 0.0;
    });

    try {
      final downloader = ref.read(modelDownloaderProvider);
      await downloader.downloadModel(
        modelId: model.id,
        url: model.downloadUrl,
        fileName: model.filename,
        onProgress: (progress, received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress[model.id] = progress;
            });
          }
        },
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        AppNotification.showSuccess(context, 'Successfully downloaded ${model.name}!');
      }
    } catch (e) {
      if (mounted) {
        AppNotification.showError(context, 'Download error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading[model.id] = false;
        });
        _checkModelFiles();
      }
    }
  }

  Future<void> _deleteModel(ModelSpec model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${model.name}?'),
        content: Text(
          'This will remove the ${(model.fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB GGUF file from local device storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final modelsDir = await FileStorageManager.instance.getModelsDir();
      final f = File(p.join(modelsDir.path, model.filename));
      if (await f.exists()) {
        await f.delete();
      }
      _checkModelFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hwAsync = ref.watch(hardwareProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Local AI & System',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. Hardware Profile & RAM Diagnostics
          Text(
            'DEVICE HARDWARE PROFILE',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          hwAsync.when(
            data: (hw) => _buildRamDiagnosticsCard(context, hw),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (err, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not profile device RAM: $err'),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // 2. Offline Model Catalog
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OFFLINE MODEL CATALOG',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                'llama.cpp / GGUF',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...ModelCatalog.allModels.map((model) => _buildModelCard(context, model)),

          const SizedBox(height: 28),

          // 3. Developer / Battery Saver Settings
          Text(
            'DEVELOPER & BATTERY SAVER',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.bolt, color: Colors.amber),
              title: const Text('Simulate AI Generation (Mock Engine)'),
              subtitle: const Text(
                'Generates realistic quizzes without loading heavy weights or consuming battery. Ideal for testing UI.',
              ),
              value: _mockEngineForced,
              onChanged: (val) {
                setState(() => _mockEngineForced = val);
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'PRIVACY & LEGAL',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shield_outlined, color: Color(0xFF4F46E5)),
              title: const Text('Welcome & Offline Privacy Promise'),
              subtitle: const Text('Combined Notice: 100% on-device data guarantees & terms'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPromiseScreen(isReviewMode: true),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRamDiagnosticsCard(BuildContext context, HardwareProfile hw) {
    final theme = Theme.of(context);
    final totalGb = (hw.totalRamMb / 1024).toStringAsFixed(1);
    final availGb = (hw.availableRamMb / 1024).toStringAsFixed(1);
    final ramRatio = hw.totalRamMb > 0
        ? (hw.totalRamMb - hw.availableRamMb) / hw.totalRamMb
        : 0.5;

    final isLowTier = hw.tier == HardwareTier.low;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.memory,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Memory: $totalGb GB',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$availGb GB Available for Inference',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (_) {
                    final tierColor = isLowTier ? AppTheme.warning : AppTheme.success;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: tierColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tierColor.withAlpha(55), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLowTier ? Icons.speed : Icons.rocket_launch,
                            size: 13,
                            color: tierColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isLowTier ? '4GB Tier' : 'High Tier',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: tierColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ramRatio.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation(
                  ramRatio > 0.85
                       ? AppTheme.error
                       : (ramRatio > 0.65 ? AppTheme.warning : theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recommended: ${isLowTier ? "Qwen 1.7B (4K Context)" : "Phi-4-mini (8K Context)"}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(ramRatio * 100).toInt()}% Used',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(BuildContext context, ModelSpec model) {
    final theme = Theme.of(context);
    final sizeGb = (model.fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
    final ramGb = (model.requiredRamMb / 1024).toStringAsFixed(1);
    final exists = _modelExists[model.id] ?? false;
    final isDownloading = _isDownloading[model.id] ?? false;
    final progress = _downloadProgress[model.id] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: exists
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      exists ? Icons.check_circle : Icons.download_for_offline,
                      color: exists ? AppTheme.success : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Size: $sizeGb GB • Requires ~$ramGb GB RAM • ${model.quantization}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Downloading weights...',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ] else if (exists) ...[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          'Installed & Offline Ready',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _deleteModel(model),
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: BorderSide(color: Colors.red.withAlpha(80)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TactilePressCard(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _startDownload(model),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _startDownload(model),
                      icon: const Icon(Icons.download, size: 18),
                      label: Text('Download $sizeGb GB Model'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
