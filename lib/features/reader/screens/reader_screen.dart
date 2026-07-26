import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/app_state.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  Timer? _timer;
  bool _isPlaying = false;
  
  // Speed setting: milliseconds per line. Default is 2500ms (2.5 seconds per line)
  int _speedMs = Hive.box('settingsBox').get('speedMs', defaultValue: 2500); 

  @override
  void dispose() {
    _timer?.cancel(); 
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;

    if (appState.currentBookPages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Empty File'), backgroundColor: Colors.teal.shade50),
        body: const Center(child: Text('No readable text could be extracted.')),
      );
    }

    final currentPage = appState.currentBookPages[appState.currentPageIndex];
    final currentLine = currentPage[appState.currentLineIndex];
    final progress = appState.currentLineIndex / (currentPage.length > 1 ? currentPage.length - 1 : 1);

    // Calculate seconds per line and lines per second for the UI label
    final double secondsPerLine = _speedMs / 1000;

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.currentBookTitle),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.teal.shade50,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: appState.toggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: appState.previousPage,
            tooltip: 'Previous Page',
          ),
          Center(
            child: Text(
              'Page ${appState.currentPageIndex + 1} / ${appState.currentBookPages.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: appState.nextPage,
            tooltip: 'Next Page',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade300, color: Colors.teal),
            
            Expanded(
              child: Center(
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
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.teal.shade50,
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
                      const Text(
                        'Text Size',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: appState.decreaseFontSize,
                            color: Colors.teal,
                          ),
                          SizedBox(
                            width: 50,
                            child: Text(
                              '${appState.fontSize.toInt()}px',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: appState.increaseFontSize,
                            color: Colors.teal,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // --- New Page Jump Slider ---
                  Row(
                    children: [
                      const Icon(Icons.menu_book, color: Colors.teal, size: 20),
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
                          activeColor: Colors.teal.shade300,
                          inactiveColor: isDark ? Colors.grey.shade800 : Colors.teal.shade100,
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  
                  // Speed Slider (Range from 500ms [Fast] to 6000ms [Slow])
                  Slider(
                    value: _speedMs.toDouble(),
                    min: 500,
                    max: 6000,
                    activeColor: Colors.teal,
                    onChanged: _updateSpeed,
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fast (0.5s)', style: TextStyle(color: Colors.grey)),
                        Text('Slow (6.0s)', style: TextStyle(color: Colors.grey)),
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
                        icon: const Icon(Icons.fast_rewind, color: Colors.teal),
                        onPressed: appState.previousLine,
                      ),
                      const SizedBox(width: 24),
                      
                      FloatingActionButton.large(
                        onPressed: _togglePlayPause,
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      ),
                      
                      const SizedBox(width: 24),
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.fast_forward, color: Colors.teal),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}