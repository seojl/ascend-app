import 'dart:ui';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../theme.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Map<String, dynamic>? _player;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final player = await db.getPlayer();
    final items = await db.getShopItems();
    setState(() {
      _player = player;
      _items = items;
      _loading = false;
    });
  }

  Future<void> _redeem(Map<String, dynamic> item) async {
    final player = _player!;
    final cost = item['xp_cost'] as int;
    // Shop redemptions spend from total accumulated level-independent XP tracking
    // is out of scope here; for now this just confirms the redemption as a log entry.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Reward Claimed', style: TextStyle(color: AppColors.text)),
        content: Text('You\'ve earned: ${item['name']}. Go enjoy it - you committed to the work.',
            style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
    final level = _player?['level'] as int? ?? 1;
    final unlockLevel = _player?['shop_unlock_level'] as int? ?? 30;
    final unlocked = level >= unlockLevel;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('XP SHOP', style: TextStyle(color: AppColors.cyan, fontSize: 12, letterSpacing: 2)),
          const SizedBox(height: 4),
          const Text('Redeem Rewards', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 16),
          if (!unlocked) _lockedPanel(level, unlockLevel),
          if (unlocked && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'Shop unlocked! No reward items configured yet - these should be generated based on your personalization answers.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          if (unlocked)
            Expanded(
              child: ListView(
                children: _items.map((item) => _shopItemTile(item, true)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lockedPanel(int level, int unlockLevel) {
    final progress = (level / unlockLevel).clamp(0.0, 1.0);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.border)),
          child: Column(
            children: [
              const Icon(Icons.lock_outline, color: AppColors.muted, size: 28),
              const SizedBox(height: 12),
              Text('Locked Until Level $unlockLevel', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text('You\'re currently Level $level. Keep completing daily quests to unlock the Shop.',
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: AppColors.panel2, color: AppColors.cyan),
              ),
              const SizedBox(height: 6),
              Text('Level $level / $unlockLevel', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Rewards stay hidden until Shop unlocks', style: TextStyle(color: AppColors.muted, fontSize: 10)),
        const SizedBox(height: 10),
        Stack(
          children: [
            Opacity(
              opacity: 0.5,
              child: Column(
                children: [
                  _shopItemTile({'name': '??? ??? ???', 'xp_cost': 0}, false),
                  _shopItemTile({'name': '??? ??? ??? ???', 'xp_cost': 0}, false),
                ],
              ),
            ),
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _shopItemTile(Map<String, dynamic> item, bool enabled) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['name'], style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
              Text('${item['xp_cost']} XP', style: const TextStyle(color: AppColors.cyan, fontSize: 11)),
            ],
          ),
          OutlinedButton(
            onPressed: enabled ? () => _redeem(item) : null,
            style: OutlinedButton.styleFrom(side: BorderSide(color: enabled ? AppColors.cyan : AppColors.border)),
            child: Text(enabled ? 'REDEEM' : 'LOCKED',
                style: TextStyle(color: enabled ? AppColors.cyan : AppColors.muted, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
