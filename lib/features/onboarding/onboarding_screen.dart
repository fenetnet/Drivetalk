import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../common/labels.dart';

/// Short onboarding: what it is, how it works, privacy & safety, a few details.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  final _name = TextEditingController();
  var _page = 0;
  // Hebrew forms of address use the common default (owner decision D-044).
  final _gender = Gender.male;
  var _tiers = {MatchTier.familiar, MatchTier.reconnect, MatchTier.widenCircle};
  var _fof = false;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final profile = ref.read(profileServiceProvider);
    await profile.updateMe(
      profile.me.copyWith(
        name: _name.text.trim(),
        gender: _gender,
        openTiers: _tiers,
        openToFriendsOfFriends: _fof,
      ),
    );
    await profile.updatePrefs(profile.prefs.copyWith(onboardingDone: true));
  }

  void _next() => _pages.nextPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pages = [
      _InfoPage(
        icon: Icons.record_voice_over_rounded,
        title: l.onbWelcomeTitle,
        lines: [l.onbWelcomeBody],
        footer: l.onbPrototypeNote,
      ),
      _InfoPage(
        icon: Icons.handshake_rounded,
        title: l.onbHowTitle,
        lines: [l.onbHow1, l.onbHow2, l.onbHow3],
      ),
      _InfoPage(
        icon: Icons.shield_rounded,
        title: l.onbPrivacyTitle,
        lines: [l.onbPrivacy1, l.onbPrivacy2, l.onbPrivacy3],
      ),
      _setupPage(context),
    ];
    final last = _page == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  for (var i = 0; i < pages.length; i++)
                    Container(
                      margin: const EdgeInsetsDirectional.only(end: 6),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppColors.terracotta
                            : AppColors.terracotta.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: last ? _finish : _next,
                    child: Text(last ? l.onbStart : l.onbNext),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setupPage(BuildContext context) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l.onbSetupTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: l.onbNameLabel,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(l.onbOpennessLabel),
        for (final t in MatchTier.values)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tierLabel(l, t)),
            subtitle: Text(tierDescription(l, t)),
            value: _tiers.contains(t),
            onChanged: (v) => setState(() {
              _tiers = {..._tiers};
              v ? _tiers.add(t) : _tiers.remove(t);
            }),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.discoverFofTitle),
          subtitle: Text(l.discoverFofBody),
          value: _fof,
          onChanged: (v) => setState(() => _fof = v),
        ),
      ],
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.icon,
    required this.title,
    required this.lines,
    this.footer,
  });
  final IconData icon;
  final String title;
  final List<String> lines;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFFF8DDD3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: AppColors.terracotta),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                line,
                style: const TextStyle(fontSize: 18, height: 1.4),
              ),
            ),
          if (footer != null) ...[
            const SizedBox(height: 24),
            Text(footer!, style: const TextStyle(color: AppColors.inkSoft)),
          ],
        ],
      ),
    );
  }
}
