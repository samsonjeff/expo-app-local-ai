import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../models/job.dart';
import 'app_database.dart';

class JobRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<void> saveJob(GenerationJob job) async {
    final db = await _db;
    final map = <String, dynamic>{
      'id': job.id,
      'document_id': job.documentId,
      'topic': job.topic,
      'question_count': job.questionCount,
      'difficulty': job.difficulty,
      'question_types_json': jsonEncode(job.questionTypes),
      'status': job.status.value,
      'stage': job.stage.name,
      'progress': job.progress,
      'status_message': job.statusMessage,
      'result_quiz_id': job.resultQuizId,
      'error_message': job.errorMessage,
      'created_at': job.createdAt.toIso8601String(),
      'completed_at': job.completedAt?.toIso8601String(),
    };

    try {
      map['assessment_mode'] = job.assessmentMode;
      map['passing_score'] = job.passingScore;
    } catch (_) {}

    await db.insert(
      'generation_jobs',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<GenerationJob?> getJobById(String id) async {
    final db = await _db;
    final rows = await db.query('generation_jobs', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<GenerationJob>> getAllJobs() async {
    final db = await _db;
    final rows = await db.query('generation_jobs', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  GenerationJob _fromRow(Map<String, dynamic> row) {
    final typesJson = row['question_types_json'] as String? ?? '[]';
    final typesList = (jsonDecode(typesJson) as List<dynamic>).map((e) => e.toString()).toList();

    return GenerationJob(
      id: row['id'] as String,
      documentId: row['document_id'] as String?,
      topic: row['topic'] as String?,
      questionCount: row['question_count'] as int? ?? 10,
      difficulty: row['difficulty'] as String? ?? 'medium',
      assessmentMode: (row['assessment_mode'] ?? 'quiz').toString(),
      passingScore: (row['passing_score'] as num?)?.toInt() ?? 70,
      questionTypes: typesList,
      status: JobStatus.values.firstWhere(
        (s) => s.value == row['status'],
        orElse: () => JobStatus.pending,
      ),
      stage: JobStage.values.firstWhere(
        (st) => st.name == row['stage'],
        orElse: () => JobStage.idle,
      ),
      progress: (row['progress'] as num).toDouble(),
      statusMessage: row['status_message'] as String? ?? '',
      resultQuizId: row['result_quiz_id'] as String?,
      errorMessage: row['error_message'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      completedAt: row['completed_at'] != null ? DateTime.parse(row['completed_at'] as String) : null,
    );
  }
}
