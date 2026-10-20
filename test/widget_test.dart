import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:linea/core/state/app_state.dart';
import 'package:linea/features/dashboard/dashboard_screen.dart';
import 'package:linea/features/reader/models/book.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('linea_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BookAdapter());
    }
    await Hive.openBox<Book>('booksBox');
    await Hive.openBox('settingsBox');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Dashboard renders and has DropTarget for desktop drag and drop', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => AppState(),
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Dashboard displays Import Document
    expect(find.text('Import Document'), findsOneWidget);
    expect(find.text('Continue Reading'), findsOneWidget);

    // Verify DropTarget is present for drag and drop
    expect(find.byType(DropTarget), findsOneWidget);
  });
}
