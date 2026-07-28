import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../theme.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  Map<String, dynamic>? _player;
  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _buffs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final player = await db.getPlayer();
    final goals = await db.getActiveGoals();
    final buffs = await db.getBuffs();
    setState(() {
      _player = player;
      _goals = goals;
      _buffs = buffs;
      _loading = false;
    });
  }

  int _xpNeeded(int level) => level * 100;

  String _levelTitle(int level) {
    if (level >= 100) return 'Master';
    if (level >= 50) return 'Elite';
    if (level >= 10) return 'Awakened';
    return 'Novice';
  }

  Future<void> _showAddGoalDialog() async {
    if (_goals.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have 10 active goals - the max allowed.')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final deadlineCtrl = TextEditingController();
    String category = 'Learning';
    const categories = [
      'Learning', 'Career', 'Finance', 'Fitness', 'Health', 'Personal Development', 'Custom'
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Add A Goal', style: TextStyle(color: AppColors.text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Goal Name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: AppColors.panel2,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? category),
                ),
                const SizedBox(height: 12),
                TextField(controller: targetCtrl, decoration: const InputDecoration(labelText: 'Target Outcome')),
                const SizedBox(height: 12),
                TextField(controller: deadlineCtrl, decoration: const InputDecoration(labelText: 'Deadline')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await DatabaseHelper.instance.addGoal(
                  nameCtrl.text.trim(),
                  category,
                  targetCtrl.text.trim().isEmpty ? null : targetCtrl.text.trim(),
                  deadlineCtrl.text.trim().isEmpty ? null : deadlineCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save Goal'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
    if (_player == null) return const Center(child: Text('No player found.'));

    final level = _player!['level'] as int;
    final xp = _player!['xp'] as int;
    final needed = _xpNeeded(level);
    final progress = (xp / needed).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('CHARACTER SHEET', style: TextStyle(color: AppColors.cyan, fontSize: 12, letterSpacing: 2)),
        const SizedBox(height: 4),
        const Text('Player Status', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.panel,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statRow('IGN', _player!['ign']),
              _statRow('LEVEL', '$level'),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(border: Border.all(color: AppColors.violet)),
                child: Text(_levelTitle(level), style: const TextStyle(color: AppColors.violet, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              for (final buff in _buffs)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('+ ${buff['name']} (+${buff['xp_bonus_percent']}% XP)',
                      style: const TextStyle(color: AppColors.violet, fontSize: 12)),
                ),
              const SizedBox(height: 14),
              _statRow('XP', '$xp / $needed'),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.panel2,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.panel,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GOALS (${_goals.length}/10)', style: const TextStyle(color: AppColors.cyan, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 8),
              for (final goal in _goals)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(goal['name'], style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                          Text(goal['category'], style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
                        child: const Text('COMMITTED', style: TextStyle(color: AppColors.muted, fontSize: 9)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _showAddGoalDialog,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cyan, style: BorderStyle.solid),
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('+ ADD NEW GOAL', style: TextStyle(color: AppColors.cyan, fontSize: 12, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1)),
          Text(value, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
