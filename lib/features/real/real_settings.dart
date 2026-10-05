import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import '../settings/routines_screen.dart';
import 'real_common.dart';
import 'real_home.dart';

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
              ListTile(
                leading: me == null
                    ? const Icon(Icons.person_rounded)
                    : PersonAvatar(person: me.toPerson(), size: 40),
                title: Text(l.realPhotoTitle),
                subtitle: Text(
                  me?.photo == null ? l.realPhotoNone : l.realPhotoSet,
                ),
                trailing: const Icon(Icons.photo_camera_rounded),
                onTap: me == null || s.busy
                    ? null
                    : () => _editPhoto(context, ref, me.photo != null),
              ),
              ListTile(
                leading: const Icon(Icons.badge_rounded),
                title: Text(l.realNameTitle),
                subtitle: Text(me?.name ?? '—'),
                trailing: const Icon(Icons.edit_rounded),
                onTap: me == null ? null : () => _editName(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.phone_rounded),
                title: Text(l.realMyNumber),
                subtitle: Text(
                  s.myPhone == null ? l.realNotShared : l.realShared,
                ),
                trailing: const Icon(Icons.edit_rounded),
                onTap: () => _editPhone(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.contacts_rounded),
                title: Text(l.realClearContacts),
                subtitle: Text(l.realClearContactsBody),
                onTap: s.busy
                    ? null
                    : () => ref.read(realProvider.notifier).clearContacts(),
              ),
              if (s.directCall != null)
                ListTile(
                  leading: const Icon(Icons.bolt_rounded),
                  title: Text(l.realDirectCallSetting),
                  subtitle: Text(
                    s.directCall! ? l.realDirectCallOn : l.realDirectCallOff,
                  ),
                  trailing: s.directCall!
                      ? const Icon(Icons.check_circle_rounded)
                      : TextButton(
                          onPressed: () =>
                              ref.read(realProvider.notifier).askDirectCall(),
                          child: Text(l.realDirectCallAllow),
                        ),
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
                subtitle: Text(l.routinesCount(s.routines.length)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoutinesScreen(real: true),
                  ),
                ),
              ),
              if (s.driving.supported)
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
            title: l.realSettingsMode,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.sageDark,
                ),
                title: Text(l.realModeReal),
                subtitle: Text(l.realPrivacyNote),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fact_check_rounded),
                title: Text(l.realTestModeToggle),
                subtitle: Text(l.realTestModeBody),
                value: s.prefs.testTab,
                onChanged: (v) => c.setPrefs(s.prefs.copyWith(testTab: v)),
              ),
              ListTile(
                leading: const Icon(Icons.theater_comedy_rounded),
                title: Text(l.realSwitchToDemo),
                subtitle: Text(l.realModeDemo),
                onTap: () =>
                    ref.read(appModeProvider.notifier).set(AppMode.demo),
              ),
              ListTile(
                leading: const Icon(Icons.system_update_rounded),
                title: Text(l.updateCheck),
                subtitle: Text(
                  s.newBuild != null
                      ? l.updateAvailable
                      : '${l.updateCurrent} ${ref.watch(appVersionProvider)}',
                ),
                onTap: () async {
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
                leading: const Icon(Icons.block_rounded),
                title: Text(l.realBlockedTitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => const _BlockedSheet(),
                ),
              ),
            ],
          ),
          SettingsGroup(
            children: [
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

  Future<void> _editPhoto(
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
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(l.photoFromGallery),
              onTap: () => Navigator.pop(sheet, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(l.photoFromCamera),
              onTap: () => Navigator.pop(sheet, 'camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(l.photoRemove),
                onTap: () => Navigator.pop(sheet, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return; // Dismissed.
    final messenger = ScaffoldMessenger.of(context);
    final c = ref.read(realProvider.notifier);
    Uint8List? bytes;
    if (choice != 'remove') {
      try {
        final file = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80,
        );
        if (file == null) return;
        bytes = await file.readAsBytes();
      } catch (_) {
        return; // Camera/gallery unavailable.
      }
    }
    final error = await c.setPhoto(bytes);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error != null
              ? realErrorText(l, error)
              : bytes == null
              ? l.realPhotoRemoved
              : l.realPhotoSaved,
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
      child: Padding(
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
