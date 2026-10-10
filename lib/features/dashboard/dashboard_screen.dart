import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
import '../../core/widgets/keyboard_shortcuts_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

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

  void _showTopToast(BuildContext context, String title, String message) {
    final appState = context.read<AppState>();
    final isDark = appState.isDarkMode;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -100 * (1 - value)),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(isDark ? 0.2 : 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
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

      try {
        await File(originalPath).copy(savedPath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save file: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

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

        if (mounted) {
          _showTopToast(
            context, 
            'Already Imported', 
            '"$fileName" is already in your library. Resuming your progress!'
          );
        }
      }

      if (mounted) {
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

  Widget _buildBackground(bool isDark, Color primaryColor) {
    final bgColor = isDark 
        ? Color.alphaBlend(primaryColor.withOpacity(0.04), const Color(0xFF09090B))
        : Color.alphaBlend(primaryColor.withOpacity(0.04), const Color(0xFFFAFAFA));

    return Positioned.fill(
      child: Container(
        color: bgColor,
        child: Stack(
          children: [
            Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(isDark ? 0.08 : 0.08),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(isDark ? 0.05 : 0.05),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppState appState, bool isDark) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Text(
          'Library',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 24,
          ),
        ),
      ),
      actions: [
        if (!_isMobile)
          IconButton(
            icon: const Icon(Icons.keyboard_command_key_rounded),
            tooltip: 'Keyboard Shortcuts',
            onPressed: () => showKeyboardShortcutsDialog(context),
          ),
        PopupMenuButton<int>(
          icon: const Icon(Icons.palette_rounded),
          tooltip: 'Theme Accent',
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          onSelected: appState.setThemeColor,
          itemBuilder: (context) => [
            for (int i = 0; i < AppState.themeColors.length; i++)
              PopupMenuItem(
                value: i,
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppState.themeColors[i],
                        shape: BoxShape.circle,
                        border: appState.colorIndex == i
                            ? Border.all(
                                color: isDark ? Colors.white : Colors.black,
                                width: 2.5,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      ['Mint', 'Purple', 'Royal Blue', 'Coral', 'Sage'][i],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
        IconButton(
          icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          onPressed: appState.toggleTheme,
          tooltip: 'Toggle Theme',
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context, ColorScheme colorScheme, bool isDark) {
    return BouncingButton(
      onTap: () => _pickAndParseFile(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: isDark 
              ? const LinearGradient(
                  colors: [Color(0xFF1E1E1E), Color(0xFF161616)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: isDark ? Border.all(color: colorScheme.primary.withOpacity(0.3), width: 1.5) : null,
          boxShadow: [
            if (isDark)
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            else ...[
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 0,
                spreadRadius: 1,
                offset: const Offset(0, 1),
              ),
            ]
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.primary.withOpacity(0.15) : Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? colorScheme.primary.withOpacity(0.3) : Colors.white.withOpacity(0.4), 
                  width: 1.5
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: isDark ? colorScheme.primary : Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import Document',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PDF or EPUB • Start reading with RSVP',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookItem(BuildContext context, Book book, bool isDark, ColorScheme colorScheme, Box<Book> box) {
    final colors = [
      Colors.blueAccent, Colors.purpleAccent, Colors.orangeAccent, Colors.tealAccent, Colors.pinkAccent
    ];
    final coverColor = colors[book.title.hashCode % colors.length];

    return BouncingButton(
      onTap: () => _openBook(context, book.filePath, book.title, book.currentPageIndex, book.currentLineIndex),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
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
                                      onPressed: () async {
                                        // Delete the physical file
                                        final file = File(book.filePath);
                                        if (await file.exists()) {
                                          try {
                                            await file.delete();
                                          } catch (e) {
                                            // Ignore if unable to delete
                                          }
                                        }

                                        // Delete the cached parsed text data
                                        await CacheService.deleteBookCache(book.filePath);

                                        // Remove from library
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
                            },
                            onTap: () => _openBook(context, book.filePath, book.title, book.currentPageIndex, book.currentLineIndex),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [coverColor.withOpacity(0.7), coverColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: coverColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          book.title.isNotEmpty ? book.title[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.2,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final total = book.totalPages > 0 ? book.totalPages : 1;
                              final progress = (book.currentPageIndex + 1) / total;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${(progress * 100).toStringAsFixed(0)}% Read',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      Text(
                                        'Page ${book.currentPageIndex + 1} of $total',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 6,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress.clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          borderRadius: BorderRadius.circular(3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colorScheme.primary.withOpacity(0.4),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
      body: Stack(
        children: [
          _buildBackground(isDark, colorScheme.primary),
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
                      _buildAppBar(context, appState, isDark),
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
                            _buildHeroCard(context, colorScheme, isDark),
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
                                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
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
                              return _buildBookItem(context, books[index], isDark, colorScheme, currentBox);
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

class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  
  const BouncingButton({super.key, required this.child, required this.onTap});

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
