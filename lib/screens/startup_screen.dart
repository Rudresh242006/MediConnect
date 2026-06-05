import 'package:flutter/material.dart';

import '../services/session_service.dart';

/// Resolves saved patient/doctor session before showing portal selection.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    final session = await SessionService.getActiveSession();
    if (!mounted) return;

    switch (session.kind) {
      case SessionKind.doctor:
        Navigator.pushReplacementNamed(context, '/doctor');
        break;
      case SessionKind.patient:
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
          arguments: session.patient,
        );
        break;
      case SessionKind.none:
        Navigator.pushReplacementNamed(context, '/');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
