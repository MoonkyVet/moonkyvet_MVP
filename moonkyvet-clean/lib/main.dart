import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/auth_gate.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/home_page.dart';
import 'pages/pets_page.dart';
import 'pages/profile_page.dart';
import 'pages/select_pet_page.dart';
import 'pages/find_vets_page.dart';
import 'pages/subscription_page.dart';
import 'pages/chat_page.dart';
import 'pages/landing_page.dart';
import 'pages/find_vets_by_profile_page.dart';
import 'pages/register_vet_page.dart';
import 'pages/set_vet_password_page.dart';
import 'pages/vet_confirmation_page.dart';
import 'pages/vet_accss_page.dart';
import 'pages/vet_login_page.dart';
import 'pages/owner_access_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoonkyVet AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const LandingPage(),
      routes: {
        '/login': (_) => LoginPage(),
        '/signup': (_) => SignUpPage(),
        '/home': (_) => HomePage(),
        '/myPets': (_) => PetsPage(),
        '/profile': (_) => ProfilePage(),
        '/selectPet': (_) => SelectPetPage(),
        '/findVets': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as String;
          return FindVetsPage(address: args);
        },
        '/findVetsProfile': (context) => const FindVetsByProfilePage(),
        '/vet-confirmation': (_) => const VetConfirmationPage(),
        '/vet-access': (_) => const VetAccessPage(),
        '/owner-access': (_) => const OwnerAccessPage(),

        '/subscription': (_) => SubscriptionPage(),
        '/chat': (context) {
          final pet = ModalRoute.of(context)!.settings.arguments as Pet?;
          return ChatPage(selectedPet: pet);
        },
        '/register-vet': (_) => RegisterVetPage(),
        '/vet-login': (_) => const VetLoginPage(),

        '/set-vet-password': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return SetVetPasswordPage(vetData: args);
        },
      },
    );
  }
}