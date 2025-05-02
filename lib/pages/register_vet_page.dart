import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_place/google_place.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _suppressPrediction = false;

  bool emailExists = false;
  bool checkingEmail = false;

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
    if (_suppressPrediction) return;

    final input = _addressController.text.trim();
    if (input.isNotEmpty) {
      var result = await googlePlace.autocomplete.get(input);
      if (result != null && result.predictions != null) {
        setState(() => predictions = result.predictions!.take(3).toList());
      }
    } else {
      setState(() => predictions = []);
    }
  }

  void _selectPrediction(AutocompletePrediction prediction) {
    _suppressPrediction = true;
    _addressController
      ..text = prediction.description!
      ..selection = TextSelection.collapsed(offset: prediction.description!.length);

    setState(() => predictions = []);
    FocusScope.of(context).unfocus();

    Future.delayed(const Duration(milliseconds: 500), () {
      _suppressPrediction = false;
    });
  }

  void _checkEmailInUse() async {
    final input = emailController.text.trim();
    if (input.isEmpty) {
      setState(() {
        emailExists = false;
        checkingEmail = false;
      });
      return;
    }

    setState(() => checkingEmail = true);

    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(input);
      if (methods.isNotEmpty) {
        setState(() {
          emailExists = true;
          checkingEmail = false;
        });
        return; // STOP aici
      }

      final users = await FirebaseFirestore.instance.collection('users')
          .where('email', isEqualTo: input).limit(1).get();

      if (users.docs.isNotEmpty) {
        setState(() {
          emailExists = true;
          checkingEmail = false;
        });
        return; // STOP aici
      }

      final vets = await FirebaseFirestore.instance.collection('vets')
          .where('email', isEqualTo: input).limit(1).get();

      setState(() {
        emailExists = vets.docs.isNotEmpty;
        checkingEmail = false;
      });

    } catch (e) {
      setState(() => checkingEmail = false);
    }
  }


  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final email = emailController.text.trim();

      try {
        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);

        if (methods.isNotEmpty) {
          if (methods.contains('password')) {
            // Exista cont pe email+parola -> nu il lasam
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Există deja un cont cu acest email.')),
            );
            return;
          } else {
            // Exista cont, dar creat prin Google (sau altceva)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Există deja un cont asociat cu Google. Autentifică-te prin Google.')),
            );
            return;
          }
        }

        // Dacă emailul nu există deloc -> continuăm la setare parolă
        Navigator.pushNamed(context, '/set-vet-password', arguments: {
          'name': nameController.text,
          'email': emailController.text,
          'experience': experienceController.text,
          'price': priceController.text,
          'address': _addressController.text,
          'expertise': selectedExpertise,
          'animals': selectedAnimals,
          'level': selectedLevel,
          'profileImage': profileImage,
          'diplomaImages': diplomaImages,
        });

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la verificarea emailului: $e')),
        );
      }
    }
  }

  Future<void> _saveVetProfileWithoutCreatingAuthUser() async {
    final vetDoc = FirebaseFirestore.instance.collection('vets').doc();

    await vetDoc.set({
      'name': nameController.text,
      'email': emailController.text,
      'experience': experienceController.text,
      'price': priceController.text,
      'address': _addressController.text,
      'expertise': selectedExpertise,
      'animals': selectedAnimals,
      'level': selectedLevel,
      'status': 'PENDING',
      'createdAt': Timestamp.now(),
    });

    // Dacă vrei, poți face aici și upload la poze (profileImage, diplomaImages)

    Navigator.pushNamedAndRemoveUntil(context, '/vet-confirmation', (route) => false);
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
    emailController.addListener(_checkEmailInUse);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    experienceController.dispose();
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
            padding: const EdgeInsets.only(top: 70, left: 20, right: 20, bottom: 0),
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
                  _buildEmailInput(),
                  _darkInput(experienceController, 'Experiență (ani)', type: TextInputType.number),
                  _darkInput(priceController, 'Preț consult online (lei)', type: TextInputType.number),
                  const SizedBox(height: 3),
                  _buildAddressField(),
                  SizedBox(height: predictions.isNotEmpty ? 0 : 16),
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
                  const Text('Demonstrează statutul de veterinar/tehnician/asistent:', style: TextStyle(color: Colors.white)),
                  ElevatedButton.icon(
                    onPressed: _pickDiplomaImages,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Încarcă poze cu documentele dvs.'),
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

  Widget _buildEmailInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: const TextStyle(color: Colors.white70),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: checkingEmail
                  ? const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
                  : emailController.text.isEmpty
                  ? null
                  : emailExists
                  ? const Icon(Icons.close, color: Colors.red)
                  : const Icon(Icons.check, color: Colors.green),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Câmp obligatoriu';
              if (emailExists) return 'Email deja folosit';
              return null;
            },
          ),
        ),
        if (emailExists)
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 4),
            child: Text(
              'Există deja un cont cu acest email.',
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: _addressController,
            focusNode: _addressFocusNode,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Adresă cabinet:',
              labelStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Câmp obligatoriu' : null,
          ),
        ),
        if (predictions.isNotEmpty)
          ...predictions.map((prediction) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                border: const Border(top: BorderSide(color: Colors.white10)),
              ),
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                title: Text(
                  prediction.description ?? '',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => _selectPrediction(prediction),
              ),
            );
          }),
      ],
    );
  }

  Widget _darkInput(
      TextEditingController controller,
      String label, {
        TextInputType type = TextInputType.text,
        FocusNode? node,
      }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: node,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Câmp obligatoriu' : null,
      ),
    );
  }
}
