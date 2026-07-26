import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../dashboard/dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _completeOnboarding(BuildContext context) {
    // Save to Hive that the user has completed onboarding
    Hive.box('settingsBox').put('hasSeenOnboarding', true);

    // Navigate to Dashboard and remove Onboarding from the backstack
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: const [
                  _OnboardingPage(
                    icon: Icons.visibility,
                    title: 'Read Without Moving Your Eyes',
                    description: 'Linea uses RSVP (Rapid Serial Visual Presentation) to flash text 6 words at a time. This eliminates eye movement and drastically increases your reading speed.',
                  ),
                  _OnboardingPage(
                    icon: Icons.speed,
                    title: 'Control Your Pace',
                    description: 'Adjust the seconds-per-line speed on the fly. Start slow to get used to the rhythm, then crank it up as your brain adapts.',
                  ),
                  _OnboardingPage(
                    icon: Icons.library_books,
                    title: 'Your Books, Everywhere',
                    description: 'Import any PDF or EPUB. Linea strips out the junk, formats it perfectly, and always remembers exactly what line you left off on.',
                  ),
                ],
              ),
            ),
            
            // Bottom Controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators
                  Row(
                    children: List.generate(
                      3,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 10,
                        width: _currentPage == index ? 24 : 10,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? Colors.teal : Colors.teal.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  
                  // Next / Get Started Button
                  FilledButton(
                    onPressed: () {
                      if (_currentPage == 2) {
                        _completeOnboarding(context);
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(_currentPage == 2 ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.teal),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          const SizedBox(height: 24),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}