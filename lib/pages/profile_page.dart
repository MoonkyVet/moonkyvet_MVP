import 'package:flutter/material.dart';
import 'package:google_place/google_place.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocusNode = FocusNode();

  late GooglePlace googlePlace;
  List<AutocompletePrediction> predictions = [];

  String email = FirebaseAuth.instance.currentUser?.email ?? '';
  bool _suppressPrediction = false;

  Future<void> loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        email = FirebaseAuth.instance.currentUser?.email ?? '';
      });
    }
  }

  Future<void> saveUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'name': _nameController.text.trim(),
      'email': email,
      'address': _addressController.text.trim(),
      'phone': _phoneController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

    loadUserProfile();
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

    // Repornește predicțiile după ce focusul a fost pierdut
    Future.delayed(const Duration(milliseconds: 500), () {
      _suppressPrediction = false;
    });
  }


  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/profile_background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.8)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    AppBar(
                      title: const Text(
                        'Profilul meu',
                        style: TextStyle(color: Colors.white),
                      ),
                      iconTheme: const IconThemeData(color: Colors.white),
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(label: 'Numele meu', controller: _nameController),
                    _buildTextField(label: 'Email', initialValue: email, readOnly: true),
                    _buildAddressField(),
                    _buildTextField(
                      label: 'Numar de telefon',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          try {
                            await saveUserProfile();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Modificari salvate cu success'),
                                backgroundColor: Colors.white24,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Oups!: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: const Text('Salveaza'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.15),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/subscription');
                      },
                      icon: const Icon(Icons.star),
                      label: const Text("Gestioneaza abonament"),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: (val) =>
        !readOnly && (val == null || val.isEmpty) ? 'Enter $label' : null,
      ),
    );
  }

  Widget _buildAddressField() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTextField(
          label: 'Address',
          controller: _addressController,
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
                  border: const Border(
                    top: BorderSide(color: Colors.white10),
                  ),
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
}
