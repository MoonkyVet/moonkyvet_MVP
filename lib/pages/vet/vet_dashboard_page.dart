import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class VetDashboardPage extends StatefulWidget {
  const VetDashboardPage({super.key});

  @override
  State<VetDashboardPage> createState() => _VetDashboardPageState();
}

class _VetDashboardPageState extends State<VetDashboardPage> {
  int consultations = 0;
  double videoEarnings = 0;
  double textEarnings = 0;
  double rating = 0;
  int ratingsCount = 0;
  List<QueryDocumentSnapshot> recentReviews = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final vetDoc = await FirebaseFirestore.instance.collection('vets').doc(uid).get();
    final earnings = vetDoc.data()?['earnings'] as Map<String, dynamic>? ?? {};

    final reviewsSnapshot = await FirebaseFirestore.instance
        .collection('vets')
        .doc(uid)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .limit(3)
        .get();

    setState(() {
      consultations = vetDoc.data()?['consultations'] ?? 0;
      videoEarnings = (earnings['video'] ?? 0).toDouble();
      textEarnings = (earnings['text'] ?? 0).toDouble();
      rating = (vetDoc.data()?['rating'] ?? 0).toDouble();
      ratingsCount = vetDoc.data()?['ratingsCount'] ?? 0;
      recentReviews = reviewsSnapshot.docs;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        centerTitle: true,
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
          loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dashboardCard(FontAwesomeIcons.stethoscope, 'Consultații efectuate', consultations.toString()),
                _dashboardCard(Icons.attach_money, 'Venituri video', '${videoEarnings.toStringAsFixed(2)} RON'),
                _dashboardCard(Icons.message, 'Venituri text', '${textEarnings.toStringAsFixed(2)} RON'),
                _dashboardCard(Icons.star_rate, 'Rating mediu', '$rating / 5 (${ratingsCount} recenzii)'),
                const SizedBox(height: 20),
                const Text('Recenzii recente', style: TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...recentReviews.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['userName'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text(data['comment'], style: const TextStyle(color: Colors.white70)),
                    trailing: Text('${data['rating']}/5', style: const TextStyle(color: Colors.tealAccent)),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardCard(IconData icon, String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.tealAccent, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
