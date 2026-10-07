import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/app_state.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:ui';
import '../../../core/widgets/keyboard_shortcuts_dialog.dart';

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
  // Speed setting: milliseconds per line. Default is 2500ms (2.5 seconds per line)
  int _speedMs = Hive.box('settingsBox').get('speedMs', defaultValue: 2500); 

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _lastLineIndex = -1;
  int _lastPageIndex = -1;

  @override
  void dispose() {
    _timer?.cancel();
    _hideControlsTimer?.cancel();
    _keyboardFocusNode.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
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
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      appState.previousLine();
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
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _speedMs), (timer) {
      final appState = context.read<AppState>();
      
      bool advanced = appState.nextLine();
      
      if (!advanced) {
        _togglePlayPause(); // Pause automatically at the end of the page
      }
    });
  }

  void _updateSpeed(double newSpeedMs) {
    setState(() {
      _speedMs = newSpeedMs.toInt();
    });
    Hive.box('settingsBox').put('speedMs', _speedMs);
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
  _hideControlsTimer?.cancel();
  if (isLandscape) {
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _controlsVisible = false);
        _updateSystemUI(isLandscape);
      });
    }
  }

  void _handleScreenTap(bool isLandscape) {
    if (!isLandscape) return;
    setState(() => _controlsVisible = true);
    _updateSystemUI(isLandscape);
    _resetHideControlsTimer(true);
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
            final double secondsPerLine = _speedMs / 1000;
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
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
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
                    Text('Speed: ${secondsPerLine.toStringAsFixed(1)}s / line', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    StatefulBuilder(
                      builder: (context, setSheetState) {
                        return Slider(
                          value: _speedMs.toDouble(),
                          min: 500, max: 6000,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) {
                            setSheetState(() => _speedMs = val.toInt());
                            _updateSpeed(val);
                          },
                        );
                      }
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Fast (0.5s)', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          Text('Slow (6.0s)', style: TextStyle(color: Colors.grey, fontSize: 14)),
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

    if (_lastOrientation != orientation) {
      _lastOrientation = orientation;
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

    // Calculate seconds per line and lines per second for the UI label
    final double secondsPerLine = _speedMs / 1000;

    // Check if line or page changed to animate the scroll list
    if (_lastLineIndex != appState.currentLineIndex || _lastPageIndex != appState.currentPageIndex) {
      if (_itemScrollController.isAttached) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_itemScrollController.isAttached) {
            _itemScrollController.scrollTo(
              index: appState.currentLineIndex,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.35, // Visually shift higher to balance the bottom pill
            );
          }
        });
      }
      _lastLineIndex = appState.currentLineIndex;
      _lastPageIndex = appState.currentPageIndex;
    }

    return KeyboardListener(
    focusNode: _keyboardFocusNode,
    autofocus: !isMobile, // was: isDesktop
    onKeyEvent: _handleKeyEvent,
    child : Scaffold(
    appBar: PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight),
    child: IgnorePointer(
      ignoring: isLandscape && !_controlsVisible,
      child: AnimatedOpacity(
        opacity: (isLandscape && !_controlsVisible) ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        child: AppBar(
          title: Text(appState.currentBookTitle),
          backgroundColor: isDark ? Colors.grey.shade900 : Theme.of(context).colorScheme.secondaryContainer,
          actions: [
          if (!isMobile)
          IconButton(
            icon: const Icon(Icons.help_outline),
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
          PopupMenuButton<int>(
            iconSize: isMobile ? 24 : 26,
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Change Accent Color',
            onOpened: () => _handleScreenTap(isLandscape),
            onSelected: (index) {
              appState.setThemeColor(index);
              _handleScreenTap(isLandscape);
            },
            itemBuilder: (context) => [
              for (int i = 0; i < AppState.themeColors.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Row(
                    children: [
                      Container(
                        width: isMobile ? 18:24,
                        height: isMobile ? 18:24,
                        decoration: BoxDecoration(
                          color: AppState.themeColors[i],
                          shape: BoxShape.circle,
                          border: appState.colorIndex == i
                              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
                              : null,
                        ),
                      ),
                      SizedBox(width: isMobile ? 8:12),
                      Text(['Mint', 'Purple', 'Royal Blue', 'Coral', 'Sage'][i]),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            iconSize: isMobile ? 24 : 26,
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: (){
              appState.toggleTheme();
              _handleScreenTap(isLandscape);
            },
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            iconSize: isMobile ? 18 : 24,
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: (){
              appState.previousPage();
              _handleScreenTap(isLandscape);
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
            iconSize: isMobile ? 18 : 24,
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: (){
              appState.nextPage();
              _handleScreenTap(isLandscape);
            },
            tooltip: 'Next Page',
          ),
          SizedBox(width: isMobile ? 6:8),
        ],
      ),
    ),
  ),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: ()=> _handleScreenTap(isLandscape),
          child: Stack(
            children:[
              Column(
          children: [
            if(!isLandscape)
            LinearProgressIndicator(value: progress, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), color: Theme.of(context).colorScheme.primary),
            
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
                  child: ScrollablePositionedList.builder(
                    itemScrollController: _itemScrollController,
                    itemPositionsListener: _itemPositionsListener,
                    initialScrollIndex: appState.currentLineIndex,
                    initialAlignment: 0.35,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.5),
                    itemCount: currentPage.length,
                  itemBuilder: (context, index) {
                    final line = currentPage[index];
                    final isActive = index == appState.currentLineIndex;
                    final distance = (index - appState.currentLineIndex).abs();
                    
                    return GestureDetector(
                      onTap: () {
                         appState.jumpToLine(index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: distance > 1 ? 0.0 : (isActive ? 1.0 : 0.4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: isActive ? 0.0 : 2.0, 
                              end: isActive ? 0.0 : 2.0
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
                              scale: isActive ? 1.0 : 0.7,
                              curve: Curves.easeOutCubic,
                              child: Text(
                                line,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: appState.fontSize, // Fixed layout size prevents jumpiness!
                                  height: 1.4,
                                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
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
                              color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
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
                                color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
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
                              onPressed: () { appState.previousLine(); _handleScreenTap(isLandscape); },
                            ),
                            const SizedBox(width: 8),
                            FloatingActionButton(
                              onPressed: () { _togglePlayPause(); _handleScreenTap(isLandscape); },
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
                              onPressed: () { appState.nextLine(); _handleScreenTap(isLandscape); },
                            ),
                            if (!isLandscape && isMobile) ...[
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
                  bottom: isLandscape ? 100 : 120,
                  left: 0, right: 0,
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: appState.nextPage,
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Start Next Page'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ));
  }
}