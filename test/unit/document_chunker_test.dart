import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app_local_ai/orchestration/document_chunker.dart';

void main() {
  group('DocumentChunker', () {
    test('returns single chunk for short text', () {
      const text = 'This is a short study guide about Flutter isolates and memory safety.';
      final chunks = DocumentChunker.chunkText(text, maxChunkChars: 500, overlapChars: 50);

      expect(chunks.length, equals(1));
      expect(chunks.first.text, equals(text));
      expect(chunks.first.tokenEstimate, greaterThan(0));
    });

    test('splits longer text into overlapping chunks', () {
      final buffer = StringBuffer();
      for (int i = 0; i < 50; i++) {
        buffer.writeln('Sentence number $i explaining detailed computer science concepts.');
      }
      final text = buffer.toString();

      final chunks = DocumentChunker.chunkText(text, maxChunkChars: 400, overlapChars: 100);

      expect(chunks.length, greaterThan(1));
      for (int i = 0; i < chunks.length; i++) {
        expect(chunks[i].index, equals(i));
        expect(chunks[i].text.isNotEmpty, isTrue);
      }
    });
  });
}
