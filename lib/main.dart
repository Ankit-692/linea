import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'features/reader/models/book.dart';
import 'core/state/app_state.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final appDir = await getApplicationSupportDirectory();
  Hive.init(appDir.path);
  Hive.registerAdapter(BookAdapter());
  
  // Open the boxes
  await Hive.openBox<Book>('booksBox');
  await Hive.openBox('settingsBox'); // New box for app settings/flags

  // Check if onboarding is complete
  final settingsBox = Hive.box('settingsBox');
  final bool hasSeenOnboarding = settingsBox.get('hasSeenOnboarding', defaultValue: false);

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: LineaApp(showOnboarding: !hasSeenOnboarding),
    ),
  );
}

class LineaApp extends StatelessWidget {
  final bool showOnboarding;

  const LineaApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    // Watch AppState to rebuild when theme changes
    final appState = context.watch<AppState>();

    return MaterialApp(
      title: 'Linea',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      // Automatically switch based on state
      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: showOnboarding ? const OnboardingScreen() : const DashboardScreen(),
    );
  }
}