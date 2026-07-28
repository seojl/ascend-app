import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../theme.dart';
import 'main_scaffold.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ignController = TextEditingController();
  final _goalNameController = TextEditingController();
  final _deadlineController = TextEditingController();
  String _category = 'Learning';

  final _categories = const [
    'Learning', 'Career', 'Finance', 'Fitness', 'Health', 'Personal Development', 'Custom'
  ];

  bool _saving = false;

  Future<void> _begin() async {
    if (_ignController.text.trim().isEmpty || _goalNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in your IGN and a first goal.')),
      );
      return;
    }
    setState(() => _saving = true);

    final db = DatabaseHelper.instance;
    await db.createPlayer(_ignController.text.trim());
    await db.addGoal(
      _goalNameController.text.trim(),
      _category,
      null,
      _deadlineController.text.trim().isEmpty ? null : _deadlineController.text.trim(),
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScaffold()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SYSTEM INITIALIZATION',
                    style: TextStyle(color: AppColors.cyan, letterSpacing: 2, fontSize: 12)),
                const SizedBox(height: 6),
                const Text('Welcome, Player',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.text)),
                const SizedBox(height: 20),
                TextField(
                  controller: _ignController,
                  decoration: const InputDecoration(labelText: 'IGN'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _goalNameController,
                  decoration: const InputDecoration(labelText: 'Goal Name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _category,
                  dropdownColor: AppColors.panel2,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _deadlineController,
                  decoration: const InputDecoration(labelText: 'Deadline (e.g. 12 months)'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _begin,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(_saving ? 'STARTING...' : 'BEGIN JOURNEY'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can add more goals anytime from your Goals panel (up to 10 active).',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
