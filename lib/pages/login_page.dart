import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'home_page.dart';
import 'signup_page.dart';
import 'subscription_page.dart'; // 🔥 importă și SubscriptionPage
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/vet/vet_home_page.dart'; // sau unde ai salvat vet_home_page.dart

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final auth = AuthService();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoggedInUser();
  }

  Future<void> _checkLoggedInUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) {
      await _navigateBasedOnSubscription(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/');
          },
        ),
        title: const Text(
          'Login',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/login_background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.85)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Welcome Back! 👋',
                    style: TextStyle(fontSize: 22, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  _darkInput(emailController, 'Email'),
                  const SizedBox(height: 16),
                  _darkInput(passController, 'Password', obscure: true),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _handleEmailPasswordLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      child: Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('or login with Google', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 10),
                  IconButton(
                    icon: Image.asset('assets/google_icon.png', height: 36, width: 36),
                    onPressed: _handleGoogleLogin,
                  ),
                  const SizedBox(height: 30),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      );
                    },
                    child: const Text("Don't have an account? Sign up", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _darkInput(TextEditingController controller, String label, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }



  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await auth.signInWithGoogle();
      if (user != null) {
        await _navigateBasedOnSubscription(user);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Future<void> _handleEmailPasswordLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await auth.signIn(
        emailController.text.trim(),
        passController.text.trim(),
      );

      if (user != null) {
        // Verificăm dacă utilizatorul este un veterinar
        await _navigateBasedOnSubscription(user);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateBasedOnSubscription(User user) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userSnapshot = await userDoc.get();

    if (!userSnapshot.exists) {
      await userDoc.set({
        'email': user.email,
        'subscriptionActive': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final bool subscriptionActive = userSnapshot.data()?['subscriptionActive'] ?? false;

    // Verificăm dacă utilizatorul este veterinar
    final vetDoc = await FirebaseFirestore.instance.collection('vets').doc(user.uid).get();
    if (vetDoc.exists) {
      // Dacă este veterinar, îl redirecționăm direct pe VetHomePage
      _navigateWithSlide(context, const VetHomePage());
      return;
    }

    // Dacă nu este veterinar, verificăm statusul subscripției
    if (subscriptionActive) {
      _navigateWithSlide(context, const HomePage());
    } else {
      Navigator.pushReplacementNamed(context, '/subscription');
    }
  }

  void _navigateWithSlide(BuildContext context, Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offsetAnimation = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

}
