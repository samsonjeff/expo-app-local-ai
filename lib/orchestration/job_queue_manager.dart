import 'dart:async';
import '../inference/model_catalog.dart';
import '../inference/model_lifecycle_manager.dart';
import '../inference/ram_detector.dart';
import '../models/job.dart';
import '../models/quiz.dart';
import '../storage/database/document_repository.dart';
import '../storage/database/job_repository.dart';
import '../storage/database/quiz_repository.dart';
import 'document_chunker.dart';
import 'document_parser.dart';
import 'json_validator.dart';
import 'prompt_builder.dart';

class JobQueueManager {
  final JobRepository jobRepo;
  final DocumentRepository docRepo;
  final QuizRepository quizRepo;
  final ModelLifecycleManager lifecycleManager;

  final _jobUpdateController = StreamController<GenerationJob>.broadcast();
  Stream<GenerationJob> get jobUpdates => _jobUpdateController.stream;

  final Set<String> _cancellationRequests = {};

  JobQueueManager({
    required this.jobRepo,
    required this.docRepo,
    required this.quizRepo,
    required this.lifecycleManager,
  });

  Future<void> cancelJob(String jobId) async {
    _cancellationRequests.add(jobId);
    final job = await jobRepo.getJobById(jobId);
    if (job != null && job.status == JobStatus.running) {
      final updated = job.copyWith(
        status: JobStatus.cancelled,
        statusMessage: 'Cancelled by user',
      );
      await jobRepo.saveJob(updated);
      _jobUpdateController.add(updated);
    }
  }

  Future<Quiz> runQuizGeneration(GenerationJob initialJob) async {
    var currentJob = initialJob.copyWith(
      status: JobStatus.running,
      stage: JobStage.idle,
      progress: 0.05,
      statusMessage: 'Starting generation pipeline...',
    );
    await _emit(currentJob);

    try {
      _checkCancelled(currentJob.id);

      // 1. Parsing Document
      String contextContent = '';
      if (currentJob.documentId != null) {
        currentJob = currentJob.copyWith(
          stage: JobStage.parsingDocument,
          progress: JobStage.parsingDocument.baseProgress,
          statusMessage: 'Extracting text from document...',
        );
        await _emit(currentJob);

        final doc = await docRepo.getDocumentById(currentJob.documentId!);
        if (doc != null) {
          contextContent = await DocumentParser.parseFileInIsolate(doc.filePath);
        }
      }

      _checkCancelled(currentJob.id);

      // 2. Chunking Text
      if (contextContent.isNotEmpty) {
        currentJob = currentJob.copyWith(
          stage: JobStage.chunkingText,
          progress: JobStage.chunkingText.baseProgress,
          statusMessage: 'Optimizing text chunks for context window...',
        );
        await _emit(currentJob);

        final chunks = await DocumentChunker.chunkTextInIsolate(contextContent);
        if (chunks.isNotEmpty) {
          contextContent = chunks.first.text;
        }
      }

      _checkCancelled(currentJob.id);

      // 3. Hardware Tier & Model Setup
      final hwProfile = await RamDetector.detectProfile();
      final modelSpec = ModelCatalog.getRecommendedModel(hwProfile.tier);

      currentJob = currentJob.copyWith(
        stage: JobStage.loadingModel,
        progress: JobStage.loadingModel.baseProgress,
        statusMessage: 'Initializing ${modelSpec.name}...',
      );
      await _emit(currentJob);

      // 4. Prompt Building
      final prompt = PromptBuilder.buildQuizPrompt(
        content: contextContent.isNotEmpty ? contextContent : null,
        topic: currentJob.topic,
        questionCount: currentJob.questionCount,
        difficulty: currentJob.difficulty,
        questionTypes: currentJob.questionTypes,
      );

      // 5. Inference Execution with strict RAM lifecycle management
      final rawOutputBuffer = StringBuffer();

      await lifecycleManager.executeWithModel(
        modelPath: modelSpec.filename,
        action: () async {
          currentJob = currentJob.copyWith(
            stage: JobStage.generatingInference,
            progress: JobStage.generatingInference.baseProgress,
            statusMessage: 'Streaming tokens from AI engine...',
          );
          await _emit(currentJob);

          var tokenCount = 0;
          final stream = lifecycleManager.bridge.generate(prompt);

          await for (final chunk in stream) {
            _checkCancelled(currentJob.id);
            rawOutputBuffer.write(chunk.token);
            tokenCount = chunk.totalTokensSoFar;

            if (tokenCount % 10 == 0) {
              final progressVal = (0.50 + (tokenCount / 200) * 0.35).clamp(0.50, 0.85);
              currentJob = currentJob.copyWith(
                progress: progressVal,
                statusMessage: 'Generated $tokenCount tokens...',
              );
              await _emit(currentJob);
            }
          }
        },
      );

      // 6. Freeing RAM
      currentJob = currentJob.copyWith(
        stage: JobStage.unloadingModel,
        progress: JobStage.unloadingModel.baseProgress,
        statusMessage: 'Unloaded AI model from RAM',
      );
      await _emit(currentJob);

      // 7. JSON Validation & Auto-repair
      currentJob = currentJob.copyWith(
        stage: JobStage.validatingJson,
        progress: JobStage.validatingJson.baseProgress,
        statusMessage: 'Validating output schema and repairing format...',
      );
      await _emit(currentJob);

      final quiz = JsonValidator.validateAndNormalizeQuiz(
        rawOutputBuffer.toString(),
        sourceDocumentId: currentJob.documentId,
      );

      // 8. Saving Quiz
      currentJob = currentJob.copyWith(
        stage: JobStage.savingQuiz,
        progress: JobStage.savingQuiz.baseProgress,
        statusMessage: 'Saving quiz to database...',
      );
      await _emit(currentJob);

      await quizRepo.saveQuiz(quiz);

      // 9. Completion
      currentJob = currentJob.copyWith(
        status: JobStatus.completed,
        stage: JobStage.complete,
        progress: 1.0,
        statusMessage: 'Quiz generated successfully with ${quiz.totalQuestions} questions!',
        resultQuizId: quiz.id,
        completedAt: DateTime.now(),
      );
      await _emit(currentJob);

      return quiz;
    } catch (e) {
      currentJob = currentJob.copyWith(
        status: _cancellationRequests.contains(currentJob.id)
            ? JobStatus.cancelled
            : JobStatus.failed,
        errorMessage: e.toString(),
        statusMessage: 'Generation stopped: $e',
        completedAt: DateTime.now(),
      );
      await _emit(currentJob);
      rethrow;
    } finally {
      _cancellationRequests.remove(currentJob.id);
    }
  }

  void _checkCancelled(String jobId) {
    if (_cancellationRequests.contains(jobId)) {
      throw StateError('Job $jobId was cancelled by user');
    }
  }

  Future<void> _emit(GenerationJob job) async {
    await jobRepo.saveJob(job);
    _jobUpdateController.add(job);
  }

  void dispose() {
    _jobUpdateController.close();
  }
}
