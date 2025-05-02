import 'dart:convert';
import 'package:flutter/material.dart';

class OtherDetailsCard extends StatefulWidget {
  final String otherDetailsJson;
  final ValueChanged<String> onOtherDetailsChanged;

  const OtherDetailsCard({
    Key? key,
    required this.otherDetailsJson,
    required this.onOtherDetailsChanged,
  }) : super(key: key);

  @override
  State<OtherDetailsCard> createState() => _OtherDetailsCardState();
}

class _OtherDetailsCardState extends State<OtherDetailsCard> {
  late Map<String, dynamic> parsed;

  @override
  void initState() {
    super.initState();
    try {
      final cleanJson = widget.otherDetailsJson.replaceAll('```json', '').replaceAll('```', '').trim();
      parsed = jsonDecode(cleanJson);
    } catch (_) {
      parsed = {
        "vaccinations": [],
        "deworming": [],
        "microchip": {"number": "", "location": ""},
        "observations": ""
      };
    }
  }

  void _saveAndNotify() {
    widget.onOtherDetailsChanged(jsonEncode(parsed));
  }

  void _editVaccinations() {
    final vaccinations = List<Map<String, dynamic>>.from(parsed['vaccinations'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 48,
                  child: Stack(
                    children: [
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Vaccinări',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                ...vaccinations.asMap().entries.map((entry) {
                  int index = entry.key;
                  var vaccine = entry.value;
                  return Card(
                    color: Colors.white10,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _textField('Nume', vaccine['name'] ?? '', (val) => vaccine['name'] = val),
                          const SizedBox(height: 8),
                          _textField('Batch', vaccine['batch'] ?? '', (val) => vaccine['batch'] = val),
                          const SizedBox(height: 8),
                          _dateField('Dată vaccinare', vaccine['date'] ?? '', (val) => vaccine['date'] = val),
                          const SizedBox(height: 8),
                          _dateField('Valabil până', vaccine['valid_until'] ?? '', (val) => vaccine['valid_until'] = val),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed: () {
                                vaccinations.removeAt(index);
                                setState(() => parsed['vaccinations'] = vaccinations);
                                Navigator.pop(context);
                                _editVaccinations();
                                _saveAndNotify();
                              },
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    vaccinations.add({"name": "", "batch": "", "date": "", "valid_until": ""});
                    setState(() => parsed['vaccinations'] = vaccinations);
                    Navigator.pop(context);
                    _editVaccinations();
                    _saveAndNotify();
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Adaugă vaccin', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => parsed['vaccinations'] = vaccinations);
                    _saveAndNotify();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Salvează'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }
  Widget _dateField(String label, String initialValue, Function(String) onChanged) {
    final controller = TextEditingController(text: initialValue);
    return GestureDetector(
      onTap: () async {
        FocusScope.of(context).unfocus(); // închide tastatura
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(initialValue) ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.teal,
                  surface: Colors.black87,
                  onSurface: Colors.white,
                ),
                dialogBackgroundColor: Colors.black87,
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          final formatted = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          controller.text = formatted;
          onChanged(formatted);
        }
      },
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: const Icon(Icons.calendar_today, color: Colors.white54),
          ),
        ),
      ),
    );
  }


  void _editDeworming() {
    final deworming = List<String>.from(parsed['deworming'] ?? []);
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Deparazitări', style: TextStyle(color: Colors.white, fontSize: 20)),
              ...deworming.asMap().entries.map((entry) {
                int index = entry.key;
                return ListTile(
                  title: Text(deworming[index], style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      deworming.removeAt(index);
                      setState(() => parsed['deworming'] = deworming);
                      Navigator.pop(context);
                      _editDeworming();
                      _saveAndNotify();
                    },
                  ),
                );
              }),
              const SizedBox(height: 8),
              _textField('Ex: Drontal, 2024-03-12', '', (val) => controller.text = val),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    deworming.add(controller.text.trim());
                    setState(() => parsed['deworming'] = deworming);
                    _saveAndNotify();
                    Navigator.pop(context);
                    _editDeworming();
                  }
                },
                child: const Text('Adaugă deparazitare'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() => parsed['deworming'] = deworming);
                  _saveAndNotify();
                  Navigator.pop(context);
                },
                child: const Text('Salvează'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editMicrochip() {
    final chip = parsed['microchip'] ?? {"number": "", "location": ""};
    final numberCtrl = TextEditingController(text: chip['number'] ?? '');
    final locationCtrl = TextEditingController(text: chip['location'] ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Date microcip', style: TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 12),
              _textField('Număr microcip', numberCtrl.text, (val) => chip['number'] = val),
              const SizedBox(height: 12),
              _textField('Locație', locationCtrl.text, (val) => chip['location'] = val),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => parsed['microchip'] = chip);
                  _saveAndNotify();
                  Navigator.pop(context);
                },
                child: const Text('Salvează'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(String label, String initialValue, Function(String) onChanged) {
    final controller = TextEditingController(text: initialValue);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vaccinations = parsed['vaccinations'] as List;
    final deworming = parsed['deworming'] as List;
    final microchip = parsed['microchip'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _sectionTitle('Detalii suplimentare AI:'),
        const SizedBox(height: 12),
        _editableTile(
          label: 'Vaccinări',
          value: vaccinations.isEmpty ? 'Fără vaccinări' : '${vaccinations.length} vaccinuri',
          onTap: _editVaccinations,
        ),
        _editableTile(
          label: 'Deparazitări',
          value: deworming.isEmpty ? 'Nicio deparazitare' : '${deworming.length} înregistrări',
          onTap: _editDeworming,
        ),
        _editableTile(
          label: 'Microcip',
          value: 'Nr: ${microchip['number'] ?? '-'}, Loc: ${microchip['location'] ?? '-'}',
          onTap: _editMicrochip,
        ),
      ],
    );
  }

  Widget _editableTile({required String label, required String value, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      title: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
      subtitle: Text(value, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.edit, color: Colors.white54),
      onTap: onTap,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
  }
}
