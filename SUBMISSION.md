# AppBuildersPH Hackathon 2026 - Local AI Submission

## 📋 The Project

- **Project Name**:
  **MaQui** (Offline Local AI Quiz & Reviewer)

- **Short Description**:
  MaQui is a 100% offline, on-device AI-powered assessment and active-recall study companion for students and teachers. It ingests lecture notes and presentation slides (PDF, PPTX, DOCX, TXT) and autonomously generates curriculum-aligned mock examinations (Multiple Choice, True/False, Identification, and Essay) along with spaced-repetition flashcards (SRS)—running entirely on local device hardware with zero cloud latency, zero API costs, and zero data telemetry.

- **Team Members**:
  - Rochelle
  - Sedrick
  - Jeff Samson

- **Public GitHub Repository**:
  [https://github.com/samsonjeff/expo-app-local-ai](https://github.com/samsonjeff/expo-app-local-ai)  
  *(Branch: `polishing/sedrick` / `main`)*

---

## 🎥 The Proof

- **Demo Video**:
  `[Insert your Google Drive / YouTube / Loom link here]`

- **X / LinkedIn Video URL**:
  `[Insert your X (Twitter) or LinkedIn post URL here]`

- **What Runs Locally**:
  1. **Document Ingestion & Chunking**: Multi-format document text extraction (PDF via `syncfusion_flutter_pdf`, PowerPoint PPTX / Word DOCX via archive & XML stream parsing) running in dedicated Dart background Isolates.
  2. **LLM Inference**: On-device quantized GGUF neural network execution (e.g., Qwen 2.5 1.5B / Phi-4-mini / Llama 3.2 3B) running through `llama.cpp` native C++ bindings via `dart:ffi`.
  3. **JSON Schema Repair & Validation**: Real-time streaming token validation and deterministic syntax repair for structured question-answer outputs.
  4. **Assessment & Grading Engine**: Instant offline evaluation, student answer comparison, AI conceptual rationale generation, and rubrics.
  5. **Flashcard Spaced Repetition (SRS)**: Local Leitner/SM-2 spaced repetition memory algorithm and review scheduling.
  6. **Local Database & Sandboxing**: Type-safe SQLite relational database (`sqflite` + `drift`) for storing quizzes, question banks, study attempts, and deck states.
  7. **Export & Print Formatting**: Offline generation and sharing of printable Student Exam Papers and Teacher Answer Keys with rubrics (`pdf` & `printing`).

- **What Requires Internet**:
  - **Only One-Time Model Weight Download** (fetching the quantized GGUF weights to device storage on initial setup from Hugging Face).
  - Once the model file is on the device, the app requires **0 bytes of internet connectivity** and operates flawlessly in Airplane Mode (Wi-Fi and Cellular disabled).

---

## 🔍 The Disclosures

- **Models Used**:
  - **Primary (4GB RAM tier)**: `Qwen2.5-1.5B-Instruct-Q4_K_M.gguf` (capped to 4096 context tokens for guaranteed zero-OOM execution on budget smartphones).
  - **Secondary (6GB–8GB RAM tier)**: `Phi-4-mini-Instruct-Q4_K_M.gguf` / `Llama-3.2-3B-Instruct-Q4_K_M.gguf` (up to 8192 context window).
  - **Dual-Mode Mock Fallback Engine**: Deterministic fallback engine for instant development and testing across platforms without native C++ runtimes.

- **Technologies & Frameworks**:
  - **Mobile Framework**: Flutter (Dart 3.x), targeting mobile-first Android/iOS architectures.
  - **State Management**: `flutter_riverpod` (Riverpod 2.x).
  - **Inference Runtime**: `llama.cpp` compiled via CMake/Android NDK, bound via `dart:ffi`.
  - **Database**: SQLite via `sqflite` & `drift`.
  - **Document Parsing**: `syncfusion_flutter_pdf`, `archive`, `xml`.
  - **Background Persistence**: `flutter_foreground_task`, `shared_preferences`, `path_provider`.
  - **Exporting & Printing**: `pdf`, `printing`, `share_plus`.
  - **Motion & UI**: Material Design 3, `google_fonts` (Inter), custom isolate-safe tactile micro-interaction system (`TactilePressCard`, `FlipCard3D`, `AiPulseGlow`, `StaggeredEntranceItem`).

- **APIs and Cloud Services**:
  - **None**. Zero external AI APIs used (no OpenAI, no Anthropic, no Google Gemini API, no cloud servers, no proxy backends). Only standard public CDN (Hugging Face) for downloading public GGUF weights during setup.

- **Existing Code and Assets**:
  - Open-source Flutter packages from pub.dev.
  - Open-source `llama.cpp` engine.
  - Custom MaQui application logo and branding assets (`assets/MaQui-light-mode.png`, `assets/MaQui-dark-mode.png`).

- **AI Development Tools**:
  - Google Antigravity / Gemini IDE for architectural pair-programming, test authoring, and UI polish.

---

## 💡 Key Question: Why does this product benefit from running AI locally?

### 1. 100% Student & Institutional Data Privacy (Zero Cloud Leakage)
In educational settings, study materials frequently consist of unreleased teacher syllabi, unpublished research notes, internal lecture slides, and confidential midterm review items. Cloud-hosted LLMs transmit every word over third-party servers, where it can be logged, monetized, or ingested into training corpora. MaQui processes every single token in the local sandboxed memory of the student's personal phone, making compliance with privacy laws (such as GDPR and the Philippine Data Privacy Act) absolute by design.

### 2. Zero Recurring API Costs for Students and Public Schools
Cloud AI applications impose ongoing operational costs: every 30-question quiz generated from a 15-page slide deck costs money per token on proprietary cloud APIs. For public school students and budget-conscious universities across developing regions, subscriptions or credit limits create a digital divide. Running inference on-device democratizes access: once installed, generating 1,000 quizzes costs **₱0.00 / $0.00**.

### 3. Bulletproof Accessibility in Low-Connectivity & Classroom Environments
Internet connectivity across public transport, rural provinces, dormitories, and crowded campus Wi-Fi networks is notoriously unstable or expensive. Furthermore, educational institutions and testing centers frequently prohibit or restrict internet access in classrooms. Because MaQui operates entirely offline, students can study and generate fresh mock exams anywhere—whether riding a bus, studying during power blackouts, or reviewing in an airplane seat.

### 4. Deterministic Reliability Without Cloud Outages or Rate-Limits
Cloud LLM APIs are subject to server degradation, queueing delays, HTTP 429 rate limits, and breaking API schema changes right before exam week. MaQui provides instantaneous local execution with zero network roundtrip latency and zero external points of failure.

### 5. Exam Integrity Under Airplane Mode
When taking assessments or studying with active recall, educators can require students to toggle Airplane Mode on their devices. With MaQui, the AI tutor and quiz generator continue to work at peak capability while preventing students from browsing external cheat sheets or messaging classmates.
