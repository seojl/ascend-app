import 'package:flutter/material.dart';
import 'db/database_helper.dart';
import 'theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AscendApp());
}

class AscendApp extends StatelessWidget {
  const AscendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ascend',
      debugShowCheckedModeBanner: false,
      theme: buildAscendTheme(),
      home: const _StartupRouter(),
    );
  }
}

// Checks whether a player profile already exists on disk. If yes, skip straight
// to the main app (Status/Quests/Shop/Settings). If no, show onboarding.
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  bool _loading = true;
  bool _hasPlayer = false;

  @override
  void initState() {
    super.initState();
    _checkPlayer();
  }

  Future<void> _checkPlayer() async {
    final player = await DatabaseHelper.instance.getPlayer();
    setState(() {
      _hasPlayer = player != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
      );
    }
    return _hasPlayer ? const MainScaffold() : const OnboardingScreen();
  }
}
