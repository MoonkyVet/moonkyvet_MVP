import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonkyvet/models/pet.dart';
import 'package:moonkyvet/widgets/other_details_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PetDetailsPage extends StatefulWidget {
  final Pet initialPet;

  const PetDetailsPage({Key? key, required this.initialPet}) : super(key: key);

  @override
  State<PetDetailsPage> createState() => _PetDetailsPageState();
}

class _PetDetailsPageState extends State<PetDetailsPage> {
  late Pet pet;

  @override
  void initState() {
    super.initState();
    pet = widget.initialPet;
  }

  Future<void> _updatePetInFirestore() async {
    final petsRef = FirebaseFirestore.instance.collection('pets');
    await petsRef.doc(pet.id).update(pet.toMap());
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseStorage.instance.ref().child('pets/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();

      setState(() => pet = pet.copyWith(photoUrl: url));
      await _updatePetInFirestore();
    }
  }

  Future<void> _addHealthBookImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseStorage.instance.ref().child('pets/${user.uid}/healthbook_${DateTime.now().millisecondsSinceEpoch}_${picked.name}');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();

      setState(() {
        final updatedList = List<String>.from(pet.medicalRecordUrls)..add(url);
        pet = pet.copyWith(medicalRecordUrls: updatedList);
      });
      await _updatePetInFirestore();
    }
  }

  Future<void> _deleteHealthBookImage(String imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Confirmare ștergere', style: TextStyle(color: Colors.white)),
        content: const Text('Sigur vrei să ștergi această imagine?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nu')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Da')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        final updatedList = List<String>.from(pet.medicalRecordUrls)..remove(imageUrl);
        pet = pet.copyWith(medicalRecordUrls: updatedList);
      });
      await _updatePetInFirestore();
    }
  }

  void _showFullScreenImage(String url, {VoidCallback? onDelete}) {
    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(child: InteractiveViewer(child: Image.network(url))),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 30),
                onPressed: () {
                  Navigator.pop(context);
                  if (onDelete != null) onDelete();
                },
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

  Widget _buildEditableField(String label, String value, Function(String) onSave) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      subtitle: Text(value.isNotEmpty ? value : '---', style: const TextStyle(color: Colors.white)),
      trailing: IconButton(
        icon: const Icon(Icons.edit, color: Colors.white),
        onPressed: () async {
          String tempValue = value;

          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.black,
              title: Text('Selectează $label', style: const TextStyle(color: Colors.white)),
              content: (label == 'Sex' || label == 'Sterilizat')
                  ? DropdownButtonFormField<String>(
                value: tempValue.isNotEmpty ? tempValue : (label == 'Sex' ? 'Mascul' : 'Nu'),
                dropdownColor: Colors.black,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  labelText: label,
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: label == 'Sex'
                    ? const [
                  DropdownMenuItem(value: 'Mascul', child: Text('Mascul', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'Femelă', child: Text('Femelă', style: TextStyle(color: Colors.white))),
                ]
                    : const [
                  DropdownMenuItem(value: 'Da', child: Text('Da', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'Nu', child: Text('Nu', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (val) {
                  if (val != null) tempValue = val;
                },
              )
                  : TextField(
                controller: TextEditingController(text: value),
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => tempValue = val,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anulează', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    onSave(tempValue);  // Update local
                    await _updatePetInFirestore();  // Update Firebase imediat
                    Navigator.pop(context);
                  },
                  child: const Text('Salvează'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(pet.name, style: const TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickProfilePhoto,
              child: CircleAvatar(
                radius: 80,
                backgroundImage: pet.photoUrl.isNotEmpty ? NetworkImage(pet.photoUrl) : null,
                backgroundColor: Colors.white10,
                child: pet.photoUrl.isEmpty ? const Icon(Icons.camera_alt, size: 30, color: Colors.white54) : null,
              ),
            ),
            const SizedBox(height: 20),
            Text(pet.name, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(pet.breed, style: const TextStyle(fontSize: 20, color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Vârstă: ${_calculateAge(pet.birthDate)}', style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),

            _buildEditableField('Sex', pet.sex, (val) => setState(() => pet = pet.copyWith(sex: val))),
            _buildEditableField(
              'Greutate kg',
              pet.weight.toString(), // doar numărul, fără "kg"
                  (val) => setState(() => pet = pet.copyWith(
                weight: double.tryParse(val.trim()) ?? pet.weight,
              )),
            ),
            _buildEditableField('Sterilizat', pet.neutered ? 'Da' : 'Nu', (val) => setState(() => pet = pet.copyWith(neutered: val == 'Da'))),
            _buildEditableField('Alergii', pet.allergies.isEmpty ? 'Nicio alergie' : pet.allergies, (val) => setState(() => pet = pet.copyWith(allergies: val))),
            _buildEditableField('Număr microcip', pet.microchipNumber, (val) => setState(() => pet = pet.copyWith(microchipNumber: val))),
            _buildEditableField('Locație microcip', pet.microchipLocation.isEmpty ? 'Nespecificat' : pet.microchipLocation, (val) => setState(() => pet = pet.copyWith(microchipLocation: val))),
            const SizedBox(height: 24),


            const SizedBox(height: 12),
            OtherDetailsCard(
              otherDetailsJson: pet.otherDetails,
              onOtherDetailsChanged: (newJson) async {
                setState(() {
                  pet = pet.copyWith(otherDetails: newJson);
                });
                await _updatePetInFirestore();
              },
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Carnet de sănătate:', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...pet.medicalRecordUrls.map((url) => GestureDetector(
                  onTap: () => _showFullScreenImage(url, onDelete: () => _deleteHealthBookImage(url)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url, width: 100, height: 100, fit: BoxFit.cover),
                  ),
                )),
                GestureDetector(
                  onTap: _addHealthBookImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white10,
                    ),
                    child: const Icon(Icons.add_a_photo, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _calculateAge(String birthDate) {
    try {
      if (birthDate.isEmpty) return "Necunoscut";
      List<String> parts = birthDate.split('-');
      if (parts.length < 2) return "Necunoscut";

      int year = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      DateTime birth = DateTime(year, month);

      final now = DateTime.now();
      int years = now.year - birth.year;
      int months = now.month - birth.month;

      if (months < 0) {
        years--;
        months += 12;
      }

      if (years > 0 && months > 0) {
        return "$years ani și $months luni";
      } else if (years > 0) {
        return "$years ani";
      } else if (months > 0) {
        return "$months luni";
      } else {
        return "Mai puțin de o lună";
      }
    } catch (e) {
      return "Necunoscut";
    }
  }
}
