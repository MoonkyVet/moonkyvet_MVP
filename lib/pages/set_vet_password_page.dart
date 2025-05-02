import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class SetVetPasswordPage extends StatefulWidget {
  final Map<String, dynamic> vetData;

  const SetVetPasswordPage({super.key, required this.vetData});

  @override
  State<SetVetPasswordPage> createState() => _SetVetPasswordPageState();
}

class _SetVetPasswordPageState extends State<SetVetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createVetAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final email = widget.vetData['email'] as String;
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parolele nu coincid')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);

      if (methods.isNotEmpty) {
        // Dacă există deja metode de autentificare pentru email, nu permitem setarea parolei aici.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Există deja un cont cu acest email. Te rugăm să te autentifici.')),
        );
        setState(() => loading = false);
        return;
      }

      // Dacă emailul NU are metode -> creăm contul
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;
      final vetDoc = FirebaseFirestore.instance.collection('vets').doc(uid);

      // Upload profile image dacă există
      String? profileImageUrl;
      if (widget.vetData['profileImage'] != null) {
        final File profileImage = widget.vetData['profileImage'];
        final uploadTask = await FirebaseStorage.instance
            .ref('vets/$uid/profile.jpg')
            .putFile(profileImage);
        profileImageUrl = await uploadTask.ref.getDownloadURL();
      }

      // Upload diploma images dacă există
      List<String> diplomaUrls = [];
      if (widget.vetData['diplomaImages'] != null) {
        final List<File> diplomaFiles = List<File>.from(widget.vetData['diplomaImages']);
        for (int i = 0; i < diplomaFiles.length; i++) {
          final uploadTask = await FirebaseStorage.instance
              .ref('vets/$uid/diploma_$i.jpg')
              .putFile(diplomaFiles[i]);
          final diplomaUrl = await uploadTask.ref.getDownloadURL();
          diplomaUrls.add(diplomaUrl);
        }
      }

      // Salvăm datele în Firestore
      await vetDoc.set({
        'name': widget.vetData['name'],
        'email': email,
        'experience': widget.vetData['experience'],
        'price': widget.vetData['price'],
        'address': widget.vetData['address'],
        'expertise': widget.vetData['expertise'],
        'animals': widget.vetData['animals'],
        'level': widget.vetData['level'],
        'profileImage': profileImageUrl,
        'diplomas': diplomaUrls,
        'status': 'PENDING',
        'createdAt': Timestamp.now(),
      });

      // Navigăm către confirmare
      Navigator.pushNamedAndRemoveUntil(context, '/vet-confirmation', (route) => false);

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la crearea contului: ${e.message ?? 'Eroare necunoscută'}')),
      );
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Setează Parola', style: TextStyle(color: Colors.white)),
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
          Container(color: Colors.black.withOpacity(0.7)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const SizedBox(height: 80),
                  _darkInput(passwordController, 'Parolă', obscureText: true),
                  const SizedBox(height: 20),
                  _darkInput(confirmPasswordController, 'Confirmă parola', obscureText: true),
                  const SizedBox(height: 30),
                  loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : ElevatedButton(
                    onPressed: _createVetAccount,
                    child: const Text('Continuă'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkInput(TextEditingController controller, String label, {bool obscureText = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Câmp obligatoriu' : null,
      ),
    );
  }
}
