import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/state/app_state.dart';
import '../../features/reader/models/book.dart';
import '../reader/screens/reader_screen.dart';
import '../reader/services/file_parser_service.dart';
import '../../features/reader/services/cache_service.dart';
import '../../core/utils/toast_utils.dart';
import 'widgets/dashboard_background.dart';
import 'widgets/dashboard_app_bar.dart';
import 'widgets/import_hero_card.dart';
import 'widgets/book_list_item.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _pickAndParseFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub'],
      lockParentWindow: true,
      allowMultiple: false,
      withData: false,
    );

    if (result != null && result.files.single.path != null) {
      final String originalPath = result.files.single.path!;
      final String fileName = result.files.single.name;

      final directory = await getApplicationDocumentsDirectory();
      final String savedPath = '${directory.path}/$fileName';

      int startPage = 0;
      int startLine = 0;

      final box = Hive.box<Book>('booksBox');
      
      final existingKey = box.keys.firstWhere(
        (k) {
          final b = box.get(k);
          return b != null && b.title == fileName;
        },
        orElse: () => null,
      );

      if (existingKey != null) {
        final existingBook = box.get(existingKey)!;
        startPage = existingBook.currentPageIndex;
        startLine = existingBook.currentLineIndex;
        
        if (existingKey != savedPath) {
          final file = File(existingKey as String);
          if (await file.exists()) {
            try {
              await file.delete();
            } catch (e) {
              // Ignore if unable to delete
            }
          }
          await CacheService.deleteBookCache(existingKey);
          box.delete(existingKey);
        }

        if (context.mounted) {
          ToastUtils.showTopToast(
            context, 
            'Already Imported', 
            '"$fileName" is already in your library. Resuming your progress!'
          );
        }
      }

      if (existingKey != savedPath) {
        try {
          await File(originalPath).copy(savedPath);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save file: $e'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      if (context.mounted) {
        _openBook(context, savedPath, fileName, startPage, startLine);
      }
    }
  }

  Future<void> _openBook(
    BuildContext context,
    String filePath,
    String title,
    int startPage,
    int startLine,
  ) async {
    if (!File(filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found. It may have been moved or deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const CircularProgressIndicator(),
        ),
      ),
    );

    try {
      List<List<String>>? extractedPages = await CacheService.loadBookCache(filePath);
      if (extractedPages == null) {
        extractedPages = await FileParserService.parseFile(filePath);
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
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  void _confirmAndRemoveBook(BuildContext context, Book book, Box<Book> box, bool isDark) {
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
            onPressed: () async {
              final file = File(book.filePath);
              if (await file.exists()) {
                try {
                  await file.delete();
                } catch (e) {
                  // Ignore if unable to delete
                }
              }

              await CacheService.deleteBookCache(book.filePath);
              box.delete(book.filePath);

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Book>('booksBox');
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          DashboardBackground(isDark: isDark, primaryColor: colorScheme.primary),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ValueListenableBuilder<Box<Book>>(
                valueListenable: box.listenable(),
                builder: (context, currentBox, _) {
                  final books = currentBox.values.toList().reversed.toList();
                  
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      DashboardAppBar(appState: appState, isDark: isDark),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                '${_getGreeting()},',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ImportHeroCard(
                              colorScheme: colorScheme, 
                              isDark: isDark, 
                              onImportTap: () => _pickAndParseFile(context),
                            ),
                            const SizedBox(height: 48),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Row(
                                children: [
                                  Text(
                                    'Continue Reading',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black87,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.auto_stories_rounded, color: colorScheme.primary, size: 24),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                      if (books.isEmpty)
                        SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 48.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.menu_book_rounded, size: 48, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'No books yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Import a document to get started',
                                    style: TextStyle(
                                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final book = books[index];
                              return BookListItem(
                                book: book,
                                isDark: isDark,
                                colorScheme: colorScheme,
                                onTap: () => _openBook(context, book.filePath, book.title, book.currentPageIndex, book.currentLineIndex),
                                onRemove: () => _confirmAndRemoveBook(context, book, currentBox, isDark),
                              );
                            },
                            childCount: books.length,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 48)),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
