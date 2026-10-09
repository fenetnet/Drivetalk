import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../real/backend_config.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import '../settings/routines_screen.dart';
import 'real_common.dart';
import 'real_home.dart';
import 'real_stats.dart';

class RealSettingsScreen extends ConsumerWidget {
  const RealSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final me = s.snapshot?.me;
    final apk = ref.watch(apkUrlProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.tabSettings,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SettingsGroup(
            title: l.realGroupAccount,
            children: [
              // One row: my picture, name and number. Tap to change.
              ListTile(
                leading: me == null
                    ? const Icon(Icons.person_rounded)
                    : PersonAvatar(person: me.toPerson(), size: 44),
                title: Text(
                  me?.name ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  s.myPhone ?? l.realNotShared,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.end,
                ),
                trailing: const Icon(Icons.edit_rounded),
                onTap: me == null || s.busy
                    ? null
                    : () => _editProfile(context, ref, me.photo != null),
              ),
            ],
          ),
          SettingsGroup(
            title: l.settingsDriving,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.directions_car_rounded),
                title: Text(l.realAutoDriving),
                subtitle: Text(
                  s.driving.supported
                      ? l.realAutoDrivingBody
                      : l.realAutoDrivingUnsupported,
                ),
                value: s.driving.enabled,
                onChanged: !s.driving.supported || s.busy
                    ? null
                    : (v) => setAutoDriving(context, ref, v),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: Text(l.routinesTitle),
                subtitle: Text(
                  '${l.routinesExplain}\n${l.routinesCount(s.routines.length)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoutinesScreen(),
                  ),
                ),
              ),
              if (s.driving.supported && s.driving.enabled)
                ListTile(
                  leading: const Icon(Icons.bluetooth_rounded),
                  title: Text(l.realCarTitle),
                  subtitle: Text(
                    s.driving.carName.isEmpty
                        ? l.realCarBody
                        : s.driving.carName,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickCar(context, ref),
                ),
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over_rounded),
                title: Text(l.settingsVoiceReadout),
                subtitle: Text(l.settingsVoiceReadoutBody),
                value: s.prefs.voice,
                onChanged: (v) => c.setPrefs(s.prefs.copyWith(voice: v)),
              ),
              if (s.prefs.voice)
                SwitchListTile(
                  secondary: const Icon(Icons.badge_outlined),
                  title: Text(l.settingsSpeakNames),
                  subtitle: Text(l.settingsSpeakNamesBody),
                  value: s.prefs.speakNames,
                  onChanged: (v) => c.setPrefs(s.prefs.copyWith(speakNames: v)),
                ),
            ],
          ),
          SettingsGroup(
            title: l.settingsGeneral,
            children: [
              if (s.driving.supported)
                ListTile(
                  leading: const Icon(Icons.notifications_rounded),
                  title: Text(l.notificationsTitle),
                  subtitle: Text(
                    s.driving.notifications
                        ? l.notificationsOnBody
                        : l.notificationsOffBody,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: c.openNotificationSettings,
                ),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_rounded),
                title: Text(l.hideStatusTitle),
                subtitle: Text(l.hideStatusBody),
                value: s.snapshot?.hidden ?? false,
                onChanged: s.busy || s.snapshot == null
                    ? null
                    : c.setHideStatus,
              ),
              ListTile(
                leading: const Icon(Icons.system_update_rounded),
                title: Text(l.updateCheck),
                subtitle: Text(
                  s.newBuild != null
                      ? l.updateAvailable
                      : '${l.updateCurrent} ${ref.watch(appVersionProvider)}',
                ),
                // The owner's tools are hidden: a long press here asks for
                // the owner's code (users and store reviewers never see it).
                onLongPress: s.admin ? null : () => _askAdminCode(context, ref),
                onTap: () async {
                  // Google Play build: the store page has the update.
                  if (BackendConfig.store) return openAppUpdate();
                  final c = ref.read(realProvider.notifier);
                  await c.checkForUpdate(force: true);
                  if (ref.read(realProvider).newBuild != null) {
                    await openAppUpdate();
                  } else {
                    messengerKey.currentState?.showSnackBar(
                      SnackBar(content: Text(l.updateNone)),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.rate_review_rounded),
                title: Text(l.feedbackTitle),
                subtitle: Text(l.feedbackBody),
                onTap: () => _sendFeedback(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text(l.realBlockedTitle),
                subtitle: Text(l.realBlockedBody),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const _BlockedSheet(),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.sageDark,
                ),
                title: Text(l.settingsPrivacy),
                subtitle: Text(l.settingsPrivacyBody),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _privacySheet(context, ref),
              ),
            ],
          ),
          if (s.admin)
            SettingsGroup(
              title: l.adminTitle,
              children: [
                ListTile(
                  leading: const Icon(Icons.bar_chart_rounded),
                  title: Text(l.statsTitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RealStatsScreen(),
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.fact_check_rounded),
                  title: Text(l.realTestModeToggle),
                  subtitle: Text(l.realTestModeBody),
                  value: s.prefs.testTab,
                  onChanged: (v) => c.setPrefs(s.prefs.copyWith(testTab: v)),
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: Text(l.realDownloadLink),
                  subtitle: Text(
                    apk,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                  ),
                  trailing: IconButton(
                    tooltip: l.realShareApp,
                    icon: const Icon(Icons.share_rounded),
                    onPressed: () async {
                      if (!kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.android) {
                        await SharePlus.instance.share(ShareParams(text: apk));
                      } else {
                        await Clipboard.setData(ClipboardData(text: apk));
                        messengerKey.currentState?.showSnackBar(
                          SnackBar(content: Text(l.realCopied)),
                        );
                      }
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.restart_alt_rounded,
                    color: AppColors.danger,
                  ),
                  title: Text(l.realStartOver),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        content: Text(l.realStartOverConfirm),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(d, false),
                            child: Text(l.cancel),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.danger,
                            ),
                            onPressed: () => Navigator.pop(d, true),
                            child: Text(l.confirm),
                          ),
                        ],
                      ),
                    );
                    if (ok ?? false) await c.signOut();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_rounded),
                  title: Text(l.adminLock),
                  onTap: c.lockAdmin,
                ),
              ],
            ),
          SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.danger,
                ),
                title: Text(
                  l.realDeleteAccount,
                  style: const TextStyle(color: AppColors.danger),
                ),
                onTap: s.busy ? null : () => _deleteAccount(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The owner's tools, behind the owner's code.
  Future<void> _askAdminCode(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final code = TextEditingController();
    var wrong = false;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) {
          Future<void> submit() async {
            final ok = await ref
                .read(realProvider.notifier)
                .unlockAdmin(code.text);
            if (!d.mounted) return;
            if (ok) {
              Navigator.pop(d);
            } else {
              setState(() => wrong = true);
            }
          }

          return AlertDialog(
            title: Text(l.adminTitle),
            content: TextField(
              controller: code,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                labelText: l.adminCode,
                errorText: wrong ? l.adminWrong : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d),
                child: Text(l.cancel),
              ),
              FilledButton(onPressed: submit, child: Text(l.confirm)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickCar(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    final devices = await c.carCandidates();
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<(String, String)>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(l.realCarPick, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (devices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(l.realCarNoDevices),
              ),
            for (final (name, address) in devices)
              ListTile(
                leading: const Icon(Icons.directions_car_rounded),
                title: Text(name),
                onTap: () => Navigator.pop(sheet, (address, name)),
              ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: Text(l.realCarRemove),
              onTap: () => Navigator.pop(sheet, ('', '')),
            ),
          ],
        ),
      ),
    );
    if (picked != null) await c.setCar(picked.$1, picked.$2);
  }

  /// Name / picture / number, from the one profile row.
  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    bool hasPhoto,
  ) async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.badge_rounded),
              title: Text(l.realNameTitle),
              onTap: () => Navigator.pop(sheet, 'name'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(l.realPhotoTitle),
              onTap: () => Navigator.pop(sheet, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.phone_rounded),
              title: Text(l.realMyNumber),
              onTap: () => Navigator.pop(sheet, 'phone'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'name':
        await _editName(context, ref);
      case 'photo':
        await editMyPhoto(context, ref, hasPhoto: hasPhoto);
      case 'phone':
        await _editPhone(context, ref);
    }
  }

  /// What the server knows (short), and "delete what was synced".
  Future<void> _privacySheet(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.realPrivacyNote, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.contacts_rounded),
                label: Text(l.realClearContacts),
                onPressed: () {
                  Navigator.pop(sheet);
                  ref.read(realProvider.notifier).clearContacts();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.realDeleteAccount),
        content: Text(l.realDeleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(d, true),
            child: Text(l.realDeleteAccountGo),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(realProvider.notifier).deleteAccount();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error == null ? l.realDeleteAccountDone : realErrorText(l, error),
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final me = ref.read(realProvider).snapshot!.me;
    final name = TextEditingController(text: me.name);
    final gender = me.gender;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: Text(l.realNameTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 40,
                decoration: InputDecoration(labelText: l.onbNameLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if ((ok ?? false) && name.text.trim().isNotEmpty) {
      await ref.read(realProvider.notifier).updateProfile(name.text, gender);
    }
  }

  Future<void> _editPhone(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final phone = TextEditingController(
      text: ref.read(realProvider).myPhone ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.realMyNumber),
        content: TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l.realPhoneLabel,
            helperText: l.realPhoneHelp,
            helperMaxLines: 5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(realProvider.notifier).setMyPhone(phone.text);
    }
  }
}

