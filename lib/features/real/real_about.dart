import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../real/real_controller.dart';
import 'real_common.dart';

/// "About DriveBond" (from Settings): what's special, every phone permission
/// with what was allowed and why it's needed, and what we never do.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  PhonePermissions? _perms;
  bool? _contacts;
  var _asking = false;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    // Answers given in the phone's own settings come back on resume.
    _life = AppLifecycleListener(onResume: _reload);
    _reload();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final p = await ref.read(realProvider.notifier).phonePermissions();
    final contacts = await ref.read(contactsReaderProvider).hasPermission();
    if (!mounted) return;
    setState(() {
      _perms = p;
      _contacts = contacts;
    });
  }

  Future<void> _ask(Future<void> Function() body) async {
    if (_asking) return;
    setState(() => _asking = true);
    try {
      await body();
    } finally {
      if (mounted) {
        setState(() => _asking = false);
        await _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = ref.read(realProvider.notifier);
    final driving = ref.watch(realProvider).driving;
    final p = _perms;

    Widget special(String emoji, String title, String body) => _Line(
      leading: Text(emoji, style: const TextStyle(fontSize: 26)),
      title: title,
      body: body,
    );

    Widget perm(
      IconData icon,
      String title,
      String body,
      _State state, {
      Future<void> Function()? ask,
    }) => _Line(
      leading: Icon(icon, color: AppColors.terracotta, size: 28),
      title: title,
      body: body,
      badge: _Badge(state),
      action: state == _State.off && ask != null
          ? OutlinedButton(
              onPressed: _asking ? null : () => _ask(ask),
              child: Text(l.permsAllowOne),
            )
          : null,
    );

    _State on(bool ok) => ok ? _State.on : _State.off;

    return Scaffold(
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Text(
              l.aboutHero,
              style: const TextStyle(
                fontSize: 18,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.coralDeep,
              ),
            ),
          ),
          SettingsGroup(
            title: l.aboutSpecialTitle,
            children: [
              special('🚗', l.aboutSpecial1Title, l.aboutSpecial1Body),
              special('🤝', l.aboutSpecial2Title, l.aboutSpecial2Body),
              special('🗣️', l.aboutSpecial3Title, l.aboutSpecial3Body),
              special('🎛️', l.aboutSpecial4Title, l.aboutSpecial4Body),
              special('🚫', l.aboutSpecial5Title, l.aboutSpecial5Body),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              l.aboutPermsIntro,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ),
          if (p == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SettingsGroup(
              title: l.aboutPermsTitle,
              children: [
                if (p.supported)
                  perm(
                    Icons.notifications_rounded,
                    l.permsNotifTitle,
                    l.aboutPermNotifBody,
                    on(p.has(PhonePermission.notifications)),
                    ask: () => c.askPermission(PhonePermission.notifications),
                  ),
                perm(
                  Icons.call_rounded,
                  l.permsCallTitle,
                  l.aboutPermCallBody,
                  on(p.has(PhonePermission.calls)),
                  ask: () => c.askPermission(PhonePermission.calls),
                ),
                perm(
                  Icons.mic_rounded,
                  l.permsMicTitle,
                  l.aboutPermMicBody,
                  on(p.has(PhonePermission.mic)),
                  ask: () => c.askPermission(PhonePermission.mic),
                ),
                if (p.supported)
                  perm(
                    Icons.battery_charging_full_rounded,
                    l.permsBgTitle,
                    l.aboutPermBgBody,
                    on(p.has(PhonePermission.background)),
                    ask: () => c.askPermission(PhonePermission.background),
                  ),
                perm(
                  Icons.contacts_rounded,
                  l.aboutPermContactsTitle,
                  l.aboutPermContactsBody,
                  _contacts == true ? _State.on : _State.optional,
                ),
                if (p.supported) ...[
                  perm(
                    Icons.directions_car_rounded,
                    l.aboutPermActivityTitle,
                    l.aboutPermActivityBody,
                    p.autoDriving ? _State.inUse : _State.optional,
                  ),
                  perm(
                    Icons.bluetooth_rounded,
                    l.aboutPermBtTitle,
                    l.aboutPermBtBody,
                    driving.carName.isEmpty ? _State.optional : _State.inUse,
                  ),
                ],
              ],
            ),
          SettingsGroup(
            title: l.aboutPrivacyTitle,
            children: [
              for (final t in [
                l.aboutNever1,
                l.aboutNever2,
                l.aboutNever3,
                l.aboutNever4,
                l.aboutNever5,
              ])
                ListTile(
                  leading: const Icon(
                    Icons.shield_rounded,
                    color: AppColors.sage,
                  ),
                  title: Text(t),
                ),
            ],
          ),
          SettingsGroup(
            title: l.aboutFeedbackTitle,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.aboutFeedbackBody),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => openFeedbackDialog(context, ref),
                      icon: const Icon(Icons.rate_review_rounded),
                      label: Text(l.feedbackTitle),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Center(
            child: Text(
              'DriveBond ${ref.watch(appVersionProvider)}',
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

enum _State { on, off, optional, inUse }

class _Badge extends StatelessWidget {
  const _Badge(this.state);
  final _State state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (text, color, icon) = switch (state) {
      _State.on => (l.aboutPermOn, AppColors.sage, Icons.check_circle_rounded),
      _State.inUse => (
        l.aboutPermInUse,
        AppColors.sage,
        Icons.check_circle_rounded,
      ),
      _State.off => (l.aboutPermOff, AppColors.danger, Icons.error_rounded),
      _State.optional => (
        l.aboutPermOptional,
        AppColors.inkSoft,
        Icons.radio_button_unchecked_rounded,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// One row: icon, a bold title (with a status on the side), the long
/// explanation under it, and maybe a button.
class _Line extends StatelessWidget {
  const _Line({
    required this.leading,
    required this.title,
    required this.body,
    this.badge,
    this.action,
  });

  final Widget leading;
  final String title;
  final String body;
  final Widget? badge;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 36, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    ?badge,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    height: 1.35,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: action,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
