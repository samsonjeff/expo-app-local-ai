import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';
import '../models/document.dart';

class DocumentParser {
  static Future<String> parseFileInIsolate(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final bytes = await file.readAsBytes();
    final type = DocumentType.fromPath(filePath);

    return await Isolate.run(() {
      return parseBytes(bytes, type);
    });
  }

  static String parseBytes(List<int> bytes, DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return _parsePdf(bytes);
      case DocumentType.docx:
        return _parseDocx(bytes);
      case DocumentType.pptx:
        return _parsePptx(bytes);
      case DocumentType.txt:
      case DocumentType.md:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static String _parsePdf(List<int> bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final text = PdfTextExtractor(document).extractText();
      return text;
    } finally {
      document.dispose();
    }
  }

  static String _parseDocx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docXmlFile = archive.findFile('word/document.xml');
    if (docXmlFile == null) return '';

    final xmlContent = utf8.decode(docXmlFile.content as List<int>, allowMalformed: true);
    final document = XmlDocument.parse(xmlContent);

    final textNodes = document.findAllElements('w:t');
    final buffer = StringBuffer();
    for (final node in textNodes) {
      buffer.write('${node.innerText} ');
    }
    return buffer.toString().trim();
  }

  static String _parsePptx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final buffer = StringBuffer();

    final slideFiles = archive.files
        .where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final slide in slideFiles) {
      final xmlContent = utf8.decode(slide.content as List<int>, allowMalformed: true);
      final document = XmlDocument.parse(xmlContent);
      final textNodes = document.findAllElements('a:t');
      for (final node in textNodes) {
        buffer.write('${node.innerText} ');
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }
}
