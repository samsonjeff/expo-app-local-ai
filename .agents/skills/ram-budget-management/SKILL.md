---
name: ram-budget-management
description: >-
  Use this skill when designing, testing, configuring, or optimizing AI inference, document processing, and background services for mobile devices constrained to 4GB to 8GB of physical RAM. Enforces hardware-aware model selection, strict memory lifecycle unloading, context window caps, Dart Isolate boundary hygiene, and OS low-memory callbacks (onTrimMemory) to guarantee zero Out-Of-Memory (OOM) crashes.
---

# 4GB–8GB RAM Budget & Memory Management Skill

This skill governs all aspects of memory safety, RAM profiling, hardware tier classification, and inference constraints for the **Flutter Local AI Quiz App** running on client devices with **4GB to 8GB of RAM** (primarily Android devices).

---

## 🎯 Target Hardware Realities & Budget Breakdown

Mobile operating systems enforce strict limits on resident application memory. On Android:
- A device with **4GB total RAM** typically leaves only **1.2GB–1.8GB** of usable RAM for the foreground app after OS services and background apps.
- A device with **6GB–8GB total RAM** provides **2.5GB–4.5GB** of usable RAM.
- Exceeding the Low Memory Killer (LMK) threshold triggers an immediate, uncatchable `SIGKILL` (Out-Of-Memory / OOM).

### RAM Budgets by Hardware Tier

| Hardware Tier | Total Device RAM | Usable App Budget | Quantized Model | Model RAM Footprint | Context RAM (KV Cache) | Dart & Flutter Overhead | Safety Margin |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Low Tier** | 4GB | ~1.5 GB | **Qwen 1.7B** (Q4_K_M) | ~1.25 GB | ~250 MB (at 4,096 ctx) | ~120 MB | ~150 MB buffer |
| **High Tier** | 6GB – 8GB+ | ~3.5 GB | **Phi-4-mini 3.8B** (Q4_K_M) | ~2.40 GB | ~550 MB (at 8,192 ctx) | ~180 MB | ~400 MB buffer |

---

## 🛡️ Non-Negotiable Memory Rules

### 1. The Strict Unload Rule (Never Resident in Background)
- **Zero Idle Weights**: GGUF model weights must **NEVER** remain loaded into RAM when no generation is active.
- **Always Wrap in Try/Finally**:
  ```dart
  await modelLifecycleManager.executeWithModel(
    modelPath: path,
    contextSize: profile.recommendedContextSize,
    threads: profile.recommendedThreads,
    action: () async {
      // Execute inference job
    },
  ); // Automatically unloads in finally block
  ```
- Any code path that loads weights outside of `ModelLifecycleManager` or fails to unload on exception is a critical defect.

### 2. Context Window & KV Cache Hard Caps
The KV cache scales linearly with context length and batch size:
- **4GB Tier**: Cap context window at `4096` tokens. Do not attempt 8k or 16k context on 4GB devices.
- **6GB–8GB Tier**: Cap context window at `8192` tokens.
- **Batch Size (`n_batch`)**: Never exceed `256` or `512` during prompt evaluation on mobile devices to prevent momentary RAM spikes.

### 3. CPU Core & Thread Allotment
- **4GB Tier**: Default to `threads: 2` (or max `threads: 4` if >4 big cores exist) to avoid thermal throttling and thread stack memory explosion.
- **6GB–8GB Tier**: Default to `threads: 4`.
- Enforce `n_gpu_layers: 0` unless dedicated Vulkan/OpenCL unified memory is explicitly verified.

### 4. Dart Isolate Memory Boundaries
- When parsing documents (PDF, DOCX) or chunking text, run in ephemeral worker isolates (`Isolate.run` or `compute`).
- **Never transfer giant raw strings or complete binary buffers**: Pass file paths rather than byte arrays across isolate boundaries where possible.
- Avoid duplicate string copies in memory during prompt construction. Clean intermediate text buffers immediately.

### 5. OS Low-Memory (`onTrimMemory`) Handling
- Register callbacks for Android `ComponentCallbacks2`:
  - `TRIM_MEMORY_RUNNING_CRITICAL` / `TRIM_MEMORY_COMPLETE`: Immediately abort active non-essential background caches and trigger `handleLowMemoryWarning()`.
  - If generation is mid-token, notify the `JobQueueManager` to checkpoint progress at the current chunk and safely terminate the native session.

---

## 🔍 Validation Checklist for Code Reviews

When reviewing or generating backend/inference code, verify:
- [ ] Is `RamDetector.detectProfile()` used to select the model and context size?
- [ ] Is the 4GB device guarded against loading 3B+ models?
- [ ] Is `isModelLoaded` verified to return `false` once generation completes?
- [ ] Are document parsing tasks performed in background isolates with closed file handles?
- [ ] Does `hasSufficientRamForInference` check (`availableRamMb >= 1200`) pass before initiating a download or load operation?
