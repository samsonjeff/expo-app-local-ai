import 'package:uuid/uuid.dart';

enum QuestionType {
  multipleChoice('multiple_choice', 'Multiple Choice'),
  trueFalse('true_false', 'True or False'),
  fillInBlank('fill_in_blank', 'Fill in the Blank'),
  enumeration('enumeration', 'Enumeration'),
  essay('essay', 'Essay (AI Rubric Key)'),
  identification('identification', 'Identification');

  final String value;
  final String label;
  const QuestionType(this.value, this.label);

  static QuestionType fromString(String val) {
    return QuestionType.values.firstWhere(
      (e) => e.value == val || e.name == val,
      orElse: () => QuestionType.multipleChoice,
    );
  }
}

enum QuizDifficulty {
  easy('easy', 'Easy'),
  medium('medium', 'Medium'),
  hard('hard', 'Hard'),
  mixed('mixed', 'Mixed');

  final String value;
  final String label;
  const QuizDifficulty(this.value, this.label);

  static QuizDifficulty fromString(String val) {
    return QuizDifficulty.values.firstWhere(
      (e) => e.value == val || e.name == val,
      orElse: () => QuizDifficulty.medium,
    );
  }
}

enum AssessmentMode {
  quiz('quiz', 'Quiz'),
  exam('exam', 'Exam');

  final String value;
  final String label;
  const AssessmentMode(this.value, this.label);

  static AssessmentMode fromString(String val) {
    return AssessmentMode.values.firstWhere(
      (e) => e.value == val.toLowerCase() || e.name == val.toLowerCase(),
      orElse: () => AssessmentMode.quiz,
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

  QuizOption copyWith({
    String? id,
    String? optionText,
    bool? isCorrect,
    int? orderIndex,
  }) {
    return QuizOption(
      id: id ?? this.id,
      optionText: optionText ?? this.optionText,
      isCorrect: isCorrect ?? this.isCorrect,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

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

  QuizQuestion copyWith({
    String? id,
    String? questionText,
    QuestionType? questionType,
    int? points,
    String? explanation,
    int? orderIndex,
    List<QuizOption>? options,
    List<String>? acceptableAnswers,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      points: points ?? this.points,
      explanation: explanation ?? this.explanation,
      orderIndex: orderIndex ?? this.orderIndex,
      options: options ?? this.options,
      acceptableAnswers: acceptableAnswers ?? this.acceptableAnswers,
    );
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json, {int index = 0}) {
    final typeStr = (json['questionType'] ?? json['type'] ?? 'multiple_choice').toString();
    final parsedType = QuestionType.fromString(typeStr);

    final rawAcceptable = json['acceptableAnswers'] as List<dynamic>? ?? [];
    final parsedAcceptable = rawAcceptable.map((e) => e.toString().trim()).toList();

    final rawOptions = json['options'] as List<dynamic>? ?? [];
    final parsedOptions = <QuizOption>[];
    for (int i = 0; i < rawOptions.length; i++) {
      final optRaw = rawOptions[i];
      if (optRaw is Map<String, dynamic>) {
        parsedOptions.add(QuizOption.fromJson(optRaw, index: i));
      } else if (optRaw is String && optRaw.trim().isNotEmpty) {
        final optStr = optRaw.trim();
        parsedOptions.add(QuizOption(
          optionText: optStr,
          isCorrect: parsedAcceptable.any((a) => a.toLowerCase() == optStr.toLowerCase()),
          orderIndex: i,
        ));
      }
    }

    if (parsedType == QuestionType.trueFalse && parsedOptions.isEmpty) {
      final isTrue = parsedAcceptable.any((a) => a.toLowerCase() == 'true') ||
          (json['correctAnswer'] ?? json['answer'] ?? '').toString().toLowerCase().contains('true');
      parsedOptions.add(QuizOption(
        optionText: 'True',
        isCorrect: isTrue,
        orderIndex: 0,
      ));
      parsedOptions.add(QuizOption(
        optionText: 'False',
        isCorrect: !isTrue,
        orderIndex: 1,
      ));
    }

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
  final AssessmentMode assessmentMode;
  final int passingScore; // 50 to 100 percentage
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
    this.assessmentMode = AssessmentMode.quiz,
    this.passingScore = 70,
    this.sourceDocumentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<QuizQuestion>? questions,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        questions = questions != null ? deduplicateQuestions(questions) : const [];

  int get totalQuestions => questions.length;
  int get totalPoints => questions.fold(0, (sum, q) => sum + q.points);

  /// Normalizes question text for robust uniqueness and idempotency checks.
  static String normalizeText(String text) {
    var s = text.trim().toLowerCase();
    // Strip leading question numbers e.g. "1.", "1)", "q1:", "question 1:", etc.
    s = s.replaceAll(RegExp(r'^(?:q(?:uestion)?\s*\d+[\s.:)\-]+|\d+[\s.:)\-]+)\s*'), '');
    // Collapse any sequence of whitespace or newlines into a single space
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Strip trailing punctuation like ?, !, .
    s = s.replaceAll(RegExp(r'[?.!]+$'), '').trim();
    return s;
  }

  /// Deduplicates options within a question by normalized optionText.
  static List<QuizOption> deduplicateOptions(List<QuizOption> options) {
    if (options.isEmpty) return const [];
    final seen = <String>{};
    final unique = <QuizOption>[];
    for (final opt in options) {
      final normalized = opt.optionText.trim().toLowerCase();
      if (normalized.isNotEmpty && seen.contains(normalized)) {
        continue;
      }
      if (normalized.isNotEmpty) seen.add(normalized);
      unique.add(opt.copyWith(orderIndex: unique.length));
    }
    return unique;
  }

  /// Deduplicates questions preserving original sequence, re-indexing orderIndex,
  /// and guaranteeing no question is repeated twice.
  static List<QuizQuestion> deduplicateQuestions(List<QuizQuestion> questions) {
    if (questions.isEmpty) return const [];
    final seenTexts = <String>{};
    final seenIds = <String>{};
    final unique = <QuizQuestion>[];

    for (final q in questions) {
      final normalized = normalizeText(q.questionText);
      final id = q.id;

      // Skip duplicate IDs or duplicate normalized question texts
      if (seenIds.contains(id) || (normalized.isNotEmpty && seenTexts.contains(normalized))) {
        continue;
      }

      if (id.isNotEmpty) seenIds.add(id);
      if (normalized.isNotEmpty) seenTexts.add(normalized);

      unique.add(q.copyWith(
        orderIndex: unique.length,
        options: deduplicateOptions(q.options),
      ));
    }

    return unique;
  }

  Quiz copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    QuizDifficulty? difficulty,
    AssessmentMode? assessmentMode,
    int? passingScore,
    String? sourceDocumentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<QuizQuestion>? questions,
  }) {
    return Quiz(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      assessmentMode: assessmentMode ?? this.assessmentMode,
      passingScore: passingScore ?? this.passingScore,
      sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      questions: questions != null ? deduplicateQuestions(questions) : this.questions,
    );
  }

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
      assessmentMode: AssessmentMode.fromString((json['assessmentMode'] ?? json['assessment_mode'] ?? 'quiz').toString()),
      passingScore: (json['passingScore'] ?? json['passing_score'] as num?)?.toInt() ?? 70,
      sourceDocumentId: json['sourceDocumentId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      questions: deduplicateQuestions(parsedQuestions),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'difficulty': difficulty.value,
    'assessmentMode': assessmentMode.value,
    'passingScore': passingScore,
    'sourceDocumentId': sourceDocumentId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'questions': questions.map((q) => q.toJson()).toList(),
  };
}
