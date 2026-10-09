import 'package:uuid/uuid.dart';

enum QuestionType {
  multipleChoice('multiple_choice'),
  trueFalse('true_false'),
  fillInBlank('fill_in_blank'),
  enumeration('enumeration'),
  essay('essay'),
  identification('identification');

  final String value;
  const QuestionType(this.value);

  static QuestionType fromString(String val) {
    return QuestionType.values.firstWhere(
      (e) => e.value == val || e.name == val,
      orElse: () => QuestionType.multipleChoice,
    );
  }
}

enum QuizDifficulty {
  easy('easy'),
  medium('medium'),
  hard('hard'),
  mixed('mixed');

  final String value;
  const QuizDifficulty(this.value);

  static QuizDifficulty fromString(String val) {
    return QuizDifficulty.values.firstWhere(
      (e) => e.value == val || e.name == val,
      orElse: () => QuizDifficulty.medium,
    );
  }
}

class QuizOption {
  final String id;
  final String optionText;
  final bool isCorrect;
  final int orderIndex;

  QuizOption({
    String? id,
    required this.optionText,
    required this.isCorrect,
    this.orderIndex = 0,
  }) : id = id ?? const Uuid().v4();

  factory QuizOption.fromJson(Map<String, dynamic> json, {int index = 0}) {
    return QuizOption(
      id: json['id'] as String?,
      optionText: (json['optionText'] ?? json['text'] ?? '').toString().trim(),
      isCorrect: json['isCorrect'] == true,
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? index,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'optionText': optionText,
    'isCorrect': isCorrect,
    'orderIndex': orderIndex,
  };
}

class QuizQuestion {
  final String id;
  final String questionText;
  final QuestionType questionType;
  final int points;
  final String explanation;
  final int orderIndex;
  final List<QuizOption> options;
  final List<String> acceptableAnswers;

  QuizQuestion({
    String? id,
    required this.questionText,
    required this.questionType,
    this.points = 1,
    this.explanation = '',
    this.orderIndex = 0,
    List<QuizOption>? options,
    List<String>? acceptableAnswers,
  })  : id = id ?? const Uuid().v4(),
        options = options ?? const [],
        acceptableAnswers = acceptableAnswers ?? const [];

  factory QuizQuestion.fromJson(Map<String, dynamic> json, {int index = 0}) {
    final typeStr = (json['questionType'] ?? json['type'] ?? 'multiple_choice').toString();
    final parsedType = QuestionType.fromString(typeStr);

    final rawOptions = json['options'] as List<dynamic>? ?? [];
    final parsedOptions = <QuizOption>[];
    for (int i = 0; i < rawOptions.length; i++) {
      if (rawOptions[i] is Map<String, dynamic>) {
        parsedOptions.add(QuizOption.fromJson(rawOptions[i] as Map<String, dynamic>, index: i));
      }
    }

    final rawAcceptable = json['acceptableAnswers'] as List<dynamic>? ?? [];
    final parsedAcceptable = rawAcceptable.map((e) => e.toString().trim()).toList();

    return QuizQuestion(
      id: json['id'] as String?,
      questionText: (json['questionText'] ?? json['question'] ?? '').toString().trim(),
      questionType: parsedType,
      points: (json['points'] as num?)?.toInt() ?? 1,
      explanation: (json['explanation'] ?? '').toString().trim(),
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? index,
      options: parsedOptions,
      acceptableAnswers: parsedAcceptable,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'questionText': questionText,
    'questionType': questionType.value,
    'points': points,
    'explanation': explanation,
    'orderIndex': orderIndex,
    'options': options.map((o) => o.toJson()).toList(),
    'acceptableAnswers': acceptableAnswers,
  };
}

class Quiz {
  final String id;
  final String title;
  final String description;
  final String category;
  final QuizDifficulty difficulty;
  final String? sourceDocumentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<QuizQuestion> questions;

  Quiz({
    String? id,
    required this.title,
    this.description = '',
    this.category = 'General',
    this.difficulty = QuizDifficulty.medium,
    this.sourceDocumentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<QuizQuestion>? questions,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        questions = questions ?? const [];

  int get totalQuestions => questions.length;
  int get totalPoints => questions.fold(0, (sum, q) => sum + q.points);

  factory Quiz.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List<dynamic>? ?? [];
    final parsedQuestions = <QuizQuestion>[];
    for (int i = 0; i < rawQuestions.length; i++) {
      if (rawQuestions[i] is Map<String, dynamic>) {
        parsedQuestions.add(QuizQuestion.fromJson(rawQuestions[i] as Map<String, dynamic>, index: i));
      }
    }

    return Quiz(
      id: json['id'] as String?,
      title: (json['title'] ?? 'Generated Quiz').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      category: (json['category'] ?? 'General').toString().trim(),
      difficulty: QuizDifficulty.fromString((json['difficulty'] ?? 'medium').toString()),
      sourceDocumentId: json['sourceDocumentId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      questions: parsedQuestions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'difficulty': difficulty.value,
    'sourceDocumentId': sourceDocumentId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'questions': questions.map((q) => q.toJson()).toList(),
  };
}
