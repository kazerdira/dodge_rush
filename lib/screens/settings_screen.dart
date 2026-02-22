import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('SYSTEMS', style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        )),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _SectionLabel('PILOT PREFERENCES'),
        _ToggleTile(icon: Icons.volume_up_rounded, label: 'Audio Systems', value: settings.soundEnabled, onChanged: (_) => settings.toggleSound()),
        _ToggleTile(icon: Icons.vibration_rounded, label: 'Haptic Feedback', value: settings.vibrationEnabled, onChanged: (_) => settings.toggleVibration()),
        const SizedBox(height: 24),
        _SectionLabel('MISSION LOG'),
        _InfoTile(icon: Icons.emoji_events_rounded, label: 'Personal Best', value: '${settings.bestScore}'),
        _InfoTile(icon: Icons.rocket_launch_rounded, label: 'Missions Flown', value: '${settings.gamesPlayed}'),
        _InfoTile(icon: Icons.circle, label: 'Credits Collected', value: '${settings.totalCoins}'),
        const SizedBox(height: 24),
        _SectionLabel('SYSTEM INFO'),
        const _InfoTile(icon: Icons.info_outline_rounded, label: 'Version', value: '1.0.0'),
        const _InfoTile(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', value: ''),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(text, style: const TextStyle(
        color: AppTheme.accent,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
      )),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: 14),
        Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        const Spacer(),
        Switch(value: value, onChanged: onChanged, activeColor: AppTheme.accent),
      ]),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(children: [
        Icon(icon, color: AppTheme.textSecondary, size: 18),
        const SizedBox(width: 14),
        Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        const Spacer(),
        if (value.isNotEmpty) Text(value, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        if (value.isEmpty) const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary, size: 13),
      ]),
    );
  }
}
