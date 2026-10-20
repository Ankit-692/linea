import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/app_state.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/keyboard_shortcuts_dialog.dart';
import '../../../core/widgets/theme_picker_button.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  Orientation? _lastOrientation;
  Timer? _timer;
  bool _isPlaying = false;
  final FocusNode _keyboardFocusNode = FocusNode(); // add this
  final bool isMobile = Platform.isAndroid || Platform.isIOS;
  // Speed setting: Words Per Minute (WPM). Default is 200 WPM
  int _wpm = Hive.box('settingsBox').get('wpm', defaultValue: 200); 

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _lastLineIndex = -1;
  int _lastPageIndex = -1;
  double _lastFontSize = -1.0;
  bool _isInitialScrollDone = false;
  bool _isPageReady = true;
  double _dragAccumulator = 0.0;
  final double _dragThreshold = 40.0; // swipe distance required to change line

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onItemsChanged);
  }

  void _onItemsChanged() {
    if (!_isInitialScrollDone && _itemScrollController.isAttached) {
      _isInitialScrollDone = true;
      final appState = context.read<AppState>();
      _itemScrollController.jumpTo(index: appState.currentLineIndex, alignment: 0.35);
      _itemPositionsListener.itemPositions.removeListener(_onItemsChanged);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hideControlsTimer?.cancel();
    _keyboardFocusNode.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (isMobile) return;
    if (event is! KeyDownEvent) return;

    final appState = context.read<AppState>();

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlayPause();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      appState.nextLine();
      if (_isPlaying) _scheduleNextLine();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      appState.previousLine();
      if (_isPlaying) _scheduleNextLine();
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      appState.nextPage();
      if (!_isPlaying) {
        _togglePlayPause();
      } else {
        _scheduleNextLine();
      }
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _scheduleNextLine();
  }

  void _scheduleNextLine() {
    _timer?.cancel();
    if (!_isPlaying || !mounted) return;

    final appState = context.read<AppState>();
    
    if (appState.currentBookPages.isEmpty) return;
    
    final currentPage = appState.currentBookPages[appState.currentPageIndex];
    if (currentPage.isEmpty) return;
    
    final currentLine = currentPage[appState.currentLineIndex];
    
    final String trimmedLine = currentLine.trim();
    final int wordCount = trimmedLine.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    final int charCount = trimmedLine.length;
    
    // Standardize long words by assuming an average word length of 5 characters.
    double effectiveWords = wordCount.toDouble();
    double charBasedWords = charCount / 5.0;
    
    // Use whichever is larger to account for lines with few but very long words
    if (charBasedWords > effectiveWords) {
      effectiveWords = charBasedWords;
    }
    
    // Add a base padding (e.g. 1.5 words) to every line to account for eye 
    // movement/transition time, ensuring very short lines aren't too fast.
    effectiveWords += 1.5;
    
    // Duration formula based on effective words
    int durationMs = ((effectiveWords / _wpm) * 60000).toInt();

    _timer = Timer(Duration(milliseconds: durationMs), () {
      if (!mounted) return;
      bool advanced = appState.nextLine();
      
      if (!advanced) {
        _togglePlayPause(); // Pause automatically at the end of the page
      } else {
        _scheduleNextLine();
      }
    });
  }

  void _updateSpeed(double newWpm) {
    setState(() {
      _wpm = newWpm.toInt();
    });
    Hive.box('settingsBox').put('wpm', _wpm);
    if (_isPlaying) {
      _startTimer(); // Restarts timer instantly with the new duration
    }
  }

  void _toggleOrientation() {
    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _updateSystemUI(bool isLandscape) {
    if (!isMobile) return;
    if (isLandscape && !_controlsVisible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _resetHideControlsTimer(bool isLandscape) {
    // No longer auto-hiding after 3 seconds.
  }

  void _handleScreenTap(bool isLandscape) {
    if (!isLandscape) return;
    setState(() => _controlsVisible = !_controlsVisible);
    _updateSystemUI(isLandscape);
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Consumer<AppState>(
          builder: (context, appState, child) {
            final isDark = appState.isDarkMode;
            return Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161616) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Text Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(
                          children: [
                            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: appState.decreaseFontSize, color: Theme.of(context).colorScheme.primary),
                            SizedBox(width: 50, child: Text('${appState.fontSize.toInt()}px', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: appState.increaseFontSize, color: Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: appState.currentPageIndex.toDouble().clamp(0.0, appState.currentBookPages.length > 1 ? (appState.currentBookPages.length - 1).toDouble() : 1.0),
                            min: 0,
                            max: appState.currentBookPages.length > 1 ? (appState.currentBookPages.length - 1).toDouble() : 1.0,
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor: isDark ? Colors.grey.shade800 : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            onChanged: appState.currentBookPages.length > 1 ? (value) => appState.jumpToPage(value.toInt()) : null,
                          ),
                        ),
                        SizedBox(width: 60, child: Text('${appState.currentPageIndex + 1} / ${appState.currentBookPages.length}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      ],
                    ),
                    const Divider(height: 16),
                    StatefulBuilder(
                      builder: (context, setSheetState) {
                        return Column(
                          children: [
                            Text('Speed: $_wpm WPM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Slider(
                              value: _wpm.toDouble(),
                              min: 50, max: 1000,
                              activeColor: Theme.of(context).colorScheme.primary,
                              onChanged: (val) {
                                setSheetState(() => _wpm = val.toInt());
                                _updateSpeed(val);
                              },
                            ),
                          ],
                        );
                      }
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Slow (50)', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          Text('Fast (1000)', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;

    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = isMobile && orientation == Orientation.landscape;

    bool layoutChanged = false;
    if (_lastOrientation != orientation || _lastFontSize != appState.fontSize) {
      _lastOrientation = orientation;
      _lastFontSize = appState.fontSize;
      layoutChanged = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _controlsVisible = true);
        _resetHideControlsTimer(isLandscape);
      });
    }

    if (appState.currentBookPages.isEmpty) {
      return Scaffold(
        appBar: (isLandscape && !_controlsVisible) ? null :
        AppBar(title: const Text('Empty File'), backgroundColor: Theme.of(context).colorScheme.primary),
        body: const Center(child: Text('No readable text could be extracted.')),
      );
    }

    final currentPage = appState.currentBookPages[appState.currentPageIndex];
    final progress = appState.currentLineIndex / (currentPage.length > 1 ? currentPage.length - 1 : 1);

    // Check if line or page changed to animate the scroll list
    if (_lastPageIndex != appState.currentPageIndex) {
      _lastPageIndex = appState.currentPageIndex;
      _lastLineIndex = appState.currentLineIndex;
      
      _isPageReady = false; // Hide the list temporarily
      
      void jump() {
        if (!mounted) return;
        if (_itemScrollController.isAttached) {
          double align = 0.35;
          _itemScrollController.jumpTo(index: appState.currentLineIndex, alignment: align);
          if (!_isInitialScrollDone) {
            _isInitialScrollDone = true;
          }
          setState(() => _isPageReady = true);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) => jump());
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
      
    } else if (_isInitialScrollDone && (_lastLineIndex != appState.currentLineIndex || layoutChanged)) {
      int oldLine = _lastLineIndex;
      _lastLineIndex = appState.currentLineIndex;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_itemScrollController.isAttached) {
          double align = 0.35;
          
          if (layoutChanged || (oldLine - appState.currentLineIndex).abs() > 2) {
             _itemScrollController.jumpTo(index: appState.currentLineIndex, alignment: align);
          } else {
            _itemScrollController.scrollTo(
              index: appState.currentLineIndex,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              alignment: align,
            );
          }
        }
      });
    }

    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = isDark 
        ? Color.alphaBlend(primaryColor.withValues(alpha: 0.04), const Color(0xFF09090B))
        : Color.alphaBlend(primaryColor.withValues(alpha: 0.04), const Color(0xFFFAFAFA));

    return KeyboardListener(
    focusNode: _keyboardFocusNode,
    autofocus: !isMobile, // was: isDesktop
    onKeyEvent: _handleKeyEvent,
    child : Scaffold(
    backgroundColor: bgColor,
    extendBodyBehindAppBar: true,
    appBar: PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight),
    child: IgnorePointer(
      ignoring: isLandscape && !_controlsVisible,
      child: AnimatedOpacity(
        opacity: (isLandscape && !_controlsVisible) ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        child: AppBar(
          title: Text(
            appState.currentBookTitle, 
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
          if (!isMobile)
          IconButton(
            icon: const Icon(Icons.keyboard_command_key_rounded),
            tooltip: 'Keyboard Shortcuts',
            onPressed: () => showKeyboardShortcutsDialog(context),
          ),
          if(isLandscape)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text(
              'Line ${appState.currentLineIndex + 1} of ${currentPage.length}',
              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Theme.of(context).colorScheme.primary, fontSize: isMobile ? 12:16),
            ),
          ),
          ThemePickerButton(
            appState: appState, 
            isDark: isDark, 
            customIconSize: isMobile ? 24 : 26,
          ),
          IconButton(
            iconSize: isMobile ? 24 : 26,
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: (){
              appState.toggleTheme();
            },
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            iconSize: isMobile ? 22 : 28,
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: (){
              appState.previousPage();
            },
            tooltip: 'Previous Page',
          ),
          Center(
            child: Text(
              'Page ${appState.currentPageIndex + 1} / ${appState.currentBookPages.length}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 12:16),
            ),
          ),
          IconButton(
            iconSize: isMobile ? 22 : 28,
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: (){
              appState.nextPage();
            },
            tooltip: 'Next Page',
          ),
          SizedBox(width: isMobile ? 6:8),
        ],
      ),
    ),
  ),
      ),
      body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: ()=> _handleScreenTap(isLandscape),
          onVerticalDragStart: (_) => _dragAccumulator = 0.0,
          onVerticalDragUpdate: (details) {
            _dragAccumulator -= details.primaryDelta ?? 0.0;
            if (_dragAccumulator > _dragThreshold) {
              appState.nextLine();
              if (_isPlaying) _scheduleNextLine();
              _dragAccumulator = 0.0;
            } else if (_dragAccumulator < -_dragThreshold) {
              appState.previousLine();
              if (_isPlaying) _scheduleNextLine();
              _dragAccumulator = 0.0;
            }
          },
          child: Stack(
            children:[
              // Premium Background Glows
              Positioned(
                top: -150,
                right: -100,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: isDark ? 0.08 : 0.08),
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
                    color: primaryColor.withValues(alpha: isDark ? 0.05 : 0.05),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              Column(
          children: [
            if(!isLandscape)
            LinearProgressIndicator(value: progress, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), color: Theme.of(context).colorScheme.primary),
            
            Expanded(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _isPageReady ? 1.0 : 0.0,
                    child: ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                    itemPositionsListener: _itemPositionsListener,
                    initialScrollIndex: appState.currentLineIndex,
                    initialAlignment: 0.35,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).size.height * 0.35,
                      bottom: MediaQuery.of(context).size.height * 0.65,
                    ),
                    itemCount: currentPage.length,
                  itemBuilder: (context, index) {
                    final line = currentPage[index];
                    final isActive = index == appState.currentLineIndex;
                    final distance = (index - appState.currentLineIndex).abs();
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: distance > 1 ? 0.0 : (isActive ? 1.0 : 0.6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: isActive ? 0.0 : 0.8, 
                            end: isActive ? 0.0 : 0.8
                          ),
                          duration: const Duration(milliseconds: 300),
                          builder: (context, blurValue, child) {
                            return ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                              child: child,
                            );
                          },
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 300),
                            scale: isActive ? 1.0 : 0.85,
                            curve: Curves.easeOutCubic,
                            child: Text(
                              line,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lora(
                                fontSize: appState.fontSize,
                                height: 1.6,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                color: isActive 
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              ),
              ),
            ),
            ]),
              // Floating Controls Pill
              Positioned(
                left: 0, right: 0, bottom: isLandscape ? 16 : 32,
                child: IgnorePointer(
                  ignoring: isLandscape && !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: (isLandscape && !_controlsVisible) ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                            IconButton(
                              iconSize: 24,
                              icon: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.onSurface),
                              onPressed: () => _showSettingsSheet(context),
                              tooltip: 'Settings',
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              iconSize: 28,
                              icon: Icon(Icons.fast_rewind_rounded, color: Theme.of(context).colorScheme.primary),
                              onPressed: () { 
                                appState.previousLine(); 
                                if (_isPlaying) _scheduleNextLine();
                              },
                            ),
                            const SizedBox(width: 8),
                            FloatingActionButton(
                              onPressed: () { _togglePlayPause(); },
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const CircleBorder(),
                              child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              iconSize: 28,
                              icon: Icon(Icons.fast_forward_rounded, color: Theme.of(context).colorScheme.primary),
                              onPressed: () { 
                                appState.nextLine(); 
                                if (_isPlaying) _scheduleNextLine();
                              },
                            ),
                            if (isMobile) ...[
                              const SizedBox(width: 16),
                              IconButton(
                                iconSize: 24,
                                icon: Icon(Icons.screen_rotation_rounded, color: Theme.of(context).colorScheme.onSurface),
                                onPressed: _toggleOrientation,
                                tooltip: 'Rotate',
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                    ),
                  ),
                ),
              ),
              if (!_isPlaying && appState.currentLineIndex == currentPage.length - 1)
                Positioned(
                  bottom: isLandscape ? 100 : 140, // Moved higher up
                  left: 0, right: 0,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark 
                                ? primaryColor.withValues(alpha: 0.25) 
                                : primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: isDark ? 0.4 : 0.3),
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                appState.nextPage();
                                if (!_isPlaying) {
                                  _togglePlayPause();
                                } else {
                                  _scheduleNextLine();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.menu_book_rounded, 
                                      size: 20, 
                                      color: isDark ? primaryColor : primaryColor.withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Start Next Page', 
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700, 
                                        fontSize: 15,
                                        color: isDark ? primaryColor : primaryColor.withValues(alpha: 0.9),
                                        letterSpacing: -0.3,
                                      )
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ));
  }
}