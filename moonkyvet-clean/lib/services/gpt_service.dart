import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/pet_model.dart';

List<Map<String, String>> buildPrompt(String question, PetModel pet) {
  return [
    {
      "role": "system",
      "content": "You are Moonky, a friendly veterinary assistant AI for dog and cat owners. "
          "You give empathetic, informative advice and always recommend consulting a real vet for serious concerns."
    },
    {
      "role": "user",
      "content": "Pet info:\n"
          "Name: ${pet.name}\n"
          "Age: ${pet.age}\n"
          "Breed: ${pet.breed}\n"
          "Sex: ${pet.gender}\n"
          "Medical history: ${pet.history ?? "No known issues"}"
    },
    {
      "role": "user",
      "content": question
    }
  ];
}

Future<String> sendToChatGPT(String question, PetModel pet) async {
  final apiKey = dotenv.env['OPENAI_API_KEY'];
  const url = 'https://api.openai.com/v1/chat/completions';

  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "model": "gpt-3.5-turbo",
      "messages": buildPrompt(question, pet),
      "temperature": 0.7,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  } else {
    print("GPT ERROR: ${response.body}");
    return "Oops, Moonky couldn't respond now.";
  }
}
