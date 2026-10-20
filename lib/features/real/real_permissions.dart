import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../real/real_controller.dart';
import 'real_common.dart';

/// The phone permissions in one place: asked once at the start (first
/// steps), and again from Settings — never in the middle of a drive.
class PermissionsList extends ConsumerStatefulWidget {
  const PermissionsList({super.key, this.onChanged, this.showAuto = true});

  /// Settings has its own switch for this (in "Driving").
  final bool showAuto;

  /// After every change (e.g. to update an "allow all" button).
  final ValueChanged<PhonePermissions>? onChanged;

  @override
  ConsumerState<PermissionsList> createState() => PermissionsListState();
}

class PermissionsListState extends ConsumerState<PermissionsList> {
  PhonePermissions? _now;
  var _asking = false;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    // Some answers come back from the phone's own settings screens.
    _life = AppLifecycleListener(onResume: reload);
    reload();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    // The screen may be gone by now (e.g. "later" while the phone asked).
    if (!mounted) return;
    final p = await ref.read(realProvider.notifier).phonePermissions();
    if (!mounted) return;
    setState(() => _now = p);
    widget.onChanged?.call(p);
  }

  Future<void> _ask(Future<void> Function() body) async {
    if (_asking) return;
    setState(() => _asking = true);
    try {
      await body();
    } finally {
      if (mounted) {
        setState(() => _asking = false);
        await reload();
      }
    }
  }

  Future<void> askAll() =>
      _ask(ref.read(realProvider.notifier).askAllPermissions);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = ref.read(realProvider.notifier);
    final p = _now;
    if (p == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    Widget row(PhonePermission kind, IconData icon, String title, String body) {
      final ok = p.has(kind);
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.terracotta),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(body),
        trailing: ok
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.sage),
                  const SizedBox(width: 4),
                  Text(l.permsDone),
                ],
              )
            // Lighter than the main "allow all" button below.
            : OutlinedButton(
                onPressed: _asking
                    ? null
                    : () => _ask(() => c.askPermission(kind)),
                child: Text(l.permsAllowOne),
              ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p.supported)
          row(
            PhonePermission.notifications,
            Icons.notifications_rounded,
            l.permsNotifTitle,
            l.permsNotifBody,
          ),
        row(
          PhonePermission.calls,
          Icons.call_rounded,
          l.permsCallTitle,
          l.permsCallBody,
        ),
        row(
          PhonePermission.mic,
          Icons.mic_rounded,
          l.permsMicTitle,
          l.permsMicBody,
        ),
        if (p.supported)
          row(
            PhonePermission.fullScreen,
            Icons.fullscreen_rounded,
            l.permsFullTitle,
            l.permsFullBody,
          ),
        if (p.supported)
          row(
            PhonePermission.background,
            Icons.battery_charging_full_rounded,
            l.permsBgTitle,
            l.permsBgBody,
          ),
        // Opt-in, off by default (it is a choice, not a permission).
        if (p.supported && widget.showAuto)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(
              Icons.directions_car_rounded,
              color: AppColors.terracotta,
            ),
            title: Text(
              l.permsAutoTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(l.permsAutoBody),
            value: p.autoDriving,
            onChanged: _asking
                ? null
                : (on) => _ask(() async {
                    if (on) {
                      await c.enableAutoDriving();
                    } else {
                      await c.disableAutoDriving();
                    }
                  }),
          ),
      ],
    );
  }
}

/// First steps: all the permissions at once, before the first drive.
class PermissionsStep extends ConsumerStatefulWidget {
  const PermissionsStep({super.key});

  @override
  ConsumerState<PermissionsStep> createState() => _PermissionsStepState();
}

class _PermissionsStepState extends ConsumerState<PermissionsStep> {
  final _list = GlobalKey<PermissionsListState>();
  var _missing = true;

  void _changed(PhonePermissions p) {
    final missing = PhonePermission.values.any((k) => !p.has(k));
    if (missing != _missing) setState(() => _missing = missing);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = ref.read(realProvider.notifier);
    return MomentLayout(
      top: Column(
        children: [
          MomentText(l.permsTitle, size: 28),
          const SizedBox(height: 10),
          MomentText(l.permsBody, size: 16, soft: true),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: PermissionsList(key: _list, onChanged: _changed),
            ),
          ),
          // Room between the list and the buttons below.
          const SizedBox(height: 16),
        ],
      ),
      actions: [
        if (_missing)
          PrimaryPill(
            label: l.permsAllowAll,
            icon: Icons.check_rounded,
            onTap: () => _list.currentState?.askAll(),
          ),
        if (_missing)
          SecondaryPill(label: l.firstRunLater, onTap: c.firstRunNext)
        else
          PrimaryPill(label: l.next, onTap: c.firstRunNext),
      ],
    );
  }
}

/// Settings → "Permissions".
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  final list = GlobalKey<PermissionsListState>();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.permsSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.permsBody, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          PermissionsList(key: list, showAuto: false),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => list.currentState?.askAll(),
            icon: const Icon(Icons.check_rounded),
            label: Text(l.permsAllowAll, style: const TextStyle(fontSize: 17)),
          ),
          // Notification kinds (sounds, lock screen) live in the phone.
          if (ref.watch(realProvider).driving.supported)
            TextButton.icon(
              onPressed: ref
                  .read(realProvider.notifier)
                  .openNotificationSettings,
              icon: const Icon(Icons.notifications_rounded),
              label: Text(l.permsPhoneNotif),
            ),
        ],
      ),
    );
  }
}
