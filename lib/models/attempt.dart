import 'package:uuid/uuid.dart';

class UserAnswer {
  final String id;
  final String attemptId;
  final String questionId;
  final String? selectedOptionId;
  final String? textAnswer;
  final bool isCorrect;
  final int earnedPoints;
  final String feedback;

  UserAnswer({
    String? id,
    required this.attemptId,
    required this.questionId,
    this.selectedOptionId,
    this.textAnswer,
    required this.isCorrect,
    required this.earnedPoints,
    this.feedback = '',
  }) : id = id ?? const Uuid().v4();

  factory UserAnswer.fromJson(Map<String, dynamic> json) => UserAnswer(
    id: json['id'] as String?,
    attemptId: (json['attemptId'] ?? '').toString(),
    questionId: (json['questionId'] ?? '').toString(),
    selectedOptionId: json['selectedOptionId'] as String?,
    textAnswer: json['textAnswer'] as String?,
    isCorrect: json['isCorrect'] == true,
    earnedPoints: (json['earnedPoints'] as num?)?.toInt() ?? 0,
    feedback: (json['feedback'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'attemptId': attemptId,
    'questionId': questionId,
    'selectedOptionId': selectedOptionId,
    'textAnswer': textAnswer,
    'isCorrect': isCorrect,
    'earnedPoints': earnedPoints,
    'feedback': feedback,
  };
}

class QuizAttempt {
  final String id;
  final String quizId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int score;
  final int totalPossibleScore;
  final double percentage;
  final int timeSpentSeconds;
  final List<UserAnswer> answers;

  QuizAttempt({
    String? id,
    required this.quizId,
    DateTime? startedAt,
    this.completedAt,
    this.score = 0,
    this.totalPossibleScore = 0,
    this.percentage = 0.0,
    this.timeSpentSeconds = 0,
    List<UserAnswer>? answers,
  })  : id = id ?? const Uuid().v4(),
        startedAt = startedAt ?? DateTime.now(),
        answers = answers ?? const [];

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as List<dynamic>? ?? [];
    return QuizAttempt(
      id: json['id'] as String?,
      quizId: (json['quizId'] ?? '').toString(),
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalPossibleScore: (json['totalPossibleScore'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      timeSpentSeconds: (json['timeSpentSeconds'] as num?)?.toInt() ?? 0,
      answers: rawAnswers
          .map((a) => UserAnswer.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'quizId': quizId,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'score': score,
    'totalPossibleScore': totalPossibleScore,
    'percentage': percentage,
    'timeSpentSeconds': timeSpentSeconds,
    'answers': answers.map((a) => a.toJson()).toList(),
  };
}
