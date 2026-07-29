import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/app_state.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
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
    final currentLine = currentPage[appState.currentLineIndex];
    final progress = appState.currentLineIndex / (currentPage.length > 1 ? currentPage.length - 1 : 1);

    // Calculate seconds per line and lines per second for the UI label
    final double secondsPerLine = _speedMs / 1000;

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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text(
              'Line ${appState.currentLineIndex + 1} of ${currentPage.length}',
              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade800:Theme.of(context).colorScheme.primary, fontSize: isMobile ? 12:16),
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
                      Text(['Teal', 'Purple', 'Indigo', 'Rose Wood', 'Slate'][i]),
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
                child: Align(
                alignment: Alignment(0, isLandscape ? -0.15 : 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    currentLine,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: appState.fontSize, // Dynamic font size
                      height: 1.5, 
                      fontWeight: FontWeight.w500
                    ),
                  ),
                ),
              ),
            ),
            if(!isLandscape)...[
            if (!_isPlaying && appState.currentLineIndex == currentPage.length - 1)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: FilledButton.icon(
                  onPressed: appState.nextPage,
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Start Next Page'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                ),
              ),
            Container(
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: !_isPlaying
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                  // --- New Font Size Controls ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Text Size',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 14:16),
                      ),
                      Row(
                        children: [
                          IconButton(
                            iconSize: isMobile ? 22:28,
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: appState.decreaseFontSize,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(
                            width: 50,
                            child: Text(
                              '${appState.fontSize.toInt()}px',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 14:16),
                            ),
                          ),
                          IconButton(
                            iconSize: isMobile ? 22:28,
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: appState.increaseFontSize,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // --- New Page Jump Slider ---
                  Row(
                    children: [
                      Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          // Clamp the value to ensure it never exceeds max if the layout shifts
                          value: appState.currentPageIndex.toDouble().clamp(
                            0.0, 
                            appState.currentBookPages.length > 1 
                                ? (appState.currentBookPages.length - 1).toDouble() 
                                : 1.0
                          ),
                          min: 0,
                          max: appState.currentBookPages.length > 1 
                                ? (appState.currentBookPages.length - 1).toDouble() 
                                : 1.0,
                          activeColor: Theme.of(context).colorScheme.primary,
                          inactiveColor: isDark ? Colors.grey.shade800 : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          // Disable slider if there's only 1 page
                          onChanged: appState.currentBookPages.length > 1 
                            ? (value) => appState.jumpToPage(value.toInt()) 
                            : null,
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${appState.currentPageIndex + 1} / ${appState.currentBookPages.length}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  
                  const Divider(height: 16),
                  // Speed Display in Seconds / Lines per second
                  Text(
                    'Speed: ${secondsPerLine.toStringAsFixed(1)}s / line',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 14:16),
                  ),
                  
                  // Speed Slider (Range from 500ms [Fast] to 6000ms [Slow])
                  Slider(
                    value: _speedMs.toDouble(),
                    min: 500,
                    max: 6000,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: _updateSpeed,
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fast (0.5s)', style: TextStyle(color: const Color.fromARGB(255, 131, 131, 131), fontSize: isMobile ? 12:16)),
                        Text('Slow (6.0s)', style: TextStyle(color: const Color.fromARGB(255, 131, 131, 131), fontSize: isMobile ? 12:16)),
                      ],
                    ),
                  ),
                
                  const SizedBox(height: 16),
                  ],
                          )
                        : const SizedBox.shrink(), // Shrinks smoothly when playing
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 32,
                        icon: Icon(Icons.fast_rewind, color: Theme.of(context).colorScheme.primary),
                        onPressed: appState.previousLine,
                      ),
                      const SizedBox(width: 24),
                      
                      isMobile ? FloatingActionButton(
                        onPressed: _togglePlayPause,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      ) : 
                      FloatingActionButton.large(
                        onPressed: _togglePlayPause,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      ),
                      
                      const SizedBox(width: 24),
                      IconButton(
                        iconSize: 32,
                        icon: Icon(Icons.fast_forward, color: Theme.of(context).colorScheme.primary),
                        onPressed: appState.nextLine,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      'Line ${appState.currentLineIndex + 1} of ${currentPage.length}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: isMobile ? 12:16),
                    ),
                  )
                ],
              ),
            ),
          ],
        ],
        ),
        if (isLandscape)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 32,
                      icon: Icon(Icons.fast_rewind, color: Theme.of(context).colorScheme.primary),
                      onPressed: (){
                        appState.previousLine();
                        _handleScreenTap(isLandscape);
                      }
                    ),
                    const SizedBox(width: 24),
                    FloatingActionButton(
                      onPressed: (){
                        _togglePlayPause();
                        _handleScreenTap(isLandscape);
                      },
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      iconSize: 32,
                      icon: Icon(Icons.fast_forward, color: Theme.of(context).colorScheme.primary),
                      onPressed: (){
                        appState.nextLine();
                        _handleScreenTap(isLandscape);
                      }
                    ),
                  ],
                  ),
                  Positioned(
                    right: 16,
                    child:FloatingActionButton.small(
                      onPressed: _toggleOrientation,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                      child: const Icon(Icons.screen_rotation),
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),  
      
  floatingActionButton: (!isLandscape && isMobile)
      ? FloatingActionButton.small(
          onPressed: _toggleOrientation,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: const Icon(Icons.screen_rotation),
        )
      : null,
    ),
    );
  }
}