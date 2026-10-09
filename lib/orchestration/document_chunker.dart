import 'dart:isolate';
import '../models/document.dart';

class DocumentChunker {
  static const int defaultMaxChunkChars = 3200; // ~800 tokens
  static const int defaultOverlapChars = 400;   // ~100 tokens

  static Future<List<DocumentChunk>> chunkTextInIsolate(
    String fullText, {
    int maxChunkChars = defaultMaxChunkChars,
    int overlapChars = defaultOverlapChars,
  }) async {
    return await Isolate.run(() {
      return chunkText(
        fullText,
        maxChunkChars: maxChunkChars,
        overlapChars: overlapChars,
      );
    });
  }

  static List<DocumentChunk> chunkText(
    String fullText, {
    int maxChunkChars = defaultMaxChunkChars,
    int overlapChars = defaultOverlapChars,
  }) {
    final trimmed = fullText.trim();
    if (trimmed.isEmpty) return [];

    if (trimmed.length <= maxChunkChars) {
      return [
        DocumentChunk(
          index: 0,
          text: trimmed,
          tokenEstimate: (trimmed.length / 4).ceil(),
          startChar: 0,
          endChar: trimmed.length,
        ),
      ];
    }

    final chunks = <DocumentChunk>[];
    int start = 0;
    int chunkIndex = 0;

    while (start < trimmed.length) {
      int end = start + maxChunkChars;
      if (end >= trimmed.length) {
        end = trimmed.length;
      } else {
        // Try to break at a natural boundary (paragraph or sentence)
        final searchWindow = trimmed.substring(start, end);
        final lastParagraph = searchWindow.lastIndexOf('\n\n');
        if (lastParagraph > maxChunkChars * 0.7) {
          end = start + lastParagraph;
        } else {
          final lastPeriod = searchWindow.lastIndexOf(RegExp(r'\. |\n'));
          if (lastPeriod > maxChunkChars * 0.6) {
            end = start + lastPeriod + 1;
          }
        }
      }

      final chunkText = trimmed.substring(start, end).trim();
      if (chunkText.isNotEmpty) {
        chunks.add(DocumentChunk(
          index: chunkIndex++,
          text: chunkText,
          tokenEstimate: (chunkText.length / 4).ceil(),
          startChar: start,
          endChar: end,
        ));
      }

      if (end >= trimmed.length) break;
      start = end - overlapChars;
      if (start < 0) start = 0;
    }

    return chunks;
  }
}
