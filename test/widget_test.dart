import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:tympeak/data/storage.dart';
import 'package:tympeak/main.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('tympeak_test_');
    await Storage.initForTest(dir.path);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
  });

  testWidgets('App boots and shows all five tabs', (tester) async {
    await tester.pumpWidget(const TympeakApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Tasks'),    findsOneWidget);
    expect(find.text('Habits'),   findsOneWidget);
    expect(find.text('Timer'),    findsOneWidget);
    expect(find.text('Notes'),    findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
