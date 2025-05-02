// 📄 signup_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'home_page.dart';
import 'email_verification.dart'; // <-- ADĂUGAT
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final auth = AuthService();
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _checkLoggedInUser();
  }

  Future<void> _checkLoggedInUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userSnapshot = await userDoc.get();

      final bool subscriptionActive = userSnapshot.data()?['subscriptionActive'] ?? false;

      if (subscriptionActive) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/subscription');
      }
    }
  }


  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final user = await auth.signUp(
        emailController.text.trim(),
        passController.text.trim(),
      );

      if (user != null) {
        // 🔥 Creează document Firestore
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userSnapshot = await userDoc.get();

        if (!userSnapshot.exists) {
          await userDoc.set({
            'email': user.email,
            'subscriptionActive': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (!user.emailVerified) {
          await user.sendEmailVerification();
          await Future.delayed(const Duration(seconds: 1)); // evită throttling
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cont creat cu succes! Verifică-ți emailul.'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
          );
        }
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message;
        switch (e.code) {
          case 'email-already-in-use':
            message = 'Acest email este deja folosit.';
            break;
          case 'invalid-email':
            message = 'Emailul introdus nu este valid.';
            break;
          case 'weak-password':
            message = 'Parola este prea slabă. Folosește cel puțin 6 caractere.';
            break;
          case 'operation-not-allowed':
            message = 'Registrarea cu email/parolă nu este permisă.';
            break;
          case 'too-many-requests':
            message = 'Prea multe încercări. Încearcă mai târziu.';
            break;
          default:
            message = 'Eroare necunoscută: ${e.message}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eroare neașteptată. Încearcă din nou.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);

    try {
      final user = await auth.signInWithGoogle();
      if (user != null) {
        // 🔥 Creează document Firestore dacă nu există
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userSnapshot = await userDoc.get();

        if (!userSnapshot.exists) {
          await userDoc.set({
            'email': user.email,
            'subscriptionActive': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Autentificat cu Google ca ${user.displayName ?? user.email}')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      setState(() => errorMessage = 'Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Creează Cont', style:TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Creează un cont nou',
                      style: TextStyle(fontSize: 22, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle('Email'),
                      validator: (val) => val == null || val.isEmpty ? 'Introduceți emailul' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle('Parolă'),
                      validator: (val) => val != null && val.length >= 6 ? null : 'Minim 6 caractere',
                    ),
                    const SizedBox(height: 24),

                    const SizedBox(height: 12),
                    isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _register,
                      child: const Text('Creează cont'),
                    ),
                    const SizedBox(height: 24),
                    const Text('sau autentifică-te cu Google', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                    IconButton(
                      icon: Image.asset('assets/google_icon.png', height: 36, width: 36),
                      onPressed: _signInWithGoogle,
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputStyle(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: Colors.white12,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}