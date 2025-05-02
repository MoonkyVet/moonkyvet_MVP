import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:moonkyvet/models/pet.dart';
import 'package:moonkyvet/models/pet_model.dart';
import 'package:moonkyvet/services//gpt_service.dart';
import 'package:moonkyvet/pages/chat_page.dart';
import 'package:moonkyvet/widgets/expandable_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool moonkyLocked = true;
  bool loading = true;
  List<Map<String, dynamic>> pets = [];
  Map<String, dynamic>? selectedPet;
  final TextEditingController _journalController = TextEditingController();
  List<Map<String, dynamic>> latestJournalEntries = [];
  List<String> dailyAdvice = [];

  bool isAdviceCollapsed = false;
  bool isJournalCollapsed = false;

  Future<void> _loadDailyAdvice() async {
    final query = await FirebaseFirestore.instance.collection('advice').get();
    final allAdvices = query.docs.map((doc) => doc['text'] as String).toList();

    allAdvices.shuffle(); // amestecă lista
    setState(() {
      dailyAdvice = allAdvices.take(2).toList(); // păstrează doar 2
    });
  }

  final cardData = [
    {'title': 'Animaluțele mele', 'icon': Icons.pets, 'route': '/myPets'},
    {'title': 'Profilul meu', 'icon': Icons.person, 'route': '/profile'},
    {'title': 'Cabinete Veterinare', 'icon': Icons.map, 'route': '/findVetsProfile'},
    {'title': 'Consultație Rapida', 'icon': Icons.chat_bubble_outline, 'route': '/connectVet'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData().then((_) => _loadDailyAdvice());
  }
  Future<String> _getCachedOrNewAdvice(Pet selectedPet) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "Eroare: utilizatorul nu este autentificat.";

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userDoc = await userDocRef.get();
    final now = DateTime.now();

    final lastGenerated = userDoc.data()?['lastAdviceGeneratedAt']?.toDate();
    final cachedAdvice = userDoc.data()?['lastAdviceText'];

    if (lastGenerated != null && cachedAdvice != null) {
      final hoursSince = now.difference(lastGenerated).inHours;
      if (hoursSince < 9) {
        return cachedAdvice; // ♻️ returnează sfatul generat anterior
      }
    }

    final newAdvice = await generatePersonalizedAdvice(PetModel.fromPet(selectedPet), latestJournalEntries);

    await userDocRef.set({
      'lastAdviceGeneratedAt': Timestamp.fromDate(now),
      'lastAdviceText': newAdvice,
    }, SetOptions(merge: true));

    return newAdvice;
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data();

    final petsQuery = await FirebaseFirestore.instance
        .collection('pets')
        .where('userId', isEqualTo: uid)
        .get();

    final petList = petsQuery.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    final firstPet = petList.isNotEmpty ? petList[0] : null;
    final isSubscribed = userData?['subscriptionActive'] == true;

    setState(() {
      moonkyLocked = !isSubscribed;
      pets = petList;
      selectedPet = firstPet;
      loading = false;
    });

    if (isSubscribed && firstPet != null) {
      await _loadLatestJournalEntries();
    }
  }

  Future<void> _loadLatestJournalEntries() async {
    final petId = selectedPet?['id'];
    if (petId == null) return;
    final query = await FirebaseFirestore.instance
        .collection('pets')
        .doc(petId)
        .collection('journal')
        .orderBy('createdAt', descending: true)
        .limit(3)
        .get();

    setState(() {
      latestJournalEntries = query.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> _saveJournalEntry() async {
    final text = _journalController.text.trim();
    if (text.isEmpty || selectedPet == null) return;

    await FirebaseFirestore.instance
        .collection('pets')
        .doc(selectedPet!['id'])
        .collection('journal')
        .add({
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _journalController.clear();
    _loadLatestJournalEntries();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Jurnalul a fost actualizat"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'MoonkyVet AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/dachshund-4.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cardData.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = cardData[index];
                      final title = item['title'] as String;
                      final route = item['route'] as String;
                      final isLocked = title == 'Talk with Moonky AI Vet' && moonkyLocked;

                      return GestureDetector(
                        onTap: () {
                          if (isLocked) {
                            Navigator.pushNamed(context, '/subscription');
                          } else {
                            Navigator.pushNamed(context, route);
                          }
                        },
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          splashColor: Colors.white24,
                          child: Card(
                            color: Colors.black.withOpacity(0.5),
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (isLocked)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8.0),
                                      child: Icon(Icons.lock_outline, size: 20, color: Colors.white70),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  if (!moonkyLocked && selectedPet != null) _buildTalkWithMoonkyButton(),

                  if (moonkyLocked)
                    _buildPromoCard()
                  else if (selectedPet == null)
                    _buildAddPetCard()
                  else
                    _buildAdviceCard(Pet.fromMap(selectedPet!)),

                  if (pets.length > 1) _buildPetSelector(),

                  if (!moonkyLocked && selectedPet != null) _buildJournalCard(),


                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetSelector() {
    return DropdownButton<Map<String, dynamic>>(
      dropdownColor: Colors.black,
      value: selectedPet,
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
      underline: Container(),
      items: pets.map((pet) {
        return DropdownMenuItem(
          value: pet,
          child: Text(
            pet['name'] ?? 'Animal',
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
      onChanged: (pet) {
        setState(() => selectedPet = pet);
      },
    );
  }

  Widget _buildJournalCard() {
    return ExpandableCard(
      title: 'Jurnalul lui ${selectedPet?['name'] ?? 'Animal'}',
      icon: Icons.menu_book_rounded,
      children: [
        DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.greenAccent,
                tabs: [
                  Tab(icon: Icon(Icons.edit_note), text: 'Adaugă'),
                  Tab(icon: Icon(Icons.library_books), text: 'Ultimele intrări'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: TabBarView(
                  children: [
                    // 📝 Tab 1: Form
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _journalController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Cum s-a simțit azi?",
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _saveJournalEntry,
                              icon: const Icon(Icons.edit_note),
                              label: const Text("Adaugă"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white12,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/fullJournal', arguments: selectedPet!['id']);
                              },
                              child: const Text("Vezi jurnalul complet", style: TextStyle(color: Colors.white70)),
                            )
                          ],
                        ),
                      ],
                    ),

                    // 📚 Tab 2: Latest entries
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: latestJournalEntries.map((entry) {
                          final date = (entry['createdAt'] as Timestamp?)?.toDate();
                          final formatted = date != null
                              ? DateFormat('dd MMM yyyy, HH:mm').format(date)
                              : 'Fără dată';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatted, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(entry['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🔓 Acces Premium Moonky", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Primește sfaturi personalizate pentru sănătatea animalului tău + acces la Moonky, veterinar AI si multe alte feature-uri premium!", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/subscription'),
            icon: const Icon(Icons.stars),
            label: const Text("Activează abonamentul"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.withOpacity(0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAddPetCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🐶 Adaugă primul tău companion",
              style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
            "Ai activat abonamentul – perfect!\nAcum adaugă un animal pentru a primi sfaturi personalizate și acces la toate funcționalitățile.",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.pushNamed(context, '/myPets');
              setState(() {
                loading = true; // opțional, pentru a arăta un spinner
              });
              await _loadData(); // 🔄 reîncarcă datele
            },
            icon: const Icon(Icons.add),
            label: const Text("Adaugă primul animal"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.withOpacity(0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildAdviceCard(Pet selectedPet) {
    return FutureBuilder<String>(
      future: _getCachedOrNewAdvice(selectedPet),
      builder: (context, snapshot) {
        final advice = snapshot.data ?? "Nu am reușit să generăm un sfat acum. Reîncearcă mai târziu.";
        final lines = advice
            .split(RegExp(r'\n+'))
            .where((line) => line.trim().isNotEmpty)
            .map((line) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("💡 ", style: TextStyle(color: Colors.white)),
            Expanded(child: Text(line.trim(), style: const TextStyle(color: Colors.white70))),
          ],
        ))
            .toList();

        return ExpandableCard(
          title: 'Sfatul zilei pentru ${selectedPet?.name ?? "Animal"}',
          icon: Icons.pets,
          children: lines,
        );
      },
    );
  }

  Widget _buildTalkWithMoonkyButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF81C784)], // nuanțe de verde
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                selectedPet: PetModel.fromPet(Pet.fromMap(selectedPet ?? {})),
              ),
            ),
          );
        },
        child: Row(
          children: const [
            Icon(Icons.auto_awesome, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Vorbește cu Moonky, Veterinar AI",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black26,
                      offset: Offset(1, 1),
                    )
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }


}
