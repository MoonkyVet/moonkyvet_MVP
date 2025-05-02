import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 👈 ascultăm ciclul de viață

    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _checkSubscriptionStatus(); // inițial, verificăm dacă e deja activ
  }

  @override
  void dispose() {
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this); // curățăm observatorul
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSubscriptionStatus(); // 👈 verifică din nou când utilizatorul revine în app
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/');
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final active = doc.data()?['subscriptionActive'] == true;

    if (active && mounted) {
      Navigator.pushReplacementNamed(context, '/subscription-success');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.5 + 0.2 * _controller.value, 1.0],
                    colors: [
                      Colors.black,
                      Colors.teal.withOpacity(0.5 + 0.3 * _controller.value),
                      Colors.black,
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  FadeInDown(
                    child: const Text(
                      'Activează Acces Complet 🚀',
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeInDown(
                    delay: Duration(milliseconds: 200),
                    child: const Text(
                      'Upgrade pentru a debloca funcționalitățile premium',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeIn(
                    delay: Duration(milliseconds: 400),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/subscription_page.png',
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _animatedBenefit('🐶 Sfaturi personalizate AI pentru animale', 600),
                  _animatedBenefit('📍 Găsește cei mai buni veterinari din apropiere', 800),
                  _animatedBenefit('💬 Acces nelimitat la chatbot-ul Moonky', 1000),
                  _animatedBenefit('📅 Programări prioritare la consultații', 1200),
                  _animatedBenefit('🎁 Oferte și cadouri exclusive lunar', 1400),
                  const SizedBox(height: 40),
                  FadeInUp(
                    delay: Duration(milliseconds: 1600),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.tealAccent, width: 1.5),
                      ),
                      child: Column(
                        children: const [
                          Text(
                            'Doar 10 RON/lună',
                            style: TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Poți anula oricând. Fără taxe ascunse.',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeInUp(
                    delay: Duration(milliseconds: 1800),
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Trebuie să fii autentificat.')),
                          );
                          return;
                        }

                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Se deschide pagina de plata...')),
                          );

                          final callable = FirebaseFunctions.instance.httpsCallable('createCheckoutSession');
                          final result = await callable();
                          final checkoutUrl = result.data['url'];

                          if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
                            await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Nu s-a putut deschide pagina Stripe')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Eroare la pornirea abonamentului: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Abonează-te'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInUp(
                    delay: Duration(milliseconds: 2000),
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/home');
                      },
                      child: const Text(
                        'Poate mai târziu',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedBenefit(String text, int delay) {
    return FadeInLeft(
      delay: Duration(milliseconds: delay),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.tealAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
