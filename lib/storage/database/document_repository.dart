import 'package:sqflite/sqflite.dart';
import '../../models/document.dart';
import 'app_database.dart';

class DocumentRepository {
  Future<Database> get _db => AppDatabase.database;

  Future<void> saveDocument(DocumentMetadata doc) async {
    final db = await _db;
    await db.insert(
      'documents',
      {
        'id': doc.id,
        'file_name': doc.fileName,
        'file_path': doc.filePath,
        'type': doc.type.value,
        'file_size_bytes': doc.fileSizeBytes,
        'character_count': doc.characterCount,
        'estimated_tokens': doc.estimatedTokens,
        'extracted_text': doc.extractedText,
        'uploaded_at': doc.uploadedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DocumentMetadata?> getDocumentById(String id) async {
    final db = await _db;
    final rows = await db.query('documents', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return DocumentMetadata(
      id: row['id'] as String,
      fileName: row['file_name'] as String,
      filePath: row['file_path'] as String,
      type: DocumentType.values.firstWhere(
        (t) => t.value == row['type'],
        orElse: () => DocumentType.txt,
      ),
      fileSizeBytes: row['file_size_bytes'] as int,
      characterCount: row['character_count'] as int? ?? 0,
      estimatedTokens: row['estimated_tokens'] as int? ?? 0,
      extractedText: row['extracted_text'] as String? ?? '',
      uploadedAt: DateTime.parse(row['uploaded_at'] as String),
    );
  }

  Future<List<DocumentMetadata>> getAllDocuments() async {
    final db = await _db;
    final rows = await db.query('documents', orderBy: 'uploaded_at DESC');
    return rows.map((row) => DocumentMetadata(
      id: row['id'] as String,
      fileName: row['file_name'] as String,
      filePath: row['file_path'] as String,
      type: DocumentType.values.firstWhere(
        (t) => t.value == row['type'],
        orElse: () => DocumentType.txt,
      ),
      fileSizeBytes: row['file_size_bytes'] as int,
      characterCount: row['character_count'] as int? ?? 0,
      estimatedTokens: row['estimated_tokens'] as int? ?? 0,
      extractedText: row['extracted_text'] as String? ?? '',
      uploadedAt: DateTime.parse(row['uploaded_at'] as String),
    )).toList();
  }

  Future<void> deleteDocument(String id) async {
    final db = await _db;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }
}
