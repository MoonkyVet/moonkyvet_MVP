import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VetHomePage extends StatefulWidget {
  const VetHomePage({super.key});

  @override
  State<VetHomePage> createState() => _VetHomePageState();
}

class _VetHomePageState extends State<VetHomePage> {
  String vetName = '';

  @override
  void initState() {
    super.initState();
    _loadVetName();
  }

  Future<void> _loadVetName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final vetDoc = await FirebaseFirestore.instance.collection('vets').doc(uid).get();
      setState(() {
        vetName = vetDoc.data()?['name'] ?? '';
      });
    }
  }

  void _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmare'),
        content: const Text('Sigur dorești să te deloghezi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nu')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Da')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false, // <- aici se dezactivează butonul back
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'MoonkyVet - Veterinar',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vetName.isNotEmpty ? 'Salutare, Dr. $vetName!' : 'Salutare, Dr.',
                  style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                _menuButton(context, Icons.person, 'Profilul meu', '/vet-profile'),
                const SizedBox(height: 20),
                _menuButton(context, Icons.chat, 'Solicitări consultații', '/vet-requests'),
                const SizedBox(height: 20),
                _menuButton(context, Icons.settings, 'Setări', '/vet-settings'),
                const SizedBox(height: 20),
                _menuButton(context, Icons.dashboard, 'Dashboard', '/vet-dashboard'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuButton(BuildContext context, IconData icon, String title, String route) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}
