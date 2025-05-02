import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gpt_service.dart';
import 'package:moonkyvet/models/pet_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final PetModel selectedPet;
  const ChatPage({super.key, required this.selectedPet});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, String>> _chatMessages = [];
  final List<Map<String, String>> _conversation = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isThinking = false;
  bool _isListening = false;
  int _typingDots = 0;
  Timer? _typingTimer;
  Timer? _scrollTimer;
  bool _initialized = false;

  static const String _cacheKeyChat = "cached_chat_messages";
  static const String _cacheKeyConversation = "cached_conversation";

  @override
  void initState() {
    super.initState();
    _checkSubscription(); // 👈 verificare abonament
    _loadConversation();
  }

  Future<void> _checkSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final isActive = userDoc.data()?['subscriptionActive'] == true;

    if (!isActive) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No active subscription'),
          content: const Text('You need an active subscription to chat with Moonky.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _loadConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedChat = prefs.getString(_cacheKeyChat);
    final cachedConversation = prefs.getString(_cacheKeyConversation);

    if (cachedChat != null && cachedConversation != null) {
      final List decodedChat = jsonDecode(cachedChat);
      final List decodedConversation = jsonDecode(cachedConversation);

      final restoredChat = decodedChat.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
      final restoredConversation = decodedConversation.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();

      setState(() {
        _chatMessages.addAll(restoredChat);
        _conversation.addAll(restoredConversation);
        _initialized = true;
      });
    } else {
      await _initializeConversation();
    }
  }

  Future<void> _saveConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedChat = jsonEncode(_chatMessages);
    final encodedConversation = jsonEncode(_conversation);

    await prefs.setString(_cacheKeyChat, encodedChat);
    await prefs.setString(_cacheKeyConversation, encodedConversation);
  }

  Future<void> _clearConversation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKeyChat);
    await prefs.remove(_cacheKeyConversation);
  }

  Future<void> _initializeConversation() async {
    final contextMessages = await generatePetContextConversation(widget.selectedPet);
    _conversation.addAll(contextMessages);
    setState(() {
      _initialized = true;
    });
  }

  void _sendMessage() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _isThinking || !_initialized) return;

    setState(() {
      _chatMessages.add({'role': 'user', 'content': input});
      _conversation.add({'role': 'user', 'content': input});
      _controller.clear();
      _isThinking = true;
    });

    await _playSound('sounds/send.mp3');
    await _scrollToBottom();
    await _saveConversation();
    _startTypingAnimation();

    final response = await sendToChatGPT(_conversation);

    _stopTypingAnimation();

    setState(() {
      _chatMessages.add({'role': 'assistant', 'content': response});
      _conversation.add({'role': 'assistant', 'content': response});
      _isThinking = false;
    });

    await _playSound('sounds/receive.mp3');
    await _scrollToBottom();
    await _saveConversation();
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
          });
        },
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _playSound(String path) async {
    try {
      await _audioPlayer.play(AssetSource(path));
    } catch (e) {
      print('Eroare la redarea sunetului: $e');
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("ro-RO");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  void _startTypingAnimation() {
    _typingTimer?.cancel();
    _scrollTimer?.cancel();

    _typingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _typingDots = (_typingDots + 1) % 4;
      });
    });

    _scrollTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _stopTypingAnimation() {
    _typingTimer?.cancel();
    _scrollTimer?.cancel();
    _typingDots = 0;
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Părăsești conversația?', style: TextStyle(color: Colors.white)),
        content: const Text('Conversația va fi ștearsă. Ești sigur?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge și Ieși', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (shouldExit ?? false) {
      await _clearConversation();
      Navigator.pop(context);
    }
  }

  Widget _buildMessage(Map<String, String> message, bool isLast) {
    final isUser = message['role'] == 'user';
    final bgColor = isUser ? Colors.deepPurpleAccent : Colors.white10;
    final textColor = Colors.white;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final content = message['content'] ?? '';

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: isLast ? const Offset(0, 0.1) : Offset.zero,
        child: Align(
          alignment: alignment,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
                bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(2, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: TextStyle(color: textColor, fontSize: 16, height: 1.4),
                ),
                if (!isUser) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.white70, size: 20),
                        onPressed: () => _speak(content),
                        tooltip: "Ascultă răspunsul",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.stop, color: Colors.white70, size: 20),
                        onPressed: () => _flutterTts.stop(),
                        tooltip: "Oprește audio",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(1, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            double opacity = (_typingDots >= index + 1) ? 1.0 : 0.3;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _scrollTimer?.cancel();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Talk with Moonky', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context), // ❗️ DOAR iesim, nu mai stergem
        ),

      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: _chatMessages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isThinking && index == _chatMessages.length) {
                  return _buildTypingIndicator();
                } else {
                  return _buildMessage(_chatMessages[index], index == _chatMessages.length - 1);
                }
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Întreabă-l pe Moonky ceva...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.redAccent),
                    onPressed: _isListening ? _stopListening : _startListening,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.deepPurpleAccent),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
