import 'package:uuid/uuid.dart';

enum DocumentType {
  pdf('pdf'),
  docx('docx'),
  pptx('pptx'),
  txt('txt'),
  md('md');

  final String value;
  const DocumentType(this.value);

  static DocumentType fromPath(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.pdf')) return DocumentType.pdf;
    if (lower.endsWith('.docx')) return DocumentType.docx;
    if (lower.endsWith('.pptx')) return DocumentType.pptx;
    if (lower.endsWith('.md')) return DocumentType.md;
    return DocumentType.txt;
  }
}

class DocumentChunk {
  final int index;
  final String text;
  final int tokenEstimate;
  final int startChar;
  final int endChar;

  const DocumentChunk({
    required this.index,
    required this.text,
    required this.tokenEstimate,
    required this.startChar,
    required this.endChar,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'text': text,
    'tokenEstimate': tokenEstimate,
    'startChar': startChar,
    'endChar': endChar,
  };

  factory DocumentChunk.fromJson(Map<String, dynamic> json) => DocumentChunk(
    index: (json['index'] as num).toInt(),
    text: json['text'] as String,
    tokenEstimate: (json['tokenEstimate'] as num).toInt(),
    startChar: (json['startChar'] as num).toInt(),
    endChar: (json['endChar'] as num).toInt(),
  );
}

class DocumentMetadata {
  final String id;
  final String fileName;
  final String filePath;
  final DocumentType type;
  final int fileSizeBytes;
  final int characterCount;
  final int estimatedTokens;
  final String extractedText;
  final DateTime uploadedAt;

  DocumentMetadata({
    String? id,
    required this.fileName,
    required this.filePath,
    required this.type,
    required this.fileSizeBytes,
    this.characterCount = 0,
    this.estimatedTokens = 0,
    this.extractedText = '',
    DateTime? uploadedAt,
  })  : id = id ?? const Uuid().v4(),
        uploadedAt = uploadedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'filePath': filePath,
    'type': type.value,
    'fileSizeBytes': fileSizeBytes,
    'characterCount': characterCount,
    'estimatedTokens': estimatedTokens,
    'extractedText': extractedText,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) => DocumentMetadata(
    id: json['id'] as String?,
    fileName: json['fileName'] as String,
    filePath: json['filePath'] as String,
    type: DocumentType.values.firstWhere(
      (t) => t.value == json['type'],
      orElse: () => DocumentType.txt,
    ),
    fileSizeBytes: (json['fileSizeBytes'] as num).toInt(),
    characterCount: (json['characterCount'] as num?)?.toInt() ?? 0,
    estimatedTokens: (json['estimatedTokens'] as num?)?.toInt() ?? 0,
    extractedText: json['extractedText'] as String? ?? '',
    uploadedAt: json['uploadedAt'] != null
        ? DateTime.tryParse(json['uploadedAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );
}
