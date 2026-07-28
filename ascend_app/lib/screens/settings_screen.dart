import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _newModelController = TextEditingController();
  List<String> _models = [];
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('openrouter_api_key') ?? '';
    final models = await AiService().getModelListPublic();
    setState(() {
      _apiKeyController.text = key;
      _models = models;
    });
  }

  Future<void> _saveKey() async {
    await AiService().saveApiKey(_apiKeyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API key saved.')));
    }
  }

  Future<void> _saveModels() async {
    await AiService().saveModelList(_models);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Model list saved.')));
    }
  }

  void _addModel() {
    final value = _newModelController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _models.add(value);
      _newModelController.clear();
    });
    _saveModels();
  }

  void _removeModel(int index) {
    setState(() => _models.removeAt(index));
    _saveModels();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final ok = await AiService().testConnection();
    setState(() {
      _testing = false;
      _testResult = ok ? 'Working' : 'No response - check your key or try a different model.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('SETTINGS', style: TextStyle(color: AppColors.cyan, fontSize: 12, letterSpacing: 2)),
        const SizedBox(height: 4),
        const Text('AI Configuration', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 20),

        const Text('OpenRouter API Key', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _apiKeyController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'sk-or-v1-...'),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: _saveKey, child: const Text('SAVE KEY')),
        ),

        const SizedBox(height: 28),
        const Text('Model Fallback List', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const Text('Tried in order - if the first is unavailable, the next is used automatically.',
            style: TextStyle(color: AppColors.muted, fontSize: 10)),
        const SizedBox(height: 10),
        for (int i = 0; i < _models.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Text('${i + 1}.', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(width: 8),
                Expanded(child: Text(_models[i], style: const TextStyle(color: AppColors.text, fontSize: 12))),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
                  onPressed: () => _removeModel(i),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newModelController,
                decoration: const InputDecoration(hintText: 'e.g. meta-llama/llama-3.3-70b-instruct:free'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _addModel,
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.cyan)),
              child: const Text('ADD', style: TextStyle(color: AppColors.cyan)),
            ),
          ],
        ),

        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _testing ? null : _testConnection,
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.cyan)),
            child: Text(_testing ? 'TESTING...' : 'TEST CONNECTION', style: const TextStyle(color: AppColors.cyan)),
          ),
        ),
        if (_testResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_testResult!,
                style: TextStyle(color: _testResult == 'Working' ? AppColors.cyan : AppColors.danger, fontSize: 12)),
          ),

        const SizedBox(height: 20),
        const Text(
          'Free OpenRouter models occasionally get discontinued. If quest generation stops working, '
          'find a new :free model ID on openrouter.ai/models and add it above.',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}
