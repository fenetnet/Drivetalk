import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/dev_tools.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../debug/debug_screen.dart';
import '../../domain/models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import '../connections/circles_screen.dart';
import 'profile_section.dart';
import 'routines_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final now = ref.watch(nowProvider);
    final profile = ref.watch(profileServiceProvider);
    final prefs = profile.prefs;
    final muted = prefs.beaconMutedUntil?.isAfter(now) ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l.tabSettings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const ProfileSection(),
          SectionTitle(l.settingsDriving),
          SwitchListTile(
            secondary: const Icon(Icons.directions_car_rounded),
            title: Text(l.settingsAutoDriving),
            subtitle: Text(l.settingsAutoDrivingBody),
            value: prefs.autoDrivingAvailability,
            onChanged: (v) async {
              if (v) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(l.settingsAutoDrivingDialogTitle),
                    content: Text(l.settingsAutoDrivingDialogBody),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(l.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(l.enable),
                      ),
                    ],
                  ),
                );
                if (!(ok ?? false)) return;
              }
              await profile.updatePrefs(
                prefs.copyWith(autoDrivingAvailability: v),
              );
            },
          ),
          ListTile(
            enabled: false,
            leading: const Icon(Icons.bluetooth_rounded),
            title: Text(l.settingsCarBluetooth),
            subtitle: Text(l.settingsCarBluetoothSoon),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.record_voice_over_rounded),
            title: Text(l.settingsVoiceReadout),
            subtitle: Text(l.settingsVoiceReadoutBody),
            value: prefs.voiceReadout,
            onChanged: (v) =>
                profile.updatePrefs(prefs.copyWith(voiceReadout: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.mic_rounded),
            title: Text(l.settingsVoiceCommands),
            subtitle: Text(l.settingsVoiceCommandsBody),
            value: prefs.voiceCommands,
            onChanged: (v) =>
                profile.updatePrefs(prefs.copyWith(voiceCommands: v)),
          ),
          ListTile(
            leading: const Icon(Icons.event_repeat_rounded),
            title: Text(l.routinesTitle),
            subtitle: Text(l.routinesCount(prefs.routines.length)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RoutinesScreen()),
            ),
          ),
          SectionTitle(l.settingsRelPrefs),
          ListTile(
            leading: const Icon(Icons.bubble_chart_rounded),
            title: Text(l.circlesTitle),
            subtitle: Text(l.circlesCount(prefs.circles.length)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CirclesScreen()),
            ),
          ),
          for (final t in RelationshipType.values)
            CheckboxListTile(
              dense: true,
              title: Text(relationshipLabel(l, t)),
              value: !prefs.excludedRelationshipTypes.contains(t),
              onChanged: (v) => profile.updatePrefs(
                prefs.copyWith(
                  excludedRelationshipTypes: (v ?? true)
                      ? ({...prefs.excludedRelationshipTypes}..remove(t))
                      : {...prefs.excludedRelationshipTypes, t},
                ),
              ),
            ),
          SectionTitle(l.settingsNotifications),
          RadioGroup<BeaconFrequency>(
            groupValue: prefs.beaconFrequency,
            onChanged: (v) =>
                profile.updatePrefs(prefs.copyWith(beaconFrequency: v)),
            child: Column(
              children: [
                for (final (f, label) in [
                  (BeaconFrequency.normal, l.beaconNormal),
                  (BeaconFrequency.low, l.beaconLow),
                  (BeaconFrequency.off, l.beaconOff),
                ])
                  RadioListTile<BeaconFrequency>(
                    dense: true,
                    value: f,
                    title: Text(label),
                  ),
              ],
            ),
          ),
          if (muted)
            ListTile(
              leading: const Icon(Icons.notifications_off_rounded),
              title: Text(l.settingsMutedUntil(prefs.beaconMutedUntil!)),
              trailing: TextButton(
                onPressed: () =>
                    profile.updatePrefs(prefs.copyWith(clearBeaconMute: true)),
                child: Text(l.unmute),
              ),
            ),
          SectionTitle(l.settingsPrivacy),
          ListTile(
            leading: const Icon(Icons.shield_rounded),
            title: Text(l.privacyTitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded),
            title: Text(l.settingsBlocked),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BlockedUsersScreen(),
              ),
            ),
          ),
          if (kDevTools) ...[
            SectionTitle(l.settingsDevTools),
            ListTile(
              leading: const Icon(Icons.build_rounded),
              title: Text(l.debugTitle),
              subtitle: Text(l.debugSubtitle),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DebugScreen()),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              l.settingsAbout,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (Icons.visibility_rounded, l.privacyShared),
      (Icons.cloud_outlined, l.privacyServer),
      (Icons.location_off_rounded, l.privacyNever),
      (Icons.phone_android_rounded, l.privacyLocal),
      (Icons.timer_outlined, l.privacyExpiry),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final (icon, text) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: AppColors.sageDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final graph = ref.watch(socialGraphServiceProvider);
    final blocked = graph.blockedByMe;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsBlocked)),
      body: blocked.isEmpty
          ? Center(child: Text(l.blockedEmpty))
          : ListView(
              children: [
                for (final p in blocked)
                  ListTile(
                    leading: PersonAvatar(person: p, size: 40),
                    title: Text(p.name),
                    trailing: TextButton(
                      onPressed: () => graph.unblock(p.id),
                      child: Text(l.unblock),
                    ),
                  ),
              ],
            ),
    );
  }
}
