import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:ui';
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
  bool _isDragging = false;

  bool get _isDropSupported => kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  bool get _isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

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

  String _normalizeFilePath(String rawPath) {
    String cleanPath = rawPath.trim();
    cleanPath = cleanPath.replaceAll('\r', '').replaceAll('\n', '');
    if (cleanPath.startsWith('file://')) {
      try {
        final uri = Uri.parse(cleanPath);
        cleanPath = uri.toFilePath();
      } catch (_) {
        cleanPath = Uri.decodeFull(cleanPath.replaceFirst('file://', ''));
      }
    } else {
      try {
        cleanPath = Uri.decodeFull(cleanPath);
      } catch (_) {}
    }
    return cleanPath;
  }

  Future<void> _handleFileImport(
    BuildContext context,
    String rawOriginalPath,
    String rawFileName,
  ) async {
    final originalPath = _normalizeFilePath(rawOriginalPath);
    String fileName = rawFileName.trim().replaceAll('\r', '').replaceAll('\n', '');
    if (fileName.isEmpty) {
      fileName = originalPath.split(Platform.pathSeparator).last;
    }

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

    if (existingKey != savedPath && originalPath != savedPath) {
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

  Future<void> _saveBookToLibrarySilently(String rawOriginalPath, String rawFileName) async {
    try {
      final originalPath = _normalizeFilePath(rawOriginalPath);
      String fileName = rawFileName.trim().replaceAll('\r', '').replaceAll('\n', '');
      if (fileName.isEmpty) {
        fileName = originalPath.split(Platform.pathSeparator).last;
      }

      final directory = await getApplicationDocumentsDirectory();
      final String savedPath = '${directory.path}/$fileName';
      final box = Hive.box<Book>('booksBox');
      
      final existingKey = box.keys.firstWhere(
        (k) {
          final b = box.get(k);
          return b != null && b.title == fileName;
        },
        orElse: () => null,
      );

      if (existingKey == null) {
        if (originalPath != savedPath) {
          await File(originalPath).copy(savedPath);
        }
        List<List<String>>? extractedPages = await CacheService.loadBookCache(savedPath);
        if (extractedPages == null) {
          extractedPages = await FileParserService.parseFile(savedPath);
          CacheService.saveBookCache(savedPath, extractedPages);
        }
        final book = Book(
          title: fileName,
          filePath: savedPath,
          currentPageIndex: 0,
          currentLineIndex: 0,
          totalPages: extractedPages.length,
        );
        box.put(savedPath, book);
      }
    } catch (_) {
      // Ignore background import error
    }
  }

  Future<void> _handleDroppedFiles(BuildContext context, List<XFile> files) async {
    if (files.isEmpty) {
      if (context.mounted) {
        ToastUtils.showTopToast(
          context,
          'Unable to Receive File',
          'Your system did not transfer the file data. Please use the "Import Document" button.',
        );
      }
      return;
    }

    final validItems = <({String path, String name})>[];
    for (final file in files) {
      final cleanPath = _normalizeFilePath(file.path);
      final ext = cleanPath.split('.').last.toLowerCase();
      if (ext == 'pdf' || ext == 'epub') {
        final name = file.name.isNotEmpty
            ? file.name.replaceAll('\r', '').replaceAll('\n', '')
            : cleanPath.split(Platform.pathSeparator).last;
        validItems.add((path: cleanPath, name: name));
      }
    }

    if (validItems.isEmpty) {
      if (context.mounted) {
        ToastUtils.showTopToast(
          context,
          'Unsupported Format',
          'Linea supports PDF and EPUB files.',
        );
      }
      return;
    }

    if (validItems.length == 1) {
      final item = validItems.first;
      if (context.mounted) {
        await _handleFileImport(context, item.path, item.name);
      }
    } else {
      for (int i = 1; i < validItems.length; i++) {
        final item = validItems[i];
        await _saveBookToLibrarySilently(item.path, item.name);
      }

      final first = validItems.first;
      if (context.mounted) {
        ToastUtils.showTopToast(
          context,
          'Books Imported',
          'Added ${validItems.length} books to your library.',
        );
        await _handleFileImport(context, first.path, first.name);
      }
    }
  }

  Future<void> _pickAndParseFile(BuildContext context) async {
    try {
      if (!kIsWeb && Platform.isMacOS) {
        await FilePicker.skipEntitlementsChecks();
      }

      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'PDF', 'EPUB'],
        lockParentWindow: true,
        allowMultiple: false,
        withData: false,
      );

      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        final String originalPath = result.files.first.path!;
        final String fileName = result.files.first.name;
        if (context.mounted) {
          await _handleFileImport(context, originalPath, fileName);
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (context.mounted) {
        ToastUtils.showTopToast(
          context,
          'Import Failed',
          'Could not open file picker: $e',
        );
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
    final cleanPath = _normalizeFilePath(filePath);
    if (!File(cleanPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('File not found. It may have been moved or deleted.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Remove',
            onPressed: () {
              final box = Hive.box<Book>('booksBox');
              box.delete(filePath);
              box.delete(cleanPath);
              CacheService.deleteBookCache(filePath);
              CacheService.deleteBookCache(cleanPath);
            },
          ),
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

  Widget _buildDropOverlayContent(BuildContext context, bool isDark, ColorScheme colorScheme) {
    return Container(
      color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.65 : 0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 36),
          constraints: const BoxConstraints(maxWidth: 460),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: colorScheme.primary,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.file_download_outlined,
                  color: colorScheme.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Drop to Read',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Release to open your document in RSVP reader',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Supports .pdf and .epub files',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      body: DropTarget(
        enable: _isDropSupported,
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) async {
          setState(() => _isDragging = false);
          await _handleDroppedFiles(context, details.files);
        },
        child: Stack(
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
                                      _isDesktop ? 'Drag & drop a PDF or EPUB here to get started' : 'Import a document to get started',
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
            if (_isDropSupported)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: _isDragging ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  if (value == 0.0) return const SizedBox.shrink();
                  return Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10 * value, sigmaY: 10 * value),
                          child: _buildDropOverlayContent(context, isDark, colorScheme),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
