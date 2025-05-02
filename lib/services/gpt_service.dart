import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:moonkyvet/models/pet_model.dart'; // asigură-te că ai modelul corect PetModel
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<List<Map<String, String>>> generatePetContextConversation(PetModel selectedPet) async {
  final birthYear = int.tryParse(selectedPet.birthDate.split('-')[0]) ?? DateTime.now().year;
  final birthMonth = int.tryParse(selectedPet.birthDate.split('-')[1]) ?? DateTime.now().month;
  final now = DateTime.now();
  final ageYears = now.year - birthYear - (now.month < birthMonth ? 1 : 0);

  // Vaccinuri scurte
  List<String> vaccineDescriptions = [];
  try {
    final other = jsonDecode(selectedPet.otherDetails);
    if (other['vaccinations'] is List) {
      for (final v in other['vaccinations']) {
        final name = v['name'] ?? '';
        final date = v['date'] ?? '';
        if (name.isNotEmpty || date.isNotEmpty) {
          vaccineDescriptions.add("$name - $date");
        }
      }
    }
  } catch (_) {}

  final vaccinesText = vaccineDescriptions.isNotEmpty
      ? "Vaccinations:\n${vaccineDescriptions.join('\n')}"
      : "No vaccination records available.";

  final profile = """
Dog Profile:
- Name: ${selectedPet.name}
- Breed: ${selectedPet.breed}
- Sex: ${selectedPet.sex}
- Age: $ageYears years
- Weight: ${selectedPet.weight > 0 ? "${selectedPet.weight} kg" : "Unknown"}
- Neutered: ${selectedPet.neutered ? "Yes" : "No"}
- Allergies: ${selectedPet.allergies.isNotEmpty ? selectedPet.allergies : "None"}
- Microchip: ${selectedPet.microchipNumber.isNotEmpty ? selectedPet.microchipNumber : "Unavailable"}

$vaccinesText
""";

  return [
    {
      "role": "system",
      "content": """
You are Moonky, a friendly virtual vet assistant. Be kind, calm and practical when helping pet owners.
If unsure about a health issue, recommend visiting a vet.

Here is the dog’s profile. Use it to guide your responses:

$profile
"""
    }
  ];
}

bool useGpt4o = false;

Future<String> sendToChatGPT(List<Map<String, String>> conversation) async {
  final apiKey = dotenv.env['OPENAI_API_KEY'];
  final model = useGpt4o ? "gpt-4o" : "gpt-3.5-turbo";

  try {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        "model": model,
        "messages": conversation,
        "temperature": 0.6,
        "max_tokens": 1000,
      }),
    );

    if (response.statusCode == 200) {
      final decoded = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decoded);
      final content = data['choices'][0]['message']['content'];

      // Detectăm dacă utilizatorul pare nemulțumit
      if (!useGpt4o && _responseSuggestsUnsatisfaction(content)) {
        useGpt4o = true; // trecem la GPT-4o pentru restul conversației
      }

      return content;
    } else {
      print("❌ GPT ERROR: ${response.statusCode} => ${response.body}");
      return "Moonky n-a putut răspunde momentan. Reîncearcă te rog.";
    }
  } catch (e) {
    print("❌ Eroare în sendToChatGPT: $e");
    return "Eroare de rețea. Te rog verifică conexiunea și reîncearcă.";
  }
}

bool _responseSuggestsUnsatisfaction(String content) {
  final text = content.toLowerCase();
  return text.contains("nu pot răspunde") ||
      text.contains("nu sunt sigur") ||
      text.contains("consultă un veterinar") ||
      text.contains("nu înțeleg") ||
      text.contains("nu am suficiente informații") ||
      text.contains("îmi pare rău, dar nu") ||
      text.contains("îți recomand să mergi la medic");
}

