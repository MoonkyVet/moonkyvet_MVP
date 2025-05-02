import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class VetProfilePage extends StatefulWidget {
  const VetProfilePage({super.key});

  @override
  State<VetProfilePage> createState() => _VetProfilePageState();
}

class _VetProfilePageState extends State<VetProfilePage> {
  DocumentSnapshot<Map<String, dynamic>>? vetData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchVetData();
  }

  Future<void> fetchVetData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('vets').doc(uid).get();
      setState(() {
        vetData = doc;
        loading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.white),
            title: const Text('Selectează din galerie', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.white),
            title: const Text('Fă o poză', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    );

    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final storageRef = FirebaseStorage.instance.ref().child('vet_profiles/$uid.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('vets').doc(uid).update({
        'profileImage': downloadUrl,
      });

      fetchVetData();
    }
  }

  Future<void> _editField(String fieldName, String label, String? currentValue) async {
    final controller = TextEditingController(text: currentValue ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Editează $label', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(color: Colors.white54),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.tealAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('vets')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .update({fieldName: newValue});
                fetchVetData();
              }
              Navigator.pop(context);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profilul meu', style: TextStyle(color: Colors.white)),
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
              : vetData == null
              ? const Center(child: Text('Eroare la încărcare.', style: TextStyle(color: Colors.white)))
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.white24,
                    backgroundImage: vetData!.data()?['profileImage'] != null
                        ? NetworkImage(vetData!.data()!['profileImage'])
                        : null,
                    child: vetData!.data()?['profileImage'] == null
                        ? const Icon(Icons.camera_alt, size: 40, color: Colors.white70)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Dr. ${vetData!.data()?['name'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  vetData!.data()?['email'] ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 30),
                _infoTile('Nivel:', vetData!.data()?['level'] ?? '',
                    onEdit: () => _editField('level', 'Nivel', vetData!.data()?['level'])),
                _infoTile('Experiență:', '${vetData!.data()?['experience']} ani',
                    onEdit: () => _editField('experience', 'Experiență', vetData!.data()?['experience'].toString())),
                _infoTile('Preț consultație:', '${vetData!.data()?['price']} lei',
                    onEdit: () => _editField('price', 'Preț consultație', vetData!.data()?['price'].toString())),
                _infoTile('Adresă cabinet:', vetData!.data()?['address'] ?? '',
                    onEdit: () => _editField('address', 'Adresă cabinet', vetData!.data()?['address'])),
                _infoTile('Status cont:', vetData!.data()?['status'] ?? ''),
                _infoTile('Consultații efectuate:', '${vetData!.data()?['consultations'] ?? 0}'),
                _infoTile('Rating:', '${(vetData!.data()?['rating'] ?? 0.0).toStringAsFixed(1)} / 5'),
                const SizedBox(height: 20),
                _sectionTitle('Domenii de expertiză'),
                Wrap(
                  spacing: 8,
                  children: (vetData!.data()?['expertise'] as List<dynamic>? ?? []).map((e) {
                    return Chip(
                      label: Text(e, style: const TextStyle(color: Colors.white)),
                      backgroundColor: Colors.teal.withOpacity(0.5),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Animale tratate'),
                Wrap(
                  spacing: 8,
                  children: (vetData!.data()?['animals'] as List<dynamic>? ?? []).map((e) {
                    return Chip(
                      label: Text(e, style: const TextStyle(color: Colors.white)),
                      backgroundColor: Colors.blueGrey.withOpacity(0.5),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Recenzii de la utilizatori'),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('vets')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection('reviews')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator(color: Colors.white);
                    }
                    final reviews = snapshot.data!.docs;
                    if (reviews.isEmpty) {
                      return const Text('Nicio recenzie încă.', style: TextStyle(color: Colors.white70));
                    }
                    return Column(
                      children: reviews.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(data['userName'], style: const TextStyle(color: Colors.white)),
                          subtitle: Text(data['comment'], style: const TextStyle(color: Colors.white70)),
                          trailing: Text('${data['rating']}/5', style: const TextStyle(color: Colors.tealAccent)),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.tealAccent, size: 20),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
