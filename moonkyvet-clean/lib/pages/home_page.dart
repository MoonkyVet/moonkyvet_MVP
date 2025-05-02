import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cardData = [
      {'title': 'My Pets', 'icon': Icons.pets, 'route': '/myPets'},
      {'title': 'My Profile', 'icon': Icons.person, 'route': '/profile'},
      {'title': 'Find VETS near me', 'icon': Icons.map, 'route': '/findVetsProfile'},
      {'title': 'Subscription', 'icon': Icons.monetization_on, 'route': '/subscription'},
      {'title': 'Talk with Moonky     AI Vet', 'icon': Icons.chat_bubble_outline, 'route': '/chat'},
      {'title': 'Talk with a real Vet', 'icon': Icons.chat_bubble_outline, 'route': '/chat'},
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'MoonkyVet AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/dachshund-4.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Gradient overlay behind AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: kToolbarHeight + 40,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Grid Content
          Container(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              itemCount: cardData.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final item = cardData[index];
                final isLocked = item['title'] == 'Talk with Moonky'; // Replace with logic

                return GestureDetector(
                  onTap: () {
                    if (isLocked /* && !hasSubscription */) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Subscribe to unlock Moonky.')),
                      );
                    } else {
                      Navigator.pushNamed(context, item['route'] as String);
                    }
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    elevation: 4,
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item['title'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (isLocked)
                            const Icon(Icons.lock_outline, size: 20, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
