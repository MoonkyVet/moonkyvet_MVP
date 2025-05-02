import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FullJournalPage extends StatefulWidget {
  final String petId;

  const FullJournalPage({super.key, required this.petId});

  @override
  State<FullJournalPage> createState() => _FullJournalPageState();
}

class _FullJournalPageState extends State<FullJournalPage> {
  String _searchQuery = '';
  bool _showFavoritesOnly = false;
  DateTime? _selectedDate;

  final TextEditingController _searchController = TextEditingController();

  void _openAddEntryModal() {
    final TextEditingController textController = TextEditingController();
    bool isFavorite = false;
    List<String> selectedTags = [];
    final List<String> emojiTags = ['🐾', '💩', '🥩', '💤', '🏥', '🎾'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✍️ Adaugă în jurnal', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Scrie ceva despre animalul tău...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: emojiTags.map((tag) {
                  final selected = selectedTags.contains(tag);
                  return ChoiceChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          selectedTags.add(tag);
                        } else {
                          selectedTags.remove(tag);
                        }
                      });
                    },
                    selectedColor: Colors.greenAccent.withOpacity(0.3),
                    backgroundColor: Colors.white10,
                    labelStyle: const TextStyle(color: Colors.white),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: isFavorite,
                        onChanged: (val) => setState(() => isFavorite = val ?? false),
                      ),
                      const Text('Favorit', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final text = textController.text.trim();
                      if (text.isEmpty) return;
                      await FirebaseFirestore.instance
                          .collection('pets')
                          .doc(widget.petId)
                          .collection('journal')
                          .add({
                        'text': text,
                        'createdAt': FieldValue.serverTimestamp(),
                        'tags': selectedTags,
                        'favorite': isFavorite,
                      });
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Salvează'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withOpacity(0.2),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  bool _filterEntry(Map<String, dynamic> data) {
    final matchesSearch = _searchQuery.isEmpty || data['text']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true;
    final matchesFavorite = !_showFavoritesOnly || (data['favorite'] == true);
    final matchesDate = _selectedDate == null || (data['createdAt'] as Timestamp?)?.toDate().day == _selectedDate?.day;
    return matchesSearch && matchesFavorite && matchesDate;
  }

  void _editEntry(String docId, String currentText, List<String> currentTags, bool isFavorite) {
    final controller = TextEditingController(text: currentText);
    List<String> selectedTags = List.from(currentTags);
    bool fav = isFavorite;
    final List<String> emojiTags = ['🐾', '💩', '🥩', '💤', '🏥', '🎾'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('✏️ Editează', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Editează textul...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: emojiTags.map((tag) {
                  final selected = selectedTags.contains(tag);
                  return ChoiceChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          selectedTags.add(tag);
                        } else {
                          selectedTags.remove(tag);
                        }
                      });
                    },
                    selectedColor: Colors.greenAccent.withOpacity(0.3),
                    backgroundColor: Colors.white10,
                    labelStyle: const TextStyle(color: Colors.white),
                  );
                }).toList(),
              ),
              CheckboxListTile(
                value: fav,
                onChanged: (val) => setState(() => fav = val ?? false),
                title: const Text('Favorit', style: TextStyle(color: Colors.white)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.greenAccent,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('pets')
                  .doc(widget.petId)
                  .collection('journal')
                  .doc(docId)
                  .update({
                'text': controller.text.trim(),
                'tags': selectedTags,
                'favorite': fav,
              });
              Navigator.pop(ctx);
            },
            child: const Text('Salvează', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📖 Jurnal', style: TextStyle(color: Colors.white)),
            if (_selectedDate != null)
              Text(
                'Filtrat: ${DateFormat('dd MMM yyyy').format(_selectedDate!)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2022),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.greenAccent,
                        surface: Colors.black,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _selectedDate = null),
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final result = await showSearch(
                context: context,
                delegate: JournalSearchDelegate(petId: widget.petId),
              );
              if (result != null) {
                setState(() => _searchQuery = result);
              }
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _openAddEntryModal,
        backgroundColor: Colors.greenAccent.withOpacity(0.2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pets')
            .doc(widget.petId)
            .collection('journal')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          final entries = snapshot.data!.docs.where((doc) => _filterEntry(doc.data() as Map<String, dynamic>)).toList();

          if (entries.isEmpty) {
            return const Center(child: Text('Nicio intrare.', style: TextStyle(color: Colors.white70)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final doc = entries[index];
              final data = doc.data() as Map<String, dynamic>;
              final date = (data['createdAt'] as Timestamp?)?.toDate();
              final formattedDate = date != null
                  ? DateFormat('dd MMM yyyy, HH:mm').format(date)
                  : 'Fără dată';
              final text = data['text'] ?? '';
              final tags = List<String>.from(data['tags'] ?? []);
              final isFavorite = data['favorite'] == true;

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: Colors.black,
                      title: const Text('Confirmare', style: TextStyle(color: Colors.white)),
                      content: const Text('Sigur vrei să ștergi această intrare?',
                          style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          child: const Text('Anulează'),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        TextButton(
                          child: const Text('Șterge', style: TextStyle(color: Colors.red)),
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) async {
                  await FirebaseFirestore.instance
                      .collection('pets')
                      .doc(widget.petId)
                      .collection('journal')
                      .doc(doc.id)
                      .delete();
                },
                child: GestureDetector(
                  onTap: () => _editEntry(doc.id, text, tags, isFavorite),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(formattedDate,
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            if (isFavorite)
                              const Icon(Icons.star, color: Colors.amber, size: 20),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(text,
                            style: const TextStyle(color: Colors.white, fontSize: 16)),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: tags
                                .map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor: Colors.white24,
                              labelStyle: const TextStyle(color: Colors.white),
                              visualDensity: VisualDensity.compact,
                            ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );

        },
      ),
    );
  }
}

class JournalSearchDelegate extends SearchDelegate<String> {
  final String petId;
  JournalSearchDelegate({required this.petId});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white54),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear),
      onPressed: () => query = '',
    ),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, query));

  @override
  Widget buildResults(BuildContext context) => const SizedBox();

  @override
  Widget buildSuggestions(BuildContext context) => const SizedBox();
}