class _BlockedSheet extends ConsumerStatefulWidget {
  const _BlockedSheet();

  @override
  ConsumerState<_BlockedSheet> createState() => _BlockedSheetState();
}

class _BlockedSheetState extends ConsumerState<_BlockedSheet> {
  List<RealProfile>? _people;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ref.read(realProvider.notifier).blockedPeople();
    if (mounted) setState(() => _people = list);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final people = _people;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.realBlockedTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (people == null)
              const Center(child: CircularProgressIndicator())
            else if (people.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(l.realBlockedEmpty),
              )
            else
              for (final p in people)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: PersonAvatar(person: p.toPerson(), size: 40),
                  title: Text(p.name),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref.read(realProvider.notifier).unblock(p);
                      await _load();
                    },
                    child: Text(l.realUnblock),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// "Send feedback": a short note to the owner (no names or numbers added).
Future<void> _sendFeedback(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final text = TextEditingController();
  final send = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(l.feedbackTitle),
      content: TextField(
        controller: text,
        autofocus: true,
        maxLength: 1000,
        minLines: 3,
        maxLines: 6,
        decoration: InputDecoration(hintText: l.feedbackHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: Text(l.feedbackSend),
        ),
      ],
    ),
  );
  if (send ?? false) {
    await ref.read(realProvider.notifier).sendFeedback(text.text);
  }
  text.dispose();
}
