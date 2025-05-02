import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonkyvet/models/pet.dart';
import 'package:moonkyvet/models/pet_model.dart';
import 'package:moonkyvet/pages/chat_page.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:moonkyvet/services/gpt_service.dart'; // 🔥 adaugă asta
import 'dart:convert';
import 'package:moonkyvet/widgets/other_details_card.dart'; // Importă widgetul
import 'package:moonkyvet/pages/pet_details_page.dart';
import 'package:moonkyvet/pages/subscription_page.dart';

import 'dart:ui';

class PetsPage extends StatefulWidget {
  const PetsPage({super.key});

  @override
  State<PetsPage> createState() => _PetsPageState();
}

class _PetsPageState extends State<PetsPage> {
  List<Pet> pets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('pets')
        .where('userId', isEqualTo: user.uid)
        .get();
    setState(() {
      pets = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // injectăm ID-ul
        return Pet.fromMap(data);
      }).toList();
      isLoading = false;
    });

  }

  Future<void> _deletePet(String id) async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this pet?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('pets').doc(id).delete();
      await _loadPets();
    }
  }
  Future<String> extractMedicalRecordText(List<File> images) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String extractedText = '';

    for (final file in images) {
      final inputImage = InputImage.fromFile(file);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      extractedText += recognizedText.text + '\n';
    }

    await textRecognizer.close();
    return extractedText.trim();
  }
  void _showPetModal(Pet pet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.95),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Image.network(
                pet.photoUrl,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, size: 60, color: Colors.white30),
              ),
            ),
            const SizedBox(height: 12),
            Text(pet.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get(),
              builder: (context, snapshot) {
                final isActive = snapshot.data?.get('subscriptionActive') == true;

                return ElevatedButton.icon(
                  icon: Icon(
                    isActive ? Icons.pets : Icons.lock,
                    color: isActive ? Colors.black : Colors.white,
                  ),
                  label: const Text("Moonky Veterinar AI"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? Colors.tealAccent : Colors.white.withOpacity(0.1),
                    foregroundColor: isActive ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: isActive ? 2 : 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (isActive) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ChatPage(selectedPet: PetModel.fromPet(pet))),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                      );
                    }
                  },
                );
              },
            ),


            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PetDetailsPage(initialPet: pet)),
                );

              },
              child: const Text("Vezi detaliile animalului"),
            ),
          ],
        ),
      ),
    );
  }


  void _showMedicalRecords(Pet pet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return FutureBuilder<List<String>>(
          future: Future.value(pet.medicalRecordUrls),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }

            final urls = snapshot.data!;

            if (urls.isEmpty) {
              return const Center(
                child: Text(
                  'No medical records found.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: urls.map((url) => Image.network(url, fit: BoxFit.cover)).toList(),
              ),
            );
          },
        );
      },
    );
  }


  InputDecoration _input(String label) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white30),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Prietenii mei', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white.withOpacity(0.1),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final refreshed = await _addOrEditPet();
          if (refreshed == true) {
            await _loadPets();
            setState(() {});
          }
        },
      ),
      body: Stack(
      children: [
    // 🐾 Poză de background pe toată pagina
    Positioned.fill(
    child: Image.asset(
      'assets/images/background_pets.jpg', // 🖼️ schimbă cu numele tău
      fit: BoxFit.cover,
    ),
    ),

    // 🖤 Overlay întunecat (opțional)
    Positioned.fill(
    child: Container(color: Colors.black.withOpacity(0.6)),
    ),
    isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : pets.isEmpty
          ? const Center(child: Text('No pets added yet.', style: TextStyle(color: Colors.white70)))
          : ListView.builder(
        itemCount: pets.length,
        itemBuilder: (context, index) {
          final pet = pets[index];
          return GestureDetector(
            onTap: () => _showPetModal(pet),
            child: Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(pet.photoUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withOpacity(0.6), // Darker overlay!
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pet.name,
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2))],
                              ),
                            ),
                            Text(
                              pet.breed,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2))],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () async {
                                final refreshed = await _editPetQuick(pet);
                                if (refreshed == true) {
                                  await _loadPets();
                                  setState(() {});
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.edit, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _deletePet(pet.id),
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.delete, color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ]
    ),
    );
  }

  // Redesigned and upgraded _addOrEditPet modal

  void _showFullScreenImageEditable({required String type, required dynamic data, required VoidCallback onDelete}) {
    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background Image - cu cățelul sărind
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/dachshund-4.png'), // <<== înlocuiește aici cu noua imagine
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Blur și overlay întunecat
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ),
            // Conținutul principal
            isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : pets.isEmpty
                ? const Center(child: Text('No pets added yet.', style: TextStyle(color: Colors.white70)))
                : ListView.builder(
              itemCount: pets.length,
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemBuilder: (context, index) {
                final pet = pets[index];
                return GestureDetector(
                  onTap: () => _showPetModal(pet),
                  child: Container(
                    height: 200,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: NetworkImage(pet.photoUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    pet.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2))],
                                    ),
                                  ),
                                  Text(
                                    pet.breed,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                      shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2))],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () async {
                                      final refreshed = await _editPetQuick(pet);
                                      if (refreshed == true) {
                                        await _loadPets();
                                        setState(() {});
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(Icons.edit, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => _deletePet(pet.id),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(Icons.delete, color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),

      ),
    );
  }

  Future<bool?> _addOrEditPet({Pet? pet}) async {
    final picker = ImagePicker();

    String name = pet?.name ?? '';
    String breed = pet?.breed ?? '';
    String sex = pet?.sex ?? 'Mascul';
    String birthDate = pet?.birthDate ?? '';
    double weight = pet?.weight ?? 0;
    String microchipNumber = pet?.microchipNumber ?? '';
    String profilePhotoUrl = pet?.photoUrl ?? '';

    final controllerName = TextEditingController(text: name);
    final controllerBreed = TextEditingController(text: breed);
    final controllerWeight = TextEditingController(text: weight == 0 ? '' : weight.toString());
    final controllerMicrochipNumber = TextEditingController(text: microchipNumber);

    int selectedYear = birthDate.isNotEmpty ? int.tryParse(birthDate.split('-')[0]) ?? DateTime.now().year : DateTime.now().year;
    int selectedMonth = birthDate.isNotEmpty ? int.tryParse(birthDate.split('-')[1]) ?? DateTime.now().month : DateTime.now().month;

    XFile? profileImageFile;
    List<XFile> healthBookImages = [];
    List<String> existingMedicalRecords = List.from(pet?.medicalRecordUrls ?? []);
    bool parsingHealthBook = false;

    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> parseHealthBook(List<XFile> files) async {
              try {
                setModalState(() => parsingHealthBook = true);

                final extractedFields = await extractFieldsFromImagesWithGPT(
                    healthBookImages.map((x) => File(x.path)).toList()
                );

                if (extractedFields != null) {
                  setModalState(() {
                    controllerName.text = extractedFields['name'] ?? '';
                    controllerBreed.text = extractedFields['breed'] ?? '';
                    controllerMicrochipNumber.text = extractedFields['microchip_number'] ?? '';
                    selectedYear = int.tryParse(extractedFields['birth_year'] ?? '') ?? selectedYear;
                    selectedMonth = int.tryParse(extractedFields['birth_month'] ?? '') ?? selectedMonth;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Datele au fost completate automat.")),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nu am putut extrage datele din carnet.")),
                  );
                }

              } catch (e) {
                print("Eroare la GPT image parse: $e");
              } finally {
                setModalState(() => parsingHealthBook = false);
              }
            }


            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ),
                    const Text('Carnet de sănătate', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final pickedFiles = await picker.pickMultiImage();
                            if (pickedFiles != null && pickedFiles.isNotEmpty) {
                              setModalState(() => healthBookImages.addAll(pickedFiles));
                              await parseHealthBook(healthBookImages);
                            }
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Galerie'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final picked = await picker.pickImage(source: ImageSource.camera);
                            if (picked != null) {
                              setModalState(() => healthBookImages.add(picked));
                              await parseHealthBook(healthBookImages);
                            }
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (parsingHealthBook)
                      const CircularProgressIndicator(color: Colors.white),
                    if (!parsingHealthBook && (healthBookImages.isNotEmpty || existingMedicalRecords.isNotEmpty))
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...existingMedicalRecords.map((url) => Image.network(url, width: 100, height: 100, fit: BoxFit.cover)),
                          ...healthBookImages.map((file) => Image.file(File(file.path), width: 100, height: 100, fit: BoxFit.cover)),
                        ],
                      ),
                    const Divider(color: Colors.white24, height: 32),
                    const Text('Poză de profil câine', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setModalState(() => profileImageFile = picked);
                        }
                      },
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: profileImageFile != null
                            ? FileImage(File(profileImageFile!.path))
                            : (profilePhotoUrl.isNotEmpty ? NetworkImage(profilePhotoUrl) : null) as ImageProvider?,
                        backgroundColor: Colors.white10,
                        child: (profileImageFile == null && profilePhotoUrl.isEmpty)
                            ? const Icon(Icons.camera_alt, size: 30, color: Colors.white54)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _customInput(controllerName, "Nume"),
                    const SizedBox(height: 12),
                    _customInput(controllerBreed, "Rasă"),
                    const SizedBox(height: 12),
                    const Text('Data nașterii', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _customDropdown<int>(selectedYear, "An", List.generate(30, (i) => DateTime.now().year - i), setModalState, (val) => selectedYear = val ?? DateTime.now().year)),
                        const SizedBox(width: 10),
                        Expanded(child: _customDropdown<int>(selectedMonth, "Lună", List.generate(12, (i) => i + 1), setModalState, (val) => selectedMonth = val ?? DateTime.now().month)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _customInput(controllerWeight, "Greutate (kg)", inputType: TextInputType.number),
                    const SizedBox(height: 12),
                    _customInput(controllerMicrochipNumber, "Număr microcip"),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;
                        setModalState(() => isLoading = true);

                        String uploadedProfilePhotoUrl = profilePhotoUrl;
                        if (profileImageFile != null) {
                          final ref = FirebaseStorage.instance.ref().child('pets/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
                          await ref.putFile(File(profileImageFile!.path));
                          uploadedProfilePhotoUrl = await ref.getDownloadURL();
                        }

                        List<String> uploadedHealthBookUrls = [...existingMedicalRecords];
                        List<File> allHealthBookFiles = [];

                        for (final file in healthBookImages) {
                          final ref = FirebaseStorage.instance.ref().child('pets/${user.uid}/healthbook_${DateTime.now().millisecondsSinceEpoch}_${file.name}');
                          await ref.putFile(File(file.path));
                          final url = await ref.getDownloadURL();
                          uploadedHealthBookUrls.add(url);
                          allHealthBookFiles.add(File(file.path));
                        }

                        String fullExtractedText = '';
                        if (allHealthBookFiles.isNotEmpty) {
                          final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
                          for (final file in allHealthBookFiles) {
                            final inputImage = InputImage.fromFile(file);
                            final recognizedText = await textRecognizer.processImage(inputImage);
                            fullExtractedText += recognizedText.text + '\n';
                          }
                          await textRecognizer.close();
                        }

                        String otherDetailsJson = '{}';
                        if (fullExtractedText.trim().isNotEmpty) {
                          otherDetailsJson = await generateOtherDetailsFromHealthBook(fullExtractedText);
                        }

                        final newPet = Pet(
                          id: pet?.id ?? '',
                          name: controllerName.text,
                          breed: controllerBreed.text,
                          sex: sex,
                          birthDate: '${selectedYear.toString().padLeft(4, '0')}-${selectedMonth.toString().padLeft(2, '0')}',
                          weight: double.tryParse(controllerWeight.text) ?? 0,
                          neutered: false,
                          allergies: '',
                          photoUrl: uploadedProfilePhotoUrl,
                          medicalRecordUrls: uploadedHealthBookUrls,
                          medicalRecordText: fullExtractedText,
                          microchipNumber: controllerMicrochipNumber.text,
                          microchipLocation: '',
                          otherDetails: otherDetailsJson,
                        );

                        final petsRef = FirebaseFirestore.instance.collection('pets');
                        if (pet == null) {
                          await petsRef.add({...newPet.toMap(), 'userId': user.uid});
                        } else {
                          await petsRef.doc(pet.id).update({...newPet.toMap(), 'userId': user.uid});
                        }

                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(pet == null ? 'Adaugă animal' : 'Actualizează animal'),
                    ),
                  ],
                ),
              ),
            );
          },

        );
      },
    );
  }
  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _customInput(TextEditingController controller, String label, {TextInputType inputType = TextInputType.text}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: inputType,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white10,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
  Future<bool?> _editPetQuick(Pet pet) async {
    final picker = ImagePicker();

    String profilePhotoUrl = pet.photoUrl;
    double weight = pet.weight;
    String allergies = pet.allergies;
    List<String> existingMedicalRecords = List.from(pet.medicalRecordUrls);
    XFile? profileImageFile;
    List<XFile> newHealthBookImages = [];

    final controllerWeight = TextEditingController(text: weight == 0 ? '' : weight.toString());
    final controllerAllergies = TextEditingController(text: allergies);

    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Editează Animal', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Poza profil
                    GestureDetector(
                      onTap: () async {
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setModalState(() => profileImageFile = picked);
                        }
                      },
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: profileImageFile != null
                            ? FileImage(File(profileImageFile!.path))
                            : (profilePhotoUrl.isNotEmpty ? NetworkImage(profilePhotoUrl) : null) as ImageProvider?,
                        backgroundColor: Colors.white10,
                        child: (profileImageFile == null && profilePhotoUrl.isEmpty)
                            ? const Icon(Icons.camera_alt, size: 30, color: Colors.white54)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Greutate
                    _customInput(controllerWeight, "Greutate (kg)", inputType: TextInputType.number),
                    const SizedBox(height: 12),

                    // Alergii
                    _customInput(controllerAllergies, "Alergii"),
                    const SizedBox(height: 24),

                    // Adaugă poză carnet
                    ElevatedButton.icon(
                      onPressed: () async {
                        final List<XFile>? pickedFiles = await picker.pickMultiImage();
                        if (pickedFiles != null && pickedFiles.isNotEmpty) {
                          setModalState(() => newHealthBookImages.addAll(pickedFiles));
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Adaugă poză carnet'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
                    ),
                    const SizedBox(height: 12),

                    // Afișează toate imaginile
                    if (existingMedicalRecords.isNotEmpty || newHealthBookImages.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...existingMedicalRecords.map((url) => GestureDetector(
                            onTap: () {
                              _showFullScreenImageEditable(
                                type: 'url',
                                data: url,
                                onDelete: () {
                                  setModalState(() => existingMedicalRecords.remove(url));
                                },
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(url, width: 100, height: 100, fit: BoxFit.cover),
                            ),
                          )),
                          ...newHealthBookImages.map((file) => GestureDetector(
                            onTap: () {
                              _showFullScreenImageEditable(
                                type: 'file',
                                data: file,
                                onDelete: () {
                                  setModalState(() => newHealthBookImages.remove(file));
                                },
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(file.path), width: 100, height: 100, fit: BoxFit.cover),
                            ),
                          )),
                        ],
                      ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;
                        setModalState(() => isLoading = true);

                        // Upload profile picture
                        String uploadedProfileUrl = profilePhotoUrl;
                        if (profileImageFile != null) {
                          final ref = FirebaseStorage.instance.ref().child('pets/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
                          await ref.putFile(File(profileImageFile!.path));
                          uploadedProfileUrl = await ref.getDownloadURL();
                        }

                        // Upload new carnet images
                        List<String> updatedMedicalRecords = List.from(existingMedicalRecords);
                        for (final file in newHealthBookImages) {
                          final ref = FirebaseStorage.instance.ref().child('pets/${user.uid}/healthbook_${DateTime.now().millisecondsSinceEpoch}_${file.name}');
                          await ref.putFile(File(file.path));
                          final url = await ref.getDownloadURL();
                          updatedMedicalRecords.add(url);
                        }

                        // Update pet
                        final updatedPet = pet.copyWith(
                          weight: double.tryParse(controllerWeight.text) ?? pet.weight,
                          allergies: controllerAllergies.text.trim(),
                          photoUrl: uploadedProfileUrl,
                          medicalRecordUrls: updatedMedicalRecords,
                        );

                        final petsRef = FirebaseFirestore.instance.collection('pets');
                        await petsRef.doc(pet.id).update(updatedPet.toMap());

                        Navigator.pop(context, true);
                      },
                      child: const Text('Salvează Modificări'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent.withOpacity(0.2), foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _customDropdown<T>(T value, String label, List<T> items, Function setModalState, Function(T?) onChanged) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: Colors.black,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white10,
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item.toString(), style: const TextStyle(color: Colors.white)))).toList(),
      onChanged: (val) => setModalState(() => onChanged(val)),
    );
  }

}
