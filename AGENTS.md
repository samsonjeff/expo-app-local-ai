# Flutter / Dart Architecture & Engineering Rules

This is a Flutter mobile application targeting offline, on-device AI quiz generation and study tools. Prioritize mobile-first patterns, RAM safety, asynchronous execution in Dart Isolates, and cross-platform compatibility.

## Tech Stack & Core Libraries

- **Framework**: Flutter (stable, Android-first)
- **State Management**: `flutter_riverpod` (Riverpod 2.x+)
- **Local AI Engine**: `llama.cpp` compiled via CMake/NDK and invoked via `dart:ffi` (or `flutter_llama`) on dedicated background threads
- **Database**: `sqflite` + `drift` for type-safe SQLite access
- **Document Parsing**: `syncfusion_flutter_pdf` (PDF), `archive` + XML parsing (DOCX/PPTX)
- **Background Persistence**: `flutter_foreground_task` (foreground service to prevent OS kills during long generation tasks)
- **Sharing & Export**: `share_plus`, `path_provider`, `printing`

## Architecture Layers

1. **Presentation Layer (`lib/features/` or `lib/ui/`)**:
   - Flutter widgets, Riverpod providers/notifiers, theme, and UI flows (Upload, Config, Streaming Progress, Review/Edit, Mock Exam, Flashcards, Results).
   - UI thread must remain buttery 60fps at all times.
2. **Orchestration Layer (`lib/orchestration/` or `lib/core/pipeline/`)**:
   - Prompt templates, JSON schema validation, auto-repair.
   - Persistent `JobQueue` (SQLite-backed, chunk-level resumable).
   - Document chunking pipeline executed in background **Dart Isolates**.
   - Hardware detection & RAM tier selection (`device_info_plus` / system memory).
3. **AI Inference Layer (`lib/inference/`)**:
   - Native bindings via `dart:ffi`.
   - Streaming tokens via callbacks directly into Dart isolates.
   - Memory lifecycle control: strict unload on job completion or low-memory signals (`onTrimMemory`).
4. **Storage Layer (`lib/storage/` or `lib/data/`)**:
   - Drift / SQLite database (quizzes, questions, attempts, SRS state).
   - Local filesystem sandboxing (`models/`, `documents/`, `exports/`).

## Essential Commands

```bash
flutter pub get                                       # install/sync dependencies
flutter analyze                                       # static analysis / linting
flutter test                                          # run tests
dart run build_runner build --delete-conflicting-outputs # code generation (Drift, Riverpod, etc.)
flutter run                                           # launch app in debug mode
```

Run `flutter analyze` and `flutter test` before declaring tasks complete.

## Memory & Native Safety Rules

- **Zero UI-Thread Parsing**: Never parse large PDFs or validate large JSON schemas on the main UI isolate. Spawn a worker isolate (`Isolate.run` or `compute`).
- **RAM Lifecycle**: On 4GB–6GB devices, ensure model weights are unloaded immediately after generation finishes or fails.
- **Dual-Mode Bridge**: Provide a mock fallback engine for fast UI development on machines or platforms lacking native C++ GGUF runtimes.
