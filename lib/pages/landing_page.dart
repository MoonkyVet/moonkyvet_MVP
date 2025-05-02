import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'oboarding_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  bool showLoginOptions = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7F5AF0), Color(0xFF5E60CE)],
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.5)),

          // Content
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Title
                    // Mascot + description
                    Column(
                      children: [
                        Image.asset(
                          'assets/onboarding/mascot.png',
                          height: 170,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Primul asistent veterinar AI din România!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Descoperă o aplicație completă pentru sănătatea și bunăstarea animalului tău. Consultă AI-ul Moonky sau discută direct cu medici veterinari reali.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Animated Description
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 600),
                      crossFadeState: showLoginOptions ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      firstChild: const Text(
                        'Primul asistent veterinar AI din România!\n\n'
                            'Găsește rapid cei mai buni veterinari din zona ta, discută online cu specialiști acreditați și urmărește sănătatea animalelor tale cu ajutorul inteligenței artificiale.\n\n'
                            'Tot ce ai nevoie pentru grijă completă, într-o singură aplicație.',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      secondChild: const SizedBox.shrink(), // dispare descrierea
                    ),
                    const SizedBox(height: 40),

                    // Animated Button
                    if (!showLoginOptions)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            showLoginOptions = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                        child: const Text(
                          'Continuă',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('onboarding_seen');
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const OnboardingPage()),
                        );
                      },
                      child: const Text(
                        'Reset Onboarding',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    // Login Options Animated
                    AnimatedOpacity(
                      opacity: showLoginOptions ? 1 : 0,
                      duration: const Duration(milliseconds: 600),
                      child: AnimatedSlide(
                        offset: showLoginOptions ? Offset.zero : const Offset(0, 0.5),
                        duration: const Duration(milliseconds: 600),
                        child: Column(
                          children: [
                            const Text(
                              'Cu cine avem plăcerea?',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30),
                            _RoleCard(
                              icon: Icons.pets,
                              label: 'Intră ca Stăpân de Animal',
                              onTap: () => Navigator.pushNamed(context, '/owner-access'),
                            ),
                            const SizedBox(height: 20),
                            _RoleCard(
                              icon: Icons.medical_services_outlined,
                              label: 'Intră ca Veterinar',
                              onTap: () => Navigator.pushNamed(context, '/vet-access'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
