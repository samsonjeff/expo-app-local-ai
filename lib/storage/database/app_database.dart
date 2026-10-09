import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String dbName = 'quiz_app_local_ai.db';
  static const int dbVersion = 1;

  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Allow setting a custom database instance (e.g., in-memory for testing)
  static void setMockDatabase(Database db) {
    _database = db;
  }

  static Future<Database> _initDatabase() async {
    String path;
    if (kIsWeb) {
      path = dbName;
    } else {
      final databasesPath = await getDatabasesPath();
      path = p.join(databasesPath, dbName);
    }

    return await openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    // Documents
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        type TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL,
        character_count INTEGER DEFAULT 0,
        estimated_tokens INTEGER DEFAULT 0,
        uploaded_at TEXT NOT NULL
      );
    ''');

    // Quizzes
    await db.execute('''
      CREATE TABLE quizzes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        category TEXT DEFAULT 'General',
        difficulty TEXT DEFAULT 'medium',
        source_document_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (source_document_id) REFERENCES documents (id) ON DELETE SET NULL
      );
    ''');

    // Questions
    await db.execute('''
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        question_text TEXT NOT NULL,
        question_type TEXT NOT NULL,
        points INTEGER DEFAULT 1,
        explanation TEXT DEFAULT '',
        order_index INTEGER DEFAULT 0,
        acceptable_answers_json TEXT DEFAULT '[]',
        FOREIGN KEY (quiz_id) REFERENCES quizzes (id) ON DELETE CASCADE
      );
    ''');

    // Options
    await db.execute('''
      CREATE TABLE options (
        id TEXT PRIMARY KEY,
        question_id TEXT NOT NULL,
        option_text TEXT NOT NULL,
        is_correct INTEGER NOT NULL,
        order_index INTEGER DEFAULT 0,
        FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
      );
    ''');

    // Quiz Attempts
    await db.execute('''
      CREATE TABLE quiz_attempts (
        id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        score INTEGER DEFAULT 0,
        total_possible_score INTEGER DEFAULT 0,
        percentage REAL DEFAULT 0.0,
        time_spent_seconds INTEGER DEFAULT 0,
        FOREIGN KEY (quiz_id) REFERENCES quizzes (id) ON DELETE CASCADE
      );
    ''');

    // User Answers
    await db.execute('''
      CREATE TABLE user_answers (
        id TEXT PRIMARY KEY,
        attempt_id TEXT NOT NULL,
        question_id TEXT NOT NULL,
        selected_option_id TEXT,
        text_answer TEXT,
        is_correct INTEGER NOT NULL,
        earned_points INTEGER DEFAULT 0,
        feedback TEXT DEFAULT '',
        FOREIGN KEY (attempt_id) REFERENCES quiz_attempts (id) ON DELETE CASCADE,
        FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
      );
    ''');

    // Generation Jobs
    await db.execute('''
      CREATE TABLE generation_jobs (
        id TEXT PRIMARY KEY,
        document_id TEXT,
        topic TEXT,
        question_count INTEGER DEFAULT 10,
        difficulty TEXT DEFAULT 'medium',
        question_types_json TEXT DEFAULT '[]',
        status TEXT NOT NULL,
        stage TEXT NOT NULL,
        progress REAL DEFAULT 0.0,
        status_message TEXT DEFAULT '',
        result_quiz_id TEXT,
        error_message TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT
      );
    ''');
  }
}
