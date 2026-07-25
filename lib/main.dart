import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/state/app_state.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settingsBox'); 
  await Hive.openBox('booksBox');    

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const LineaApp(), // <-- Updated Name
    ),
  );
}

class LineaApp extends StatelessWidget {
  const LineaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linea', // <-- Updated Name
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), // Changed to teal for a reading vibe
        useMaterial3: true,
      ),
      // The Consumer listens to AppState. 
      // If it's their first time, show Onboarding. Otherwise, show Dashboard.
      home: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.isFirstLaunch) {
            return const OnboardingScreen();
          }
          return const DashboardScreen();
        },
      ),
    );
  }
}