Future<Map<String, dynamic>?> extractFieldsFromImagesWithGPT(List<File> images) async {
  final apiKey = dotenv.env['OPENAI_API_KEY'];

  final List<Map<String, dynamic>> imageContents = await Future.wait(images.map((file) async {
    final base64Image = base64Encode(await file.readAsBytes());
    return {
      "type": "image_url",
      "image_url": {
        "url": "data:image/jpeg;base64,$base64Image"
      }
    };
  }));

  final response = await http.post(
    Uri.parse('https://api.openai.com/v1/chat/completions'),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "model": "gpt-4o",
      "messages": [
        {
          "role": "system",
          "content": """
You are a veterinary assistant. The user will send one or more pages from a dog's health book (passport).

Your task is to extract and return ONLY the following data as pure valid JSON (no explanations, no markdown):

{
  "name": "",
  "breed": "",
  "birth_year": "",
  "birth_month": "",
  "microchip_number": "",
  "microchip_location": ""
}

Leave values empty if not found. DO NOT reply with text or explanations. Just valid JSON.
"""
        },
        {
          "role": "user",
          "content": imageContents
        }
      ],
      "temperature": 0.2,
      "max_tokens": 800
    }),
  );

  if (response.statusCode == 200) {
    final decoded = utf8.decode(response.bodyBytes);
    final data = jsonDecode(decoded);
    final content = data['choices'][0]['message']['content'];

    try {
      // Elimină markdown blocuri (```json)
      final cleaned = content
          .replaceAll(RegExp(r'^```json'), '')
          .replaceAll(RegExp(r'^```'), '')
          .replaceAll(RegExp(r'```$'), '')
          .trim();

      return jsonDecode(cleaned);
    } catch (e) {
      print('❌ Eroare la parsare JSON: $e\nRăspuns primit: $content');
    }
  } else {
    print("❌ GPT-4o error: ${response.statusCode} => ${response.body}");
  }

  // 🔁 Fallback la MLKit OCR dacă GPT eșuează
  try {
    print("🔁 Fallback to MLKit OCR...");
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String fullText = '';

    for (final file in images) {
      final inputImage = InputImage.fromFile(file);
      final recognizedText = await textRecognizer.processImage(inputImage);
      fullText += recognizedText.text + '\n';
    }

    await textRecognizer.close();

    return {
      "name": "",
      "breed": "",
      "birth_year": "",
      "birth_month": "",
      "microchip_number": "",
      "microchip_location": "",
      "raw_text": fullText.trim(), // poți folosi la debug sau în pagina de detalii
    };
  } catch (e) {
    print("❌ Eroare la fallback MLKit: $e");
    return null;
  }
}

Future<String> generateOtherDetailsFromHealthBook(String ocrText) async {
  final apiKey = dotenv.env['OPENAI_API_KEY'];
  const url = 'https://api.openai.com/v1/chat/completions';

  final prompt = """
You are a veterinary assistant AI.

You will receive OCR text extracted from one or more pages of a Romanian dog's health book (passport), specifically vaccination sections.

Your goal is to extract and organize the following information in clean **valid JSON** (strictly no markdown, no comments, no explanations):

{
  "vaccinations": [
    {
      "name": "",        // Example: Nobivac DHPPi
      "batch": "",       // Example: C269A01 (often follows 'LOT')
      "date": "",        // Date of vaccination in format YYYY-MM-DD
      "valid_until": ""  // Validity date if found, else empty
    }
  ],
  "deworming": [],
  "microchip": {
    "number": "",        // microchip number if visible in the OCR
    "location": ""       // location of microchip (e.g. left neck)
  },
  "observations": ""     // any free text found under 'Observații'
}

Instructions:
- Do NOT guess. If data is ambiguous, leave it empty.
- If there are multiple vaccine entries, extract each into its own object.
- For batch, look after keywords like "LOT", "Batch", or immediately after the vaccine name.
- For dates, look near the vet signature or under date headers.
- NEVER include markdown (no ```json).
""";

  final body = jsonEncode({
    "model": "gpt-4o",
    "messages": [
      {
        "role": "system",
        "content": prompt
      },
      {
        "role": "user",
        "content": ocrText
      }
    ],
    "temperature": 0.2,
    "max_tokens": 1200,
  });

  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    body: body,
  );

  if (response.statusCode == 200) {
    final decoded = utf8.decode(response.bodyBytes);
    final data = jsonDecode(decoded);
    var content = data['choices'][0]['message']['content'];

    // 🔧 Curățare automată dacă GPT a returnat cu blocuri markdown
    final cleaned = content
        .replaceAll(RegExp(r'^```json'), '')
        .replaceAll(RegExp(r'^```'), '')
        .replaceAll(RegExp(r'```$'), '')
        .trim();

    return cleaned;
  } else {
    print("GPT ERROR: ${response.statusCode} => ${response.body}");
    return '{}';
  }
}


