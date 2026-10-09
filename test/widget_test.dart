import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app_local_ai/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('LocalAiQuizApp renders home screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LocalAiQuizApp());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Local AI Quiz App'), findsOneWidget);
  });
}
