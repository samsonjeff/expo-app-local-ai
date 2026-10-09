import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/quiz.dart';

class QuizExportService {
  /// Generates a human-readable formatted document (Markdown / Text)
  static String generateFormattedText(Quiz quiz, {required bool includeAnswerKey}) {
    final buffer = StringBuffer();
    final modeLabel = quiz.assessmentMode.label.toUpperCase();

    buffer.writeln('=' * 60);
    buffer.writeln('  ${quiz.title.toUpperCase()}');
    buffer.writeln('  Assessment Mode: $modeLabel | Difficulty: ${quiz.difficulty.label}');
    buffer.writeln('  Passing Score: ${quiz.passingScore}% | Total Questions: ${quiz.totalQuestions}');
    buffer.writeln('=' * 60);
    buffer.writeln();

    if (!includeAnswerKey) {
      buffer.writeln('*** STUDENT ASSESSMENT PAPER ***');
      buffer.writeln('Name: _______________________________   Date: ______________');
      buffer.writeln('Grade / Section: ____________________   Score: _____ / ${quiz.totalPoints}');
      buffer.writeln();
      buffer.writeln('INSTRUCTIONS: Read each question carefully and provide the best answer.');
      buffer.writeln('-' * 60);
      buffer.writeln();
    } else {
      buffer.writeln('*** TEACHER ANSWER KEY & GRADING RUBRIC ***');
      buffer.writeln('-' * 60);
      buffer.writeln();
    }

    for (int i = 0; i < quiz.questions.length; i++) {
      final q = quiz.questions[i];
      buffer.writeln('${i + 1}. [${q.questionType.label} - ${q.points} pt${q.points > 1 ? "s" : ""}]');
      buffer.writeln('   ${q.questionText}');
      buffer.writeln();

      switch (q.questionType) {
        case QuestionType.multipleChoice:
          for (int j = 0; j < q.options.length; j++) {
            final opt = q.options[j];
            final prefix = String.fromCharCode(65 + j); // A, B, C, D
            if (includeAnswerKey && opt.isCorrect) {
              buffer.writeln('   [X] ($prefix) ${opt.optionText}  <-- CORRECT ANSWER');
            } else {
              buffer.writeln('   [ ] ($prefix) ${opt.optionText}');
            }
          }
          break;

        case QuestionType.trueFalse:
          if (includeAnswerKey) {
            final correctOpt = q.options.where((o) => o.isCorrect).firstOrNull?.optionText ?? 'True';
            buffer.writeln('   [X] CORRECT ANSWER: $correctOpt');
          } else {
            buffer.writeln('   ( ) True     ( ) False');
          }
          break;

        case QuestionType.identification:
          if (includeAnswerKey) {
            final answers = q.acceptableAnswers.isNotEmpty
                ? q.acceptableAnswers.join(' / ')
                : 'See explanation';
            buffer.writeln('   [X] CORRECT ANSWER: $answers');
          } else {
            buffer.writeln('   Answer: _____________________________________________');
          }
          break;

        case QuestionType.enumeration:
          if (includeAnswerKey) {
            buffer.writeln('   [X] ACCEPTABLE ITEMS:');
            for (final item in q.acceptableAnswers) {
              buffer.writeln('       - $item');
            }
          } else {
            buffer.writeln('   1. ___________________________   2. ___________________________');
            buffer.writeln('   3. ___________________________   4. ___________________________');
          }
          break;

        case QuestionType.essay:
          if (includeAnswerKey) {
            buffer.writeln('   [X] AI RUBRIC KEY & MODEL ANSWER:');
            final lines = q.explanation.split('\n');
            for (final line in lines) {
              buffer.writeln('       $line');
            }
          } else {
            buffer.writeln('   Write your response below:');
            buffer.writeln('   __________________________________________________________________');
            buffer.writeln('   __________________________________________________________________');
            buffer.writeln('   __________________________________________________________________');
          }
          break;

        case QuestionType.fillInBlank:
          if (includeAnswerKey) {
            buffer.writeln('   [X] CORRECT ANSWER: ${q.acceptableAnswers.join(" / ")}');
          } else {
            buffer.writeln('   Answer: _____________________________________________');
          }
          break;
      }

      if (includeAnswerKey && q.explanation.isNotEmpty && q.questionType != QuestionType.essay) {
        buffer.writeln();
        buffer.writeln('   Explanation: ${q.explanation}');
      }

      buffer.writeln();
      buffer.writeln('.' * 40);
      buffer.writeln();
    }

    return buffer.toString();
  }

  static String _sanitizeForStandardPdf(String text) {
    return text
        .replaceAll('✓', '[X]')
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'")
        .replaceAll('‘', "'");
  }

  /// Generates a PDF byte array using Syncfusion PDF
  static Future<List<int>> generatePdfBytes(Quiz quiz, {required bool includeAnswerKey}) async {
    final document = PdfDocument();
    document.pageSettings.margins.all = 36; // 0.5 inch margins

    final regularFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);

    final rawText = generateFormattedText(quiz, includeAnswerKey: includeAnswerKey);
    final contentText = _sanitizeForStandardPdf(rawText);

    final page = document.pages.add();
    final pageSize = page.getClientSize();

    // Draw header
    final headerText = '${quiz.title.toUpperCase()}\n'
        'Mode: ${quiz.assessmentMode.label} | Passing: ${quiz.passingScore}% | Questions: ${quiz.totalQuestions}\n'
        '${includeAnswerKey ? "*** TEACHER ANSWER KEY & RUBRIC ***" : "*** STUDENT ASSESSMENT PAPER ***"}';

    final textElement = PdfTextElement(
      text: headerText,
      font: titleFont,
      brush: PdfSolidBrush(PdfColor(30, 41, 59)),
    );
    final layoutResult = textElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
    );

    // Draw body text with automatic pagination
    final bodyElement = PdfTextElement(
      text: contentText,
      font: regularFont,
      brush: PdfSolidBrush(PdfColor(15, 23, 42)),
    );

    final layoutFormat = PdfLayoutFormat(
      layoutType: PdfLayoutType.paginate,
      breakType: PdfLayoutBreakType.fitPage,
    );

    bodyElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, (layoutResult?.bounds.bottom ?? 40) + 16, pageSize.width, pageSize.height),
      format: layoutFormat,
    );

    final bytes = await document.save();
    document.dispose();
    return bytes;
  }

  /// Exports and triggers OS Share / Print sheet
  static Future<void> exportAndShare(
    Quiz quiz, {
    required bool includeAnswerKey,
  }) async {
    final text = generateFormattedText(quiz, includeAnswerKey: includeAnswerKey);
    final safeTitle = quiz.title.replaceAll(RegExp(r'[^\w\-]'), '_');
    final fileName = '${safeTitle}_${includeAnswerKey ? "AnswerKey" : "TestPaper"}';

    if (!kIsWeb) {
      try {
        final pdfBytes = await generatePdfBytes(quiz, includeAnswerKey: includeAnswerKey);
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName.pdf');
        await file.writeAsBytes(pdfBytes, flush: true);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/pdf', name: '$fileName.pdf')],
            subject: '${quiz.title} (${includeAnswerKey ? "Answer Key" : "Exam Paper"})',
            text: 'Local AI Generated Quiz: ${quiz.title}',
          ),
        );
        return;
      } catch (e) {
        debugPrint('PDF export failed, falling back to text share: $e');
      }
    }

    // Fallback or Web share
    await SharePlus.instance.share(
      ShareParams(
        subject: '${quiz.title} (${includeAnswerKey ? "Answer Key" : "Exam Paper"})',
        text: text,
      ),
    );
  }
}
