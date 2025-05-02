
import 'package:flutter/material.dart';
import '../services/gpt_service.dart';
import '../models/pet_model.dart';
import 'pets_page.dart';

class ChatPage extends StatefulWidget {
  final Pet? selectedPet;
  const ChatPage({super.key, this.selectedPet});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isThinking = false;
  Pet? pet;

  @override
  void initState() {
    super.initState();
    _initPet();
  }

  void _initPet() async {
    pet = widget.selectedPet;

    if (pet == null) {
      Future.delayed(Duration.zero, () async {
        if (!mounted) return;
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PetsPage(returnPet: true)),
        );
        if (!mounted) return;
        if (result is Pet) {
          setState(() => pet = result);
        } else {
          Navigator.pop(context);
        }
      });
    }
  }

  void _sendMessage() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _isThinking || pet == null) return;

    setState(() {
      _messages.add({'role': 'user', 'content': input});
      _controller.clear();
      _isThinking = true;
    });

    final petModel = PetModel.fromPet(pet!);
    final response = await sendToChatGPT(input, petModel);

    setState(() {
      _messages.add({'role': 'moonky', 'content': response});
      _isThinking = false;
    });

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 150,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildMessage(Map<String, String> message) {
    final isUser = message['role'] == 'user';
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser ? Colors.deepPurpleAccent : Colors.white10;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message['content'] ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildThinkingMoonky() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 8),
          Text(
            'Moonky is thinking... 🧠',
            style: TextStyle(color: Colors.white54),
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
        title: const Text('Talk with Moonky'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isThinking && index == _messages.length) {
                  return _buildThinkingMoonky();
                }
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.black,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Ask something...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurpleAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
