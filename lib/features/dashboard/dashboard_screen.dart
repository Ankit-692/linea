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
import '../../core/widgets/keyboard_shortcuts_dialog.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  Future<void> _pickAndParseFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub'],
      lockParentWindow: true,
      allowMultiple: false,
      withData: false,
    );

    if (result != null && result.files.single.path != null) {
      final String filePath = result.files.single.path!;
      final String fileName = result.files.single.name;

      _openBook(context, filePath, fileName, 0, 0);
    }
  }

  Future<void> _openBook(
    BuildContext context,
    String filePath,
    String title,
    int startPage,
    int startLine,
  ) async {
    // Check if file still exists on device
    if (!File(filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found. It may have been moved or deleted.'),
        ),
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
      List<List<String>>? extractedPages = await CacheService.loadBookCache(
        filePath,
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Book>('booksBox');
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Linea',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (!_isMobile)
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Keyboard Shortcuts',
              onPressed: () => showKeyboardShortcutsDialog(context),
            ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Change Accent Color',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: appState.setThemeColor,
            itemBuilder: (context) => [
              for (int i = 0; i < AppState.themeColors.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppState.themeColors[i],
                          shape: BoxShape.circle,
                          border: appState.colorIndex == i
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  width: 2,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        ['Mint', 'Purple', 'Royal Blue', 'Coral', 'Sage'][i],
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: appState.toggleTheme,
            tooltip: 'Toggle Theme',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // Modern Hero Card
            InkWell(
              onTap: () => _pickAndParseFile(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Import PDF or EPUB',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start reading faster with RSVP',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                const Text(
                  'Recent Books',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Icon(Icons.auto_stories_rounded, color: colorScheme.primary, size: 20),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: box.listenable(),
                builder: (context, Box<Book> currentBox, _) {
                  if (currentBox.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No recent books yet.',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final books = currentBox.values.toList().reversed.toList();

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161616) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              _openBook(
                                context,
                                book.filePath,
                                book.title,
                                book.currentPageIndex,
                                book.currentLineIndex,
                              );
                            },
                            onLongPress: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  title: const Text('Remove Book?'),
                                  content: Text('Are you sure you want to remove "${book.title}" from your library?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: TextButton.styleFrom(foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        currentBox.delete(book.filePath);
                                        Navigator.pop(context);
                                      },
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.book_rounded,
                                      color: colorScheme.primary,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Page ${book.currentPageIndex + 1} • Line ${book.currentLineIndex + 1}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
