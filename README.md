# Local AI Quiz App (Flutter Mobile)

An offline, on-device AI quiz generation and study application built with **Flutter**, **Riverpod**, and **llama.cpp**. Generates complete multiple-choice quizzes and study sets locally with zero internet connection required.

---

## 🚀 Current Status & Backend Progress (For Frontend Devs)

The core backend architecture, local database layer, orchestration pipeline, and on-device inference engines are **ready and fully tested**.

### ✅ Completed & Ready for Frontend Integration

1. **Dual-Mode AI Inference Engine**:
   - **Native Engine** ([`NativeFlutterLlamaBridge`](file:///d:/quiz-app-local-ai/lib/inference/native_flutter_llama_bridge.dart)): Powered by `flutter_llama` (`llama.cpp`) with GPU acceleration (Vulkan on Android, Metal on iOS/macOS).
   - **Dev / Simulation Engine** ([`MockLlamaBridge`](file:///d:/quiz-app-local-ai/lib/inference/mock_llama_bridge.dart)): Emulates realistic streaming tokens and responses so frontend developers can build screens and test complete generation flows without downloading heavy GGUF models or running on physical devices.
   - **Unified Provider** ([`llamaBridgeProvider`](file:///d:/quiz-app-local-ai/lib/providers/quiz_providers.dart)): Automatically uses the native engine on mobile targets and cleanly falls back to the mock engine in dev/tests.

2. **RAM-Aware Hardware Profiling (4GB–8GB Target Devices)**:
   - Detects total & available system RAM via [`RamDetector`](file:///d:/quiz-app-local-ai/lib/inference/ram_detector.dart).
   - **Low Tier (4GB devices)**: Enforces **Qwen 1.7B** (Q4_K_M) with context capped at 4,096 tokens to prevent Out-Of-Memory (OOM) kills.
   - **High Tier (6GB–8GB+ devices)**: Allows **Phi-4-mini 3.8B** (Q4_K_M) with context up to 8,192 tokens.
   - Strict model lifecycle management ([`ModelLifecycleManager`](file:///d:/quiz-app-local-ai/lib/inference/model_lifecycle_manager.dart)) unloads model weights from RAM immediately in `finally` blocks upon completion or errors.

3. **Database & Storage Layer (SQLite / Drift)**:
   - Type-safe SQLite persistence for:
     - Quizzes, Questions, and Options (`QuizRepository`)
     - User attempts, answers, and scores (`AttemptRepository`)
     - Uploaded source documents (`DocumentRepository`)
     - Resumable background jobs (`JobRepository`)
   - Cascading deletes configured (`ON DELETE CASCADE`).

4. **Pipeline & Orchestration**:
   - [`JobQueueManager`](file:///d:/quiz-app-local-ai/lib/orchestration/job_queue_manager.dart): Handles asynchronous quiz creation with chunk-level progress milestones (`PARSING_DOCUMENT`, `CHUNKING_TEXT`, `LOADING_MODEL`, `GENERATING_INFERENCE`, `VALIDATING_JSON`, `COMPLETE`).
   - [`JsonValidator`](file:///d:/quiz-app-local-ai/lib/orchestration/json_validator.dart): Resilient JSON auto-repair that strips code fences and corrects common small-model formatting glitches.
   - Document chunking and parsing pipelines ready for background Dart Isolates.

5. **Model Downloader**:
   - [`ModelDownloader`](file:///d:/quiz-app-local-ai/lib/storage/model_downloader.dart): Supports resumable download streams with SHA-256 integrity verification.

---

## 🎨 Frontend Architecture & How to Hook In

### State Management: Riverpod
All backend services are exposed via clean Riverpod providers in [`lib/providers/quiz_providers.dart`](file:///d:/quiz-app-local-ai/lib/providers/quiz_providers.dart):

```dart
// 1. Observe all saved quizzes (auto-updates on creation/deletion)
final quizzes = ref.watch(quizzesProvider);

// 2. Watch active job progress during quiz generation
final activeJob = ref.watch(activeJobStreamProvider);

// 3. Trigger quiz generation from a topic or document
final jobManager = ref.read(jobQueueManagerProvider);
await jobManager.createJobFromTopic(
  title: 'Biology 101',
  topic: 'Cellular Respiration and Photosynthesis',
  modelPath: 'dummy_or_real_path.gguf',
);

// 4. Access repositories directly
final quizRepo = ref.read(quizRepositoryProvider);
final attemptRepo = ref.read(attemptRepositoryProvider);
```

---

## 📱 Screens Status

| Screen | File Path | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Home / Dashboard** | `lib/presentation/screens/home_screen.dart` | 🟡 Basic UI | Has quiz list & quick generation dialog. Needs polish, empty state illustrations, and category filtering. |
| **Quiz Play Screen** | `lib/presentation/screens/quiz_play_screen.dart` | 🟡 Functional | Timer, option selector, and score recording working. Needs animations & UI polish. |
| **Quiz Results** | `lib/presentation/screens/results_screen.dart` | 🟡 Functional | Summary score and retry/back actions. |
| **Document Upload Flow** | *To be built* | 🔴 Pending | File picker for PDF/DOCX with chunk preview and isolate parsing progress. |
| **Model Downloader Screen** | *To be built* | 🔴 Pending | UI to browse models (Qwen 1.7B / Phi-4), view device RAM badge, and monitor download progress. |
| **Flashcards / SRS Review** | *To be built* | 🔴 Pending | Card flip interface with SM-2 spaced repetition grading. |

---

## 🛠️ Development & Running Commands

Since the Flutter SDK is kept locally within the project folder:

```bash
# Run static analysis
.\flutter_sdk\bin\flutter.bat analyze lib test

# Run unit & widget tests
.\flutter_sdk\bin\flutter.bat test

# Run on Edge / Chrome (using Mock Engine)
.\flutter_sdk\bin\flutter.bat run -d edge

# Run on connected Android device
.\flutter_sdk\bin\flutter.bat run -d android
```