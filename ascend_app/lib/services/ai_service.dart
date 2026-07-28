import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiService {
  static const _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';

  // Reads the user's saved API key and their ordered list of model IDs to try.
  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('openrouter_api_key');
  }

  Future<List<String>> _getModelList() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('model_fallback_list');
    if (saved != null && saved.isNotEmpty) return saved;
    // Sensible default fallback chain - user can edit this in Settings any time.
    return [
      'qwen/qwen3-coder:free',
      'meta-llama/llama-3.3-70b-instruct:free',
      'google/gemma-3-27b-it:free',
    ];
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openrouter_api_key', key);
  }

  Future<void> saveModelList(List<String> models) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('model_fallback_list', models);
  }

  Future<List<String>> getModelListPublic() => _getModelList();

  // Tries each model in order. Returns the raw text response, or null if every model failed.
  Future<String?> _callWithFallback(String systemPrompt, String userPrompt) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final models = await _getModelList();

    for (final model in models) {
      try {
        final response = await http.post(
          Uri.parse(_openRouterUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
          }),
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final content = data['choices']?[0]?['message']?['content'];
          if (content != null && content.toString().trim().isNotEmpty) {
            return content.toString();
          }
        }
        // Non-200 or empty content: fall through and try the next model.
      } catch (_) {
        // Network error, timeout, or model unavailable: try the next model.
        continue;
      }
    }
    return null; // every model in the list failed
  }

  // Tests whether the currently configured key + first model can respond at all.
  // Used by the "Test Connection" button in Settings.
  Future<bool> testConnection() async {
    final result = await _callWithFallback(
      'Reply with exactly one word: OK',
      'Respond with OK',
    );
    return result != null;
  }

  // Generates today's quests based on active goals and recent completion trends.
  // Returns null if the AI is fully unavailable - caller should use a local fallback.
  Future<String?> generateDailyQuests({
    required List<Map<String, dynamic>> goals,
    required double recentCompletionRate,
  }) async {
    final systemPrompt = '''
You are the "System" in a personal RPG life-progression app called Ascend, inspired by Solo Leveling.
Generate realistic, achievable daily quests for the player based on their active goals.
Rules:
- Quests must be achievable in a single day, never unrealistic (e.g. never "study 8 hours").
- If recent completion rate is below 50%, generate slightly EASIER quests than before.
- If recent completion rate is above 85%, generate slightly HARDER quests than before.
- Each goal should get one core/fundamental quest. Occasionally (not every day) add one optional
  side quest per goal that is related but not mandatory, with its own short deadline (2-5 days)
  and bonus XP.
- Reply ONLY with valid JSON, no other text, in this exact shape:
{"quests":[{"goal_name":"...", "description":"...", "quest_type":"daily", "target_amount":30, "unit":"minutes", "xp_reward":50}]}
''';

    final userPrompt = '''
Active goals: ${jsonEncode(goals)}
Recent completion rate (last 7 days): ${(recentCompletionRate * 100).toStringAsFixed(0)}%
Generate today's quest list now.
''';

    return await _callWithFallback(systemPrompt, userPrompt);
  }

  // Generates a short, in-character check-in message from "the System".
  // Called occasionally/contextually, never in response to the user initiating.
  Future<String?> generateSystemMessage({required String context}) async {
    final systemPrompt = '''
You are the "System" - an AI presence in the Ascend app, similar to the System in Solo Leveling.
You occasionally check in on the player unprompted. Keep messages short (1-3 sentences), in-character,
supportive but not saccharine. Never break character. Reply with plain text only, no JSON.
''';
    return await _callWithFallback(systemPrompt, context);
  }
}
