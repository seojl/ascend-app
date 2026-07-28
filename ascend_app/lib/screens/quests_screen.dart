import 'package:flutter/material.dart';
import 'dart:convert';
import '../db/database_helper.dart';
import '../services/ai_service.dart';
import '../theme.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  List<Map<String, dynamic>> _quests = [];
  bool _loading = true;
  bool _generating = false;
  final Map<int, TextEditingController> _inputControllers = {};

  String get _todayStr => DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final quests = await DatabaseHelper.instance.getTodaysQuests(_todayStr);
    setState(() {
      _quests = quests;
      _loading = false;
      for (final q in quests) {
        _inputControllers.putIfAbsent(q['id'] as int, () => TextEditingController());
      }
    });
  }

  Future<void> _generateQuests() async {
    setState(() => _generating = true);
    final db = DatabaseHelper.instance;
    final goals = await db.getActiveGoals();
    final rate = await db.getRecentCompletionRate(7);
    final ai = AiService();

    List<Map<String, dynamic>> newQuests = [];

    final aiResult = await ai.generateDailyQuests(goals: goals, recentCompletionRate: rate);

    if (aiResult != null) {
      try {
        // Strip any accidental markdown fences before parsing
        final cleaned = aiResult.replaceAll('```json', '').replaceAll('```', '').trim();
        final parsed = jsonDecode(cleaned);
        final list = parsed['quests'] as List;
        for (final item in list) {
          newQuests.add({
            'description': item['description'],
            'quest_type': item['quest_type'] ?? 'daily',
            'target_amount': (item['target_amount'] as num).toDouble(),
            'unit': item['unit'] ?? 'unit',
            'xp_reward': item['xp_reward'] ?? 50,
          });
        }
      } catch (_) {
        newQuests = [];
      }
    }

    // Local fallback if the AI was unavailable or returned something unparseable
    if (newQuests.isEmpty) {
      for (final goal in goals) {
        newQuests.add({
          'description': 'Make progress on: ${goal['name']}',
          'quest_type': 'daily',
          'target_amount': 1.0,
          'unit': 'session',
          'xp_reward': 50,
        });
      }
    }

    for (final q in newQuests) {
      await db.addQuest({
        'description': q['description'],
        'quest_type': q['quest_type'],
        'target_amount': q['target_amount'],
        'current_amount': 0.0,
        'unit': q['unit'],
        'xp_reward': q['xp_reward'],
        'status': 'active',
        'quest_date': _todayStr,
      });
    }

    setState(() => _generating = false);
    if (aiResult == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI unavailable today - showing basic quests instead.')),
      );
    }
    _load();
  }

  Future<void> _logProgress(Map<String, dynamic> quest) async {
    final controller = _inputControllers[quest['id']]!;
    final amount = double.tryParse(controller.text);
    if (amount == null) return;
    await DatabaseHelper.instance.logProgress(quest['id'] as int, amount);
    controller.clear();
    _load();
  }

  Future<void> _completeQuest(Map<String, dynamic> quest) async {
    final db = DatabaseHelper.instance;
    await db.completeQuest(quest['id'] as int);
    await db.logHistory(quest['id'] as int, true, quest['xp_reward'] as int);

    final player = await db.getPlayer();
    if (player == null) return;

    final buffs = await db.getBuffs();
    int bonusPercent = buffs.fold(0, (sum, b) => sum + (b['xp_bonus_percent'] as int));

    int xpGain = quest['xp_reward'] as int;
    xpGain = (xpGain * (1 + bonusPercent / 100)).round();

    int newXp = (player['xp'] as int) + xpGain;
    int newLevel = player['level'] as int;
    int needed = newLevel * 100;

    while (newXp >= needed) {
      newXp -= needed;
      newLevel += 1;
      needed = newLevel * 100;
    }

    await db.updatePlayerXp(player['id'] as int, newXp, newLevel);
    await _checkStreakBuff();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quest complete! +$xpGain XP')),
      );
    }
    _load();
  }

  Future<void> _checkStreakBuff() async {
    final db = DatabaseHelper.instance;
    final rate = await db.getRecentCompletionRate(15);
    final buffs = await db.getBuffs();
    final alreadyHas = buffs.any((b) => b['name'] == 'Discipline Apprentice');
    if (rate >= 0.9 && !alreadyHas) {
      await db.addBuff('Discipline Apprentice', '15-day consistency streak', 5);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.cyan));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DAILY RESET · 6:00 AM PHT', style: TextStyle(color: AppColors.cyan, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text("Today's Quests", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 16),
          Expanded(
            child: _quests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No quests generated yet today.', style: TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _generating ? null : _generateQuests,
                          child: Text(_generating ? 'GENERATING...' : 'GENERATE QUESTS'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: _quests.map((q) => _questCard(q)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _questCard(Map<String, dynamic> quest) {
    final isSide = quest['quest_type'] == 'side';
    final current = (quest['current_amount'] as num).toDouble();
    final target = (quest['target_amount'] as num).toDouble();
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final ready = current >= target;
    final completed = quest['status'] == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(
          left: BorderSide(color: isSide ? AppColors.violet : AppColors.cyan, width: 3),
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(quest['description'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text)),
              ),
              if (isSide)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.violet)),
                  child: const Text('SIDE QUEST', style: TextStyle(color: AppColors.violet, fontSize: 9)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.panel2,
              color: isSide ? AppColors.violet : AppColors.cyan,
            ),
          ),
          const SizedBox(height: 6),
          Text('${current.toStringAsFixed(current == current.roundToDouble() ? 0 : 1)} / ${target.toStringAsFixed(target == target.roundToDouble() ? 0 : 1)} ${quest['unit']}  ·  +${quest['xp_reward']} XP',
              style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          if (!completed) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputControllers[quest['id']],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: 'Add ${quest['unit']}', isDense: true),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _logProgress(quest),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.cyan)),
                  child: const Text('LOG', style: TextStyle(color: AppColors.cyan, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: ready ? () => _completeQuest(quest) : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: ready ? AppColors.cyan : AppColors.border),
                ),
                child: Text(
                  ready ? 'MARK COMPLETE' : 'MARK COMPLETE (locked until $target/$target)',
                  style: TextStyle(color: ready ? AppColors.cyan : AppColors.muted, fontSize: 11),
                ),
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('✓ COMPLETED', style: TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
