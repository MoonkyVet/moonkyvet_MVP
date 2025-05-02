import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'landing_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key? key}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> onboardingData = [
    {
      'title': 'Bine ai venit în lumea Moonky!',
      'subtitle': 'Primul asistent AI creat special pentru câini. Înțelege. Ajută. Ghidează.',
      'asset': 'assets/onboarding/mascot.png',
    },
    {
      'title': 'Totul într-un singur loc',
      'subtitle': 'Jurnal, vaccinări, tratamente – urmărește cu ușurință evoluția câinelui tău.',
      'asset': 'assets/onboarding/all_at_once.png',
    },
    {
      'title': 'Găsește veterinari reali',
      'subtitle': 'Clinici veterinare din apropiere + consult online cu specialiști verificați.',
      'asset': 'assets/onboarding/find_real_vets.png',
    },
    {
      'title': 'Consultă AI-ul Moonky',
      'subtitle': 'Obține sfaturi rapide despre nutriție, sănătate și comportament.',
      'asset': 'assets/onboarding/veterinar_ai.png',
    },
  ];


  void _nextPage() {
    if (_currentIndex < onboardingData.length) {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _skip() {
    _controller.jumpToPage(onboardingData.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: onboardingData.length + 1,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              if (index == onboardingData.length) {
                return _buildFinalLanding();
              }
              final item = onboardingData[index];
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7F5AF0), Color(0xFF5E60CE)],
                  ),
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(item['asset']!, height: 240),
                    const SizedBox(height: 40),
                    Text(item['title']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        )),
                    const SizedBox(height: 20),
                    Text(item['subtitle']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  ],
                ),
              );
            },
          ),

          if (_currentIndex < onboardingData.length)
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: _skip,
                child: const Text("Skip",
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                onboardingData.length + 1,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 16 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 32,
            right: 32,
            child: _currentIndex < onboardingData.length
                ? ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Continuă", style: TextStyle(fontSize: 16)),
            )
                : const SizedBox.shrink(),
          )
        ],
      ),
    );
  }

  Widget _buildFinalLanding() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7F5AF0), Color(0xFF5E60CE)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/onboarding/mascot.png', // mascotele tale fără fundal
            height: 200,
          ),
          const SizedBox(height: 40),
          const Text(
            "Ești pregătit să ai grijă de cățelul tău cu ajutorul Moonky?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Haide să începem!",
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('onboarding_seen', true);

              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 800),
                  pageBuilder: (_, __, ___) => const LandingPage(),
                  transitionsBuilder: (_, animation, __, child) {
                    final fade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ));
                    final slide = Tween<Offset>(
                      begin: const Offset(0.0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ));

                    return FadeTransition(
                      opacity: fade,
                      child: SlideTransition(
                        position: slide,
                        child: child,
                      ),
                    );
                  },
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text("Să începem!", style: TextStyle(fontSize: 18)),
          )

        ],
      ),
    );
  }
}