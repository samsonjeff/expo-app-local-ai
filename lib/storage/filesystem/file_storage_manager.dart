import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileStorageManager {
  static FileStorageManager? _instance;
  Directory? _baseDir;

  FileStorageManager._();
  static FileStorageManager get instance => _instance ??= FileStorageManager._();

  Future<void> initialize({Directory? customBaseDir}) async {
    if (customBaseDir != null) {
      _baseDir = customBaseDir;
    } else {
      _baseDir = await getApplicationDocumentsDirectory();
    }

    await getDocumentsDir();
    await getModelsDir();
    await getExportsDir();
  }

  Future<Directory> get baseDir async {
    if (_baseDir == null) {
      await initialize();
    }
    return _baseDir!;
  }

  Future<Directory> getDocumentsDir() async {
    final base = await baseDir;
    final dir = Directory(p.join(base.path, 'documents'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getModelsDir() async {
    final base = await baseDir;
    final dir = Directory(p.join(base.path, 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getExportsDir() async {
    final base = await baseDir;
    final dir = Directory(p.join(base.path, 'exports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> saveUploadedDocument(String originalFileName, List<int> bytes) async {
    final docsDir = await getDocumentsDir();
    final safeFileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(originalFileName)}';
    final destinationFile = File(p.join(docsDir.path, safeFileName));
    return await destinationFile.writeAsBytes(bytes);
  }

  Future<File> saveQuizExportJson(String quizId, String jsonContent) async {
    final exportsDir = await getExportsDir();
    final file = File(p.join(exportsDir.path, 'quiz_$quizId.quiz.json'));
    return await file.writeAsString(jsonContent);
  }
}
