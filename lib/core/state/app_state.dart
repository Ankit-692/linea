import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppState extends ChangeNotifier {
  final Box _settingsBox = Hive.box('settingsBox');

  // Check if it's the user's first time opening the app
  bool get isFirstLaunch => _settingsBox.get('isFirstLaunch', defaultValue: true);

  // Call this after they finish the welcome screen
  Future<void> completeOnboarding() async {
    await _settingsBox.put('isFirstLaunch', false);
    notifyListeners(); // Tells the UI to update
  }

  String currentBookTitle = '';
  List<List<String>> currentBookPages = [];
  
  int currentPageIndex = 0;
  int currentLineIndex = 0;

  void loadNewBook(String title, List<List<String>> pages) {
    currentBookTitle = title;
    currentBookPages = pages;
    currentPageIndex = 0;
    currentLineIndex = 0;
    notifyListeners();
  }

  // Returns true if moving to next line, false if end of page is reached
  bool nextLine() {
    if (currentLineIndex < currentBookPages[currentPageIndex].length - 1) {
      currentLineIndex++;
      notifyListeners();
      return true;
    }
    return false; // End of page reached!
  }
  
  void previousLine() {
    if (currentLineIndex > 0) {
      currentLineIndex--;
      notifyListeners();
    }
  }

  void nextPage() {
    if (currentPageIndex < currentBookPages.length - 1) {
      currentPageIndex++;
      currentLineIndex = 0; // Reset to top of new page
      notifyListeners();
    }
  }

  void previousPage() {
    if (currentPageIndex > 0) {
      currentPageIndex--;
      currentLineIndex = 0;
      notifyListeners();
    }
  }
}