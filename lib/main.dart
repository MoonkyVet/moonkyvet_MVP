import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonkyvet/models/pet.dart';
import 'package:moonkyvet/models/pet_model.dart';

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
import 'pages/subscription_success.dart';
import 'pages/full_journal_page.dart';

// Vet
import 'pages/vet/vet_home_page.dart';
import 'pages/vet/vet_profile_page.dart';
import 'pages/vet/vet_settings_page.dart';
import 'pages/vet/connect_with_a_vet_page.dart';
import 'package:moonkyvet/pages/vet/vet_dashboard_page.dart'; // <- ajustează calea dacă e diferită

// Onboarding
import 'pages/oboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load();

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  final prefs = await SharedPreferences.getInstance();
  final bool onboardingSeen = prefs.getBool('onboarding_seen') ?? false;

  runApp(MyApp(showOnboarding: !onboardingSeen));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoonkyVet AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: showOnboarding ? const OnboardingPage() : const AuthGate(),
      routes: {
        '/subscription-success': (context) => SubscriptionSuccessPage(),
        '/landing-page': (context) => const LandingPage(),

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
          final pet = ModalRoute.of(context)!.settings.arguments as Pet;
          return ChatPage(selectedPet: PetModel.fromPet(pet));
        },

        '/fullJournal': (context) {
          final petId = ModalRoute.of(context)!.settings.arguments as String;
          return FullJournalPage(petId: petId);
        },

        '/register-vet': (_) => RegisterVetPage(),
        '/vet-login': (_) => const VetLoginPage(),
        '/vet-home': (_) => const VetHomePage(),
        '/vet-profile': (_) => const VetProfilePage(),
        '/vet-settings': (_) => const VetSettingsPage(),
        '/connectVet': (_) => ConnectWithAVetPage(),
        '/vet-dashboard': (context) => const VetDashboardPage(),
        '/set-vet-password': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return SetVetPasswordPage(vetData: args);
        },
      },
    );
  }
}
