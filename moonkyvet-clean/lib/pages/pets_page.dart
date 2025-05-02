import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class Pet {
  String id;
  String name;
  String breed;
  String sex;
  String birthDate;
  double weight;
  bool neutered;
  String allergies;
  String medicalHistory;
  String photoUrl;

  Pet({
    required this.id,
    required this.name,
    required this.breed,
    required this.sex,
    required this.birthDate,
    required this.weight,
    required this.neutered,
    required this.allergies,
    required this.medicalHistory,
    required this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'breed': breed,
      'sex': sex,
      'birthDate': birthDate,
      'weight': weight,
      'neutered': neutered,
      'allergies': allergies,
      'medicalHistory': medicalHistory,
      'photoUrl': photoUrl,
      'userId': FirebaseAuth.instance.currentUser?.uid,
    };
  }

  static Pet fromMap(String id, Map<String, dynamic> map) {
    return Pet(
      id: id,
      name: map['name'] ?? '',
      breed: map['breed'] ?? '',
      sex: map['sex'] ?? '',
      birthDate: map['birthDate'] ?? '',
      weight: (map['weight'] ?? 0).toDouble(),
      neutered: map['neutered'] ?? false,
      allergies: map['allergies'] ?? '',
      medicalHistory: map['medicalHistory'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
    );
  }
}

class PetsPage extends StatefulWidget {
  final bool returnPet;
  const PetsPage({super.key, this.returnPet = false});
  @override
  _PetsPageState createState() => _PetsPageState();
}

class _PetsPageState extends State<PetsPage> {
  List<Pet> pets = [];
  XFile? pickedFile;

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
      pets = snapshot.docs
          .map((doc) => Pet.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> _deletePet(String id) async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Delete"),
        content: Text("Are you sure you want to delete this pet?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('pets').doc(id).delete();
      _loadPets();
    }
  }

  void _showPetModal(Pet pet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
              ),
            ),
            const SizedBox(height: 12),
            Text(
              pet.name,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (widget.returnPet) Navigator.pop(context, pet);
                Navigator.pop(context, pet); // returnează petul către ChatPage
              },
              child: Text("Open Chat with Moonky VET"),
            ),

            ElevatedButton(
              onPressed: () {
                if (widget.returnPet) Navigator.pop(context, pet);
                // future action
              },
              child: Text("See Medical History"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addOrEditPet({Pet? pet}) async {
    final picker = ImagePicker();
    String name = pet?.name ?? '';
    String breed = pet?.breed ?? '';
    String sex = pet?.sex ?? 'Male';
    String birthDate = pet?.birthDate ?? '';
    String allergies = pet?.allergies ?? '';
    String medicalHistory = pet?.medicalHistory ?? '';
    double weight = pet?.weight ?? 0;
    bool neutered = pet?.neutered ?? false;
    String photoUrl = pet?.photoUrl ?? '';

    final controllerName = TextEditingController(text: name);
    final controllerBreed = TextEditingController(text: breed);
    final controllerBirth = TextEditingController(text: birthDate);
    final controllerAllergies = TextEditingController(text: allergies);
    final controllerMedical = TextEditingController(text: medicalHistory);
    final controllerWeight = TextEditingController(text: weight.toString());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: pickedFile != null
                    ? FileImage(File(pickedFile!.path))
                    : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null) as ImageProvider?,
                child: (pickedFile == null && photoUrl.isEmpty)
                    ? Icon(Icons.camera_alt, color: Colors.white)
                    : null,
              ),
              SizedBox(height: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.photo),
                label: Text('Choose Photo'),
                onPressed: () async {
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    final file = File(picked.path);
                    final exists = await file.exists();
                    if (exists) {
                      setState(() => pickedFile = picked);
                    }
                  }
                },
              ),
              TextField(controller: controllerName, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: controllerBreed, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Breed', labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: controllerBirth, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Birthdate', labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: controllerWeight, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Weight (kg)', labelStyle: TextStyle(color: Colors.white70)), keyboardType: TextInputType.number),
              TextField(controller: controllerAllergies, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Allergies', labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: controllerMedical, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Medical History', labelStyle: TextStyle(color: Colors.white70))),
              DropdownButton<String>(
                value: sex,
                dropdownColor: Colors.black,
                items: ['Male', 'Female'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: Colors.white)))).toList(),
                onChanged: (value) => setState(() => sex = value!),
              ),
              SwitchListTile(
                title: Text('Neutered', style: TextStyle(color: Colors.white)),
                value: neutered,
                onChanged: (value) => setState(() => neutered = value),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                child: Text(pet == null ? 'Add Pet' : 'Update Pet'),
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  String uploadedUrl = photoUrl;

                  try {
                    if (pickedFile != null) {
                      final file = File(pickedFile!.path);
                      final exists = await file.exists();
                      if (exists) {
                        final bytes = await file.readAsBytes();
                        final ref = FirebaseStorage.instance.ref().child('pets/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
                        final uploadTask = await ref.putData(bytes);
                        uploadedUrl = await uploadTask.ref.getDownloadURL();
                      }
                    }

                    if (uploadedUrl.isEmpty) {
                      uploadedUrl = 'https://placehold.co/100x100/000000/FFFFFF?text=No+Image';
                    }

                    final newPet = Pet(
                      id: pet?.id ?? '',
                      name: controllerName.text,
                      breed: controllerBreed.text,
                      sex: sex,
                      birthDate: controllerBirth.text,
                      weight: double.tryParse(controllerWeight.text) ?? 0,
                      neutered: neutered,
                      allergies: controllerAllergies.text,
                      medicalHistory: controllerMedical.text,
                      photoUrl: uploadedUrl,
                    );

                    final petsRef = FirebaseFirestore.instance.collection('pets');
                    if (pet == null) {
                      await petsRef.add(newPet.toMap());
                    } else {
                      await petsRef.doc(pet.id).update(newPet.toMap());
                    }

                    Navigator.pop(context);
                    _loadPets();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Eroare la încărcarea imaginii.'),
                      backgroundColor: Colors.red,
                    ));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.6), // fundal mai vizibil
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white), // culoare albă garantată
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Pets', style: TextStyle(color: Colors.white)),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white10,
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () => _addOrEditPet(),
      ),
      body: pets.isEmpty
          ? Center(child: Text('No pets added yet.', style: TextStyle(color: Colors.white70)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pets.length,
        itemBuilder: (context, index) {
          final pet = pets[index];
          return GestureDetector(
            onTap: () => _showPetModal(pet),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(24),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: pet.photoUrl.isNotEmpty
                          ? Image.network(
                        pet.photoUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      )
                          : Container(color: Colors.grey.shade800),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            pet.breed,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Spacer(),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    iconSize: 28,
                                    icon: Icon(Icons.edit, color: Colors.white),
                                    onPressed: () => _addOrEditPet(pet: pet),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    iconSize: 28,
                                    icon: Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () => _deletePet(pet.id),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
