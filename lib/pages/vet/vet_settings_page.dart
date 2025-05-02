import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/vet_settings_service.dart';
import 'package:moonkyvet/models/time_of_day_range.dart';


class VetSettingsPage extends StatefulWidget {
  const VetSettingsPage({super.key});

  @override
  State<VetSettingsPage> createState() => _VetSettingsPageState();
}

class _VetSettingsPageState extends State<VetSettingsPage> {
  final VetSettingsService _settingsService = VetSettingsService();
  String vetEmail = '';
  bool vetAvailabilityNow = false;
  final TextEditingController _videoRateController = TextEditingController();
  final TextEditingController _messageRateController = TextEditingController();

  final List<String> daysOfWeek = [
    'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă', 'Duminică'
  ];

  Map<String, TimeOfDayRange?> availability = {};

  @override
  void initState() {
    super.initState();
    _loadVetData();
  }

  Future<void> _loadVetData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _settingsService.loadVetSettings();
      if (mounted && data != null) {
        setState(() {
          vetEmail = user.email ?? '';
          vetAvailabilityNow = data['vetAvailabilityNow'] ?? false;
          _videoRateController.text = (data['videoRate'] ?? '').toString();
          _messageRateController.text = (data['messageRate'] ?? '').toString();
          availability = _settingsService.parseAvailability(data['availability']);
        });
      }
    }
  }

  void _saveVetData() async {
    try {
      await _settingsService.saveVetSettings(
        vetAvailabilityNow: vetAvailabilityNow,
        videoRate: double.tryParse(_videoRateController.text) ?? 0,
        messageRate: double.tryParse(_messageRateController.text) ?? 0,
        availability: availability,
        context: context,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setările au fost salvate.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la salvare: $e')),
      );
    }
  }

  void _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email pentru resetarea parolei a fost trimis.')),
      );
    }
  }

  Future<void> _pickTimeRange(String day) async {
    final result = await showTimeRangePicker(context);
    if (result != null) {
      setState(() {
        availability[day] = result;
      });
    }
  }

  Future<TimeOfDayRange?> showTimeRangePicker(BuildContext context) async {
    final TimeOfDay? start = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (start == null) return null;
    final TimeOfDay? end = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 17, minute: 0));
    if (end == null) return null;
    return TimeOfDayRange(start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Setări', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveVetData,
          ),
        ],
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email: $vetEmail', style: const TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 20),

                  SwitchListTile(
                    title: const Text('Sunt disponibil acum', style: TextStyle(color: Colors.white)),
                    value: vetAvailabilityNow,
                    onChanged: (val) => setState(() => vetAvailabilityNow = val),
                    activeColor: Colors.greenAccent,
                  ),

                  const SizedBox(height: 20),
                  const Text('Tarife:', style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 10),
                  _rateField(_videoRateController, 'Tarif video (lei)'),
                  const SizedBox(height: 10),
                  _rateField(_messageRateController, 'Tarif mesaje (lei)'),

                  const SizedBox(height: 30),
                  const Text('Disponibilitate:', style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 10),
                  ...daysOfWeek.map((day) {
                    final range = availability[day];
                    final text = range == null
                        ? 'Nu este setat'
                        : '${range.start.format(context)} - ${range.end.format(context)}';
                    return ListTile(
                      title: Text(day, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(text, style: const TextStyle(color: Colors.white70)),
                      trailing: const Icon(Icons.edit, color: Colors.white70),
                      onTap: () => _pickTimeRange(day),
                    );
                  }).toList(),

                  const SizedBox(height: 30),
                  _settingsButton(
                    icon: Icons.lock_reset,
                    title: 'Schimbă parola',
                    onTap: _changePassword,
                  ),
                  const SizedBox(height: 20),
                  _settingsButton(
                    icon: Icons.info_outline,
                    title: 'Despre aplicație',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Despre MoonkyVet'),
                          content: const Text('MoonkyVet AI - Platformă de consultații veterinare online.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Închide'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white12,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _settingsButton({required IconData icon, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 20),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}
