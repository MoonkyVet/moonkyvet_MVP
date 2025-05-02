// 📄 register_vet_page.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_place/google_place.dart';

class RegisterVetPage extends StatefulWidget {
  const RegisterVetPage({super.key});

  @override
  State<RegisterVetPage> createState() => _RegisterVetPageState();
}

class _RegisterVetPageState extends State<RegisterVetPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final experienceController = TextEditingController();
  final caseDescriptionController = TextEditingController();
  final priceController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressFocusNode = FocusNode();

  final List<String> allExpertise = [
    'Dermatologie', 'Ortopedie', 'Chirurgie', 'Nutriție',
    'Animale exotice', 'Vaccinări', 'Oftalmologie'
  ];

  final List<String> animalTypes = [
    'Câini', 'Pisici', 'Păsări', 'Rozătoare', 'Altele'
  ];

  final List<String> levels = ['Doctor', 'Tehnician', 'Asistent'];
  String selectedLevel = 'Doctor';

  List<String> selectedExpertise = [];
  List<String> selectedAnimals = [];

  File? profileImage;
  List<File> diplomaImages = [];
  final ImagePicker picker = ImagePicker();

  late GooglePlace googlePlace;
  List<AutocompletePrediction> predictions = [];

  Future<void> _pickProfileImage() async {
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => profileImage = File(picked.path));
  }

  Future<void> _pickDiplomaImages() async {
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => diplomaImages = picked.map((e) => File(e.path)).toList());
    }
  }

  void _onAddressChanged() async {
    if (_addressController.text.isNotEmpty) {
      var result = await googlePlace.autocomplete.get(_addressController.text);
      if (result != null && result.predictions != null) {
        setState(() => predictions = result.predictions!);
      }
    } else {
      setState(() => predictions = []);
    }
  }

  void _selectPrediction(AutocompletePrediction prediction) {
    _addressController.text = prediction.description!;
    setState(() => predictions = []);
    FocusScope.of(context).unfocus();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushNamed(context, '/set-vet-password', arguments: {
        'name': nameController.text,
        'email': emailController.text,
        'experience': experienceController.text,
        'caseDescription': caseDescriptionController.text,
        'price': priceController.text,
        'address': _addressController.text,
        'expertise': selectedExpertise,
        'animals': selectedAnimals,
        'level': selectedLevel,
        'profileImage': profileImage,
        'diplomaImages': diplomaImages,
      });
    }
  }

  @override
  void initState() {
    super.initState();
    googlePlace = GooglePlace("AIzaSyDGOs5SQxeY3rHvkJgdUE-R8Ip5rApwk-4");
    _addressController.addListener(_onAddressChanged);
    _addressFocusNode.addListener(() {
      if (!_addressFocusNode.hasFocus) {
        setState(() => predictions = []);
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    experienceController.dispose();
    caseDescriptionController.dispose();
    priceController.dispose();
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Înregistrare Veterinar', style: TextStyle(color: Colors.white)),
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
          Container(color: Colors.black.withOpacity(0.9)),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Încărcați o poză clară de profil cu dumneavoastră',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: _pickProfileImage,
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.teal.withOpacity(0.2),
                        backgroundImage: profileImage != null ? FileImage(profileImage!) : null,
                        child: profileImage == null
                            ? const Icon(Icons.camera_alt, color: Colors.white, size: 32)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _darkInput(nameController, 'Nume complet'),
                  _darkInput(emailController, 'Email'),
                  _darkInput(experienceController, 'Experiență (ani)', type: TextInputType.number),
                  _darkInput(caseDescriptionController, 'Cazuri relevante tratate'),
                  _darkInput(priceController, 'Preț consult (lei)', type: TextInputType.number),
                  const SizedBox(height: 16),
                  _buildAddressField(),
                  const SizedBox(height: 16),

                  const Text('Nivel profesional:', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedLevel,
                    dropdownColor: Colors.black87,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: levels.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => selectedLevel = val!),
                  ),

                  const SizedBox(height: 16),
                  const Text('Domenii de expertiză:', style: TextStyle(color: Colors.white)),
                  Wrap(
                    spacing: 8,
                    children: allExpertise.map((e) => FilterChip(
                      label: Text(e),
                      selected: selectedExpertise.contains(e),
                      onSelected: (v) => setState(() => v ? selectedExpertise.add(e) : selectedExpertise.remove(e)),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Animale tratate:', style: TextStyle(color: Colors.white)),
                  Wrap(
                    spacing: 8,
                    children: animalTypes.map((e) => FilterChip(
                      label: Text(e),
                      selected: selectedAnimals.contains(e),
                      onSelected: (v) => setState(() => v ? selectedAnimals.add(e) : selectedAnimals.remove(e)),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _pickDiplomaImages,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Încarcă poze cu diplome'),
                  ),
                  const SizedBox(height: 10),
                  if (diplomaImages.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: diplomaImages.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Image.file(diplomaImages[index]),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Trimite pentru aprobare'),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Adresă cabinet:', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: _addressController,
            focusNode: _addressFocusNode,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Scrie adresa...',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Câmp obligatoriu' : null,
          ),
        ),
        if (predictions.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: predictions.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  border: const Border(top: BorderSide(color: Colors.white10)),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  title: Text(
                    predictions[index].description ?? '',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => _selectPrediction(predictions[index]),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _darkInput(TextEditingController controller, String label, {TextInputType type = TextInputType.text, FocusNode? node}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        focusNode: node,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Câmp obligatoriu' : null,
      ),
    );
  }
}
