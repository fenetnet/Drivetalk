import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// My photo, my phone number (for regular calls) and who may receive it.
class ProfileSection extends ConsumerStatefulWidget {
  const ProfileSection({super.key});

  @override
  ConsumerState<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<ProfileSection> {
  late final _phone = TextEditingController(
    text: ref.read(profileServiceProvider).me.phoneNumber ?? '',
  );

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final profile = ref.read(profileServiceProvider);
      await profile.updateMe(profile.me.copyWith(photo: bytes));
    } catch (_) {
      // Camera/gallery unavailable (e.g. browser preview) — nothing to do.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final profile = ref.watch(profileServiceProvider);
    final me = profile.me;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l.settingsProfile),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              PersonAvatar(person: me, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: Text(l.photoFromGallery),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: Text(l.photoFromCamera),
                    ),
                    if (me.photo != null)
                      TextButton(
                        onPressed: () =>
                            profile.updateMe(me.copyWith(clearPhoto: true)),
                        child: Text(l.photoRemove),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
            l.photoPrivacyNote,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l.myPhoneNumber,
              helperText: l.myPhoneNumberHelp,
              helperMaxLines: 3,
              prefixIcon: const Icon(Icons.phone_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) =>
                profile.updateMe(profile.me.copyWith(phoneNumber: v.trim())),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.share_rounded),
          title: Text(l.shareNumberWithFof),
          subtitle: Text(l.shareNumberWithFofBody),
          value: me.sharesNumberWithFriendsOfFriends,
          onChanged: (v) => profile.updateMe(
            me.copyWith(sharesNumberWithFriendsOfFriends: v),
          ),
        ),
      ],
    );
  }
}
