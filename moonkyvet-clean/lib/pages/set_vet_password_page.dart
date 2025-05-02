import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SetVetPasswordPage extends StatefulWidget {
  final Map<String, dynamic> vetData;
  const SetVetPasswordPage({super.key, required this.vetData});

  @override
  State<SetVetPasswordPage> createState() => _SetVetPasswordPageState();
}

class _SetVetPasswordPageState extends State<SetVetPasswordPage> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      // 1. Create Firebase Auth user
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.vetData['email'],
        password: passwordController.text.trim(),
      );

      final uid = cred.user!.uid;

      // 2. Upload profile image
      final profileImageFile = widget.vetData['profileImage'] as File;
      final profileRef = FirebaseStorage.instance.ref('vets/$uid/profile.jpg');
      final profileUrl = await (await profileRef.putFile(profileImageFile)).ref.getDownloadURL();

      // 3. Upload diploma images
      List<File> diplomas = widget.vetData['diplomaImages'] as List<File>;
      List<String> diplomaUrls = [];
      for (int i = 0; i < diplomas.length; i++) {
        final ref = FirebaseStorage.instance.ref('vets/$uid/diploma_$i.jpg');
        final url = await (await ref.putFile(diplomas[i])).ref.getDownloadURL();
        diplomaUrls.add(url);
      }

      // 4. Save vet data in Firestore
      await FirebaseFirestore.instance.collection('vets').doc(uid).set({
        'name': widget.vetData['name'],
        'email': widget.vetData['email'],
        'experience': widget.vetData['experience'],
        'cases': widget.vetData['cases'],
        'address': widget.vetData['address'],
        'price': widget.vetData['price'],
        'expertise': widget.vetData['expertise'],
        'animals': widget.vetData['animals'],
        'profileImage': profileUrl,
        'diplomas': diplomaUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'PENDING',
      });

      if (context.mounted) {
        Navigator.pushNamed(context, '/vet-confirmation');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Eroare: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Setează Parola'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Creează o parolă pentru contul tău de veterinar',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Parolă'),
                      validator: (v) => v != null && v.length >= 6 ? null : 'Minim 6 caractere',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Confirmă parola'),
                      validator: (v) => v == passwordController.text ? null : 'Parolele nu coincid',
                    ),
                    const SizedBox(height: 30),
                    isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Continuă'),
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

  InputDecoration _inputDecoration(String label) => InputDecoration(
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
