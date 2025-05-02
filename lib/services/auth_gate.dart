import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moonkyvet/pages/vet/vet_home_page.dart'; // Pagina Veterinar
import 'package:moonkyvet/pages/home_page.dart'; // Pagina Home pentru utilizatori
import 'package:moonkyvet/pages/subscription_page.dart'; // Pagina Subscription
import 'package:moonkyvet/pages/login_page.dart'; // Pagina Login
import 'package:moonkyvet/pages/landing_page.dart'; // Pagina de Landing

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> checkUserSubscription(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      return userDoc['subscriptionActive'] ?? false;
    }
    return false;
  }

  Future<bool> checkIfVet(String userId) async {
    final vetDoc = await FirebaseFirestore.instance.collection('vets').doc(userId).get();
    return vetDoc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          final user = snapshot.data!;

          // Verificăm dacă este un utilizator veterinar
          return FutureBuilder<bool>(
            future: checkIfVet(user.uid),
            builder: (context, vetSnapshot) {
              if (vetSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              } else if (vetSnapshot.hasData && vetSnapshot.data == true) {
                // Dacă este un veterinar
                return const VetHomePage(); // Pagina pentru Veterinari
              } else {
                // Dacă nu este veterinar, verificăm dacă are abonament activ
                return FutureBuilder<bool>(
                  future: checkUserSubscription(user.uid),
                  builder: (context, subscriptionSnapshot) {
                    if (subscriptionSnapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    } else if (subscriptionSnapshot.hasData && subscriptionSnapshot.data == true) {
                      return const HomePage(); // Pagina Home pentru utilizatori cu abonament activ
                    } else {
                      return const SubscriptionPage(); // Pagina Subscription dacă nu are abonament
                    }
                  },
                );
              }
            },
          );
        } else {
          // Dacă utilizatorul nu este autentificat, îl redirecționăm către LandingPage
          return const LandingPage();
        }
      },
    );
  }
}