Future<String> generatePersonalizedAdvice(PetModel selectedPet, List<Map<String, dynamic>> latestJournal) async {
  final birthYear = int.tryParse(selectedPet.birthDate.split('-')[0]) ?? DateTime.now().year;
  final birthMonth = int.tryParse(selectedPet.birthDate.split('-')[1]) ?? DateTime.now().month;
  final now = DateTime.now();
  final ageYears = now.year - birthYear - (now.month < birthMonth ? 1 : 0);

  List<String> vaccineDescriptions = [];
  try {
    final other = jsonDecode(selectedPet.otherDetails);
    if (other['vaccinations'] is List) {
      for (final v in other['vaccinations']) {
        final name = v['name'] ?? '';
        final date = v['date'] ?? '';
        if (name.isNotEmpty || date.isNotEmpty) {
          vaccineDescriptions.add("$name - $date");
        }
      }
    }
  } catch (_) {}

  final vaccinesText = vaccineDescriptions.isNotEmpty
      ? vaccineDescriptions.join('\n')
      : "No vaccination records available.";

  final journalText = latestJournal
      .map((entry) => "- ${entry['text']}")
      .join('\n');

  final prompt = """
Ești Moonky, un asistent veterinar virtual prietenos. Ai mai jos profilul complet al câinelui, inclusiv jurnalul cu ultimele observații.

Scopul tău este să oferi 1-2 sfaturi scurte, practice și relevante pentru ziua de azi, pe baza datelor de sănătate și comportament.

🔹 Scrie în limba română.
🔹 Evită stilul formal sau clinic. Fii clar, empatic și util.
🔹 Nu folosi semne de bold (**).
🔹 Nu recomanda controale inutile — doar dacă este cazul.

Profilul câinelui:

Nume: ${selectedPet.name}
Rasă: ${selectedPet.breed}
Sex: ${selectedPet.sex}
Vârstă: $ageYears ani
Greutate: ${selectedPet.weight > 0 ? "${selectedPet.weight} kg" : "Necunoscută"}
Sterilizat: ${selectedPet.neutered ? "Da" : "Nu"}
Alergii: ${selectedPet.allergies.isNotEmpty ? selectedPet.allergies : "Niciuna"}
Microcip: ${selectedPet.microchipNumber.isNotEmpty ? selectedPet.microchipNumber : "Neprecizat"}
Vaccinuri:
$vaccinesText

Ultimele înregistrări în jurnal:
$journalText

Scrie sfaturile pe scurt, ca pentru un stăpân de câine atent.
- în limba română
- clare, empatice și utile
- fără niciun fel de formatare Markdown (nu folosi **bold** sau *italic*)
-nu folosi diactritice
-maxim 2-3 propozitii pe sfat
- evita recomandarile inutile de trimitere la veterinar
-da fiecare sfat pe un rand nou
""";


  return await sendToChatGPT_GPT4o(prompt);
}
Future<String> sendToChatGPT_GPT4o(String userPrompt) async {
  final apiKey = dotenv.env['OPENAI_API_KEY'];

  final response = await http.post(
    Uri.parse('https://api.openai.com/v1/chat/completions'),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "model": "gpt-4o",
      "messages": [
        {
          "role": "system",
          "content": """
Ești Moonky, un asistent veterinar virtual prietenos. Răspunsurile tale trebuie să fie:
- în limba română
- clare, empatice și utile
- fără niciun fel de formatare Markdown (nu folosi **bold** sau *italic*)
-nu folosi diactritice
-maxim 2-3 propozitii pe sfat
- evita recomandarile inutile de trimitere la veterinar
-da fiecare sfat pe un rand nou

Ajută stăpânii de câini cu sfaturi personalizate pe baza profilului animalului.
"""
        },
        {
          "role": "user",
          "content": userPrompt,
        }
      ],
      "temperature": 0.7,
      "max_tokens": 600,
    }),
  );

  if (response.statusCode == 200) {
    final decoded = utf8.decode(response.bodyBytes);
    final data = jsonDecode(decoded);
    return data['choices'][0]['message']['content'];
  } else {
    print("GPT-4o ERROR: ${response.statusCode} => ${response.body}");
    return "Nu am reușit să generăm sfatul acum. Încearcă din nou mai târziu.";
  }
}
