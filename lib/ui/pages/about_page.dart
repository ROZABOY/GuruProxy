import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/strings.dart';
import '../../theme/guru_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.locale.languageCode == 'fa');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/brand/app-icon.png',
                width: 72,
                height: 72,
                errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 64, color: GuruTheme.sand),
              ),
              const SizedBox(height: 12),
              Text(s.aboutTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('v1.0 · Flutter', style: TextStyle(color: Color(0xFF8FA3A7), fontSize: 12)),
              const SizedBox(height: 16),
              Text(
                s.aboutBody,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.45, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
