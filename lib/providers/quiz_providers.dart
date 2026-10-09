import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../inference/llama_bridge.dart';
import '../inference/mock_llama_bridge.dart';
import '../inference/model_lifecycle_manager.dart';
import '../inference/ram_detector.dart';
import '../models/inference.dart';
import '../models/job.dart';
import '../models/quiz.dart';
import '../orchestration/job_queue_manager.dart';
import '../storage/database/attempt_repository.dart';
import '../storage/database/document_repository.dart';
import '../storage/database/job_repository.dart';
import '../storage/database/quiz_repository.dart';

// Repositories
final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return QuizRepository();
});

final attemptRepositoryProvider = Provider<AttemptRepository>((ref) {
  return AttemptRepository();
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository();
});

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository();
});

// Hardware Profile
final hardwareProfileProvider = FutureProvider<HardwareProfile>((ref) async {
  return await RamDetector.detectProfile();
});

// Inference Bridge (Default to MockLlamaBridge for robust test/dev simulation)
final llamaBridgeProvider = Provider<LlamaBridge>((ref) {
  return MockLlamaBridge();
});

final modelLifecycleManagerProvider = Provider<ModelLifecycleManager>((ref) {
  final bridge = ref.watch(llamaBridgeProvider);
  return ModelLifecycleManager(bridge: bridge);
});

// Job Queue Manager
final jobQueueManagerProvider = Provider<JobQueueManager>((ref) {
  final jobRepo = ref.watch(jobRepositoryProvider);
  final docRepo = ref.watch(documentRepositoryProvider);
  final quizRepo = ref.watch(quizRepositoryProvider);
  final lifecycle = ref.watch(modelLifecycleManagerProvider);

  final manager = JobQueueManager(
    jobRepo: jobRepo,
    docRepo: docRepo,
    quizRepo: quizRepo,
    lifecycleManager: lifecycle,
  );

  ref.onDispose(() => manager.dispose());
  return manager;
});

// All Quizzes State Notifier
class QuizzesNotifier extends AsyncNotifier<List<Quiz>> {
  @override
  Future<List<Quiz>> build() async {
    final repo = ref.watch(quizRepositoryProvider);
    return await repo.getAllQuizzes();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(quizRepositoryProvider);
      return await repo.getAllQuizzes();
    });
  }

  Future<void> deleteQuiz(String id) async {
    final repo = ref.read(quizRepositoryProvider);
    await repo.deleteQuiz(id);
    await refresh();
  }
}

final quizzesProvider = AsyncNotifierProvider<QuizzesNotifier, List<Quiz>>(() {
  return QuizzesNotifier();
});

// Job Stream Provider
final activeJobStreamProvider = StreamProvider<GenerationJob>((ref) {
  final queue = ref.watch(jobQueueManagerProvider);
  return queue.jobUpdates;
});
