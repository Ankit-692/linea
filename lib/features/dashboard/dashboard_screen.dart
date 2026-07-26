import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../core/state/app_state.dart';
import '../../features/reader/models/book.dart';
import '../reader/screens/reader_screen.dart';
import '../reader/services/file_parser_service.dart';
import '../../features/reader/services/cache_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _pickAndParseFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub'],
      lockParentWindow: true,
    );

    if (result != null && result.files.single.path != null) {
      final String filePath = result.files.single.path!;
      final String fileName = result.files.single.name;

      _openBook(context, filePath, fileName, 0, 0);
    }
  }

  Future<void> _openBook(BuildContext context, String filePath, String title, int startPage, int startLine) async {
    // Check if file still exists on device
    if (!File(filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found. It may have been moved or deleted.')),
      );
      // Optional: Remove from Hive box here
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<List<String>>? extractedPages = await CacheService.loadBookCache(filePath);
      // 2. If no cache exists, parse it and then save it to the cache
      if (extractedPages == null) {
        extractedPages = await FileParserService.parseFile(filePath);
        // Save it in the background so it doesn't hold up the UI
        CacheService.saveBookCache(filePath, extractedPages);
      }
      if (!context.mounted) return;
      
      context.read<AppState>().loadNewBook(
        title, 
        filePath, 
        extractedPages,
        startPage: startPage,
        startLine: startLine,
      );

      Navigator.pop(context); // Close dialog

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ReaderScreen()),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Book>('booksBox');
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linea', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.teal.shade50,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: appState.toggleTheme,
            tooltip: 'Toggle Theme',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => _pickAndParseFile(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.add_circle_outline, color: Colors.white, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Import PDF or EPUB',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Recent Books',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: box.listenable(),
                builder: (context, Box<Book> currentBox, _) {
                  if (currentBox.isEmpty) {
                    return const Center(
                      child: Text('No recent books. Import one to get started!'),
                    );
                  }

                  // Convert to list and reverse so newest is on top
                  final books = currentBox.values.toList().reversed.toList();

                  return ListView.separated(
                    itemCount: books.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            // Make the icon container adapt to dark mode
                            color: isDark ? Colors.grey.shade800 : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.book, color: Colors.teal),
                        ),
                        title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('Page ${book.currentPageIndex + 1} • Line ${book.currentLineIndex + 1}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          _openBook(context, book.filePath, book.title, book.currentPageIndex, book.currentLineIndex);
                        },
                        onLongPress: () {
                          // Allow deleting from history
                          currentBox.delete(book.filePath);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}