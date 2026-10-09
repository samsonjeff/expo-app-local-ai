import 'package:uuid/uuid.dart';

enum JobStatus {
  pending('pending'),
  running('running'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  final String value;
  const JobStatus(this.value);
}

enum JobStage {
  idle('Idle', 0.0),
  parsingDocument('Parsing Document', 0.10),
  chunkingText('Chunking Text', 0.20),
  loadingModel('Loading Model into RAM', 0.35),
  generatingInference('Generating Quiz Questions', 0.50),
  unloadingModel('Freeing Model RAM', 0.88),
  validatingJson('Validating & Repairing Output', 0.92),
  savingQuiz('Saving Quiz', 0.97),
  complete('Completed', 1.0);

  final String label;
  final double baseProgress;
  const JobStage(this.label, this.baseProgress);
}

class GenerationJob {
  final String id;
  final String? documentId;
  final String? topic;
  final int questionCount;
  final String difficulty;
  final List<String> questionTypes;
  final JobStatus status;
  final JobStage stage;
  final double progress;
  final String statusMessage;
  final String? resultQuizId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  GenerationJob({
    String? id,
    this.documentId,
    this.topic,
    this.questionCount = 10,
    this.difficulty = 'medium',
    this.questionTypes = const ['multiple_choice'],
    this.status = JobStatus.pending,
    this.stage = JobStage.idle,
    this.progress = 0.0,
    this.statusMessage = 'Job initialized',
    this.resultQuizId,
    this.errorMessage,
    DateTime? createdAt,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  GenerationJob copyWith({
    JobStatus? status,
    JobStage? stage,
    double? progress,
    String? statusMessage,
    String? resultQuizId,
    String? errorMessage,
    DateTime? completedAt,
  }) {
    return GenerationJob(
      id: id,
      documentId: documentId,
      topic: topic,
      questionCount: questionCount,
      difficulty: difficulty,
      questionTypes: questionTypes,
      status: status ?? this.status,
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      resultQuizId: resultQuizId ?? this.resultQuizId,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'topic': topic,
    'questionCount': questionCount,
    'difficulty': difficulty,
    'questionTypes': questionTypes,
    'status': status.value,
    'stage': stage.name,
    'progress': progress,
    'statusMessage': statusMessage,
    'resultQuizId': resultQuizId,
    'errorMessage': errorMessage,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory GenerationJob.fromJson(Map<String, dynamic> json) {
    return GenerationJob(
      id: json['id'] as String?,
      documentId: json['documentId'] as String?,
      topic: json['topic'] as String?,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 10,
      difficulty: (json['difficulty'] ?? 'medium').toString(),
      questionTypes: (json['questionTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['multiple_choice'],
      status: JobStatus.values.firstWhere(
        (s) => s.value == json['status'],
        orElse: () => JobStatus.pending,
      ),
      stage: JobStage.values.firstWhere(
        (st) => st.name == json['stage'],
        orElse: () => JobStage.idle,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      statusMessage: (json['statusMessage'] ?? '').toString(),
      resultQuizId: json['resultQuizId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
    );
  }
}
