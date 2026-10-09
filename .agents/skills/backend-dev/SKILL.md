---
name: backend-dev
description: >-
  Use this skill when developing, refactoring, testing, maintaining, or architecting the backend systems of the Flutter Local AI Quiz App. Strictly isolates backend tasks (AI inference via FFI, Drift/SQLite database, job queues, document chunking, prompt engineering, memory management in Dart Isolates) from Flutter UI widgets and screen components.
---

# Local AI Quiz App - Flutter Backend Engineering Skill

This skill governs the development and maintenance of the offline backend, local AI inference engine, database, and orchestration pipelines for the **Flutter Local AI Quiz App**.

## 🎯 Role & Boundary Definition

- **Focus Exclusively On**:
  - AI Inference Engine & Hardware Management (`lib/inference/`)
  - Application Pipeline, Job Queue & Document Processing (`lib/orchestration/`)
  - SQLite / Drift Database, Repositories & Filesystem Sandbox (`lib/storage/`)
  - Domain Data Models, JSON serialization & schemas (`lib/models/`)
  - Backend Unit Tests & Benchmarks (`test/`)
  - Background Service Orchestration (`lib/services/foreground_service.dart` - planned)
- **Strictly Avoid**:
  - Creating or modifying UI widgets, screen layouts (`lib/presentation/screens/`), widget themes, navigation routers, or design tokens. The frontend UI is managed separately.
  - Adding UI-thread blocking computations. Heavy processing must always be delegated to Dart worker isolates.

---

## 🏛️ System Architecture

The backend follows a 4-layer modular decoupled architecture:

```
[Presentation Layer & Riverpod Providers] (Consumers)
               │
               ▼
┌────────────────────────────────────────────────────────┐
│ Layer 2: Application & Orchestration (Dart Isolates)   │
│ - JobQueueManager (SQLite-backed, resumable at chunk)  │
│ - DocumentParser & DocumentChunker (PDF, DOCX in worker)│
│ - PromptBuilder & PromptTemplates (strict JSON prompts)│
│ - JSONValidator (auto-repair, schema validation)       │
└──────────────────────────┬─────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
┌──────────────────────────────────┐ ┌──────────────────────────────────┐
│ Layer 3: AI Inference Layer      │ │ Layer 4: Storage & Filesystem    │
│ - LlamaBridge (abstract contract)│ │ - Drift / SQLite Database        │
│ - MockLlamaBridge (dev/test sim) │ │   - AppDatabase (schema/tables)  │
│ - LlamaFfiBridge (planned C++)   │ │   - Repositories in database/    │
│ - ModelLifecycleManager (RAM GC) │ │ - FileStorageManager (sandbox)   │
│ - RAMDetector (Hardware tiering) │ │ - ModelDownloader (planned)      │
│ - ModelCatalog (Phi-4, Qwen3)    │ │                                  │
└──────────────────────────────────┘ └──────────────────────────────────┘
```

---

## 📋 Core Engineering Rules

### 1. Memory Safety & RAM Lifecycle (Crucial for Mobile)
Mobile hardware (especially 4GB–6GB devices) has strict memory limits. Any unreleased GGUF context will trigger an OS Out-Of-Memory (OOM) kill.
- **Always Unload Models**: Ensure `ModelLifecycleManager.unloadModel()` is called in a `finally` block after inference finishes or fails.
- **Never Persist Model Context in RAM**: The model should only reside in active memory while generation is running.
- **Hardware-Aware Tiers**:
  - `high` (6GB–8GB+ RAM): Phi-4-mini (3.8B Q4_K_M)
  - `low` (4GB RAM): Qwen3 (1.7B Q4_K_M)
- **Native CPU Inference Parameters**: Always enforce `n_threads: 4`, `n_gpu_layers: 0`, and context window caps (default 4096-8192 tokens).

### 2. Dual-Mode Inference Bridge
The codebase supports both native on-device inference and development simulation:
- Native builds execute real GGUF weights via `llama.cpp` through `dart:ffi`.
- When native C++ libraries are unavailable (e.g. unit tests, desktop simulators without precompiled binaries), `LlamaBridge` seamlessly delegates to `MockLlamaBridge` yielding realistic streamed tokens.
- **Never remove the fallback engine**, as frontend and CI developers depend on it to build and test UI flows without compiling native C++.

### 3. Drift & SQLite Database Guidelines
- **Foreign Keys**: Enforce foreign key constraints on connection setup.
- **Cascading Deletes**: `ON DELETE CASCADE` must be configured on relationships so deleting a quiz removes its associated questions, options, and attempt records cleanly.
- **Repository Isolation**: All SQL interactions must be contained within `lib/storage/database/` (`QuizRepository`, `AttemptRepository`, `DocumentRepository`, `JobRepository`).

### 4. Job Queue & Asynchronous Progress
Quiz generation is computationally heavy and must never freeze the UI thread:
- Heavy parsing and JSON validation must run in Dart Isolates (`Isolate.run` or dedicated workers).
- Generation is managed through `JobQueueManager`.
- Each job must report standard progress milestones:
  - `10%` - `PARSING_DOCUMENT`
  - `20%` - `CHUNKING_TEXT`
  - `35%` - `LOADING_MODEL`
  - `50%–85%` - `GENERATING_INFERENCE` (with streaming token count)
  - `88%` - Unloading model from RAM
  - `92%` - `VALIDATING_JSON`
  - `97%` - `SAVING_QUIZ`
  - `100%` - `COMPLETE`
- Honor job cancellation requests (`cancelRequested`).

### 5. Resilient JSON Parsing & Auto-Repair
Small LLMs often produce slight formatting flaws (markdown ticks, unescaped quotes, trailing commas, or missing brackets):
- Raw LLM output must **always** pass through `JsonValidator.validateAndNormalizeQuiz()`.
- The validator strips markdown code fences, cleans control characters, repairs unbalanced braces, and ensures valid question structures.

### 6. Filesystem Sandboxing
- All files (models, uploaded documents, export files) must be managed within sandboxed directories provided by `FileStorageManager` (`models/`, `documents/`, `exports/`).
