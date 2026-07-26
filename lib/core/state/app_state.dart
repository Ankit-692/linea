import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/reader/models/book.dart';

class AppState extends ChangeNotifier {
  // --- Theme State ---
  bool _isDarkMode = Hive.box('settingsBox').get('isDarkMode', defaultValue: false);
  bool get isDarkMode => _isDarkMode;

  // --- Font Size State ---
  // Default to 32.0 if no preference is saved
  double _fontSize = Hive.box('settingsBox').get('fontSize', defaultValue: 32.0);
  double get fontSize => _fontSize;

  void increaseFontSize() {
    if (_fontSize < 72.0) {
      _fontSize += 2.0;
      Hive.box('settingsBox').put('fontSize', _fontSize);
      notifyListeners();
    }
  }

  void decreaseFontSize() {
    if (_fontSize > 16.0) {
      _fontSize -= 2.0;
      Hive.box('settingsBox').put('fontSize', _fontSize);
      notifyListeners();
    }
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    Hive.box('settingsBox').put('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  String _currentBookTitle = '';
  String _currentFilePath = '';
  List<List<String>> _currentBookPages = [];
  int _currentPageIndex = 0;
  int _currentLineIndex = 0;

  String get currentBookTitle => _currentBookTitle;
  List<List<String>> get currentBookPages => _currentBookPages;
  int get currentPageIndex => _currentPageIndex;
  int get currentLineIndex => _currentLineIndex;

  final Box<Book> _booksBox = Hive.box<Book>('booksBox');

  void loadNewBook(String title, String filePath, List<List<String>> pages, {int startPage = 0, int startLine = 0}) {
    _currentBookTitle = title;
    _currentFilePath = filePath;
    _currentBookPages = pages;
    _currentPageIndex = startPage;
    _currentLineIndex = startLine;
    
    _saveProgress();
    notifyListeners();
  }

  void _saveProgress() {
    if (_currentFilePath.isEmpty || _currentBookPages.isEmpty) return;
    
    final book = Book(
      title: _currentBookTitle,
      filePath: _currentFilePath,
      currentPageIndex: _currentPageIndex,
      currentLineIndex: _currentLineIndex,
    );
    
    // Save or update the book using its file path as the unique key
    _booksBox.put(_currentFilePath, book);
  }

  bool nextLine() {
    if (_currentBookPages.isEmpty) return false;
    if (_currentLineIndex < _currentBookPages[_currentPageIndex].length - 1) {
      _currentLineIndex++;
      _saveProgress();
      notifyListeners();
      return true;
    } else {
      return false; // End of page
    }
  }

  void previousLine() {
    if (_currentLineIndex > 0) {
      _currentLineIndex--;
      _saveProgress();
      notifyListeners();
    }
  }

  void nextPage() {
    if (_currentBookPages.isEmpty) return;
    if (_currentPageIndex < _currentBookPages.length - 1) {
      _currentPageIndex++;
      _currentLineIndex = 0;
      _saveProgress();
      notifyListeners();
    }
  }

  void previousPage() {
    if (_currentPageIndex > 0) {
      _currentPageIndex--;
      _currentLineIndex = 0;
      _saveProgress();
      notifyListeners();
    }
  }

  void jumpToPage(int pageIndex) {
    if (_currentBookPages.isEmpty) return;
    
    if (pageIndex >= 0 && pageIndex < _currentBookPages.length) {
      _currentPageIndex = pageIndex;
      _currentLineIndex = 0; // Always start at the top of the new page
      _saveProgress();
      notifyListeners();
    }
  }
}