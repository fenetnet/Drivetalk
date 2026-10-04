import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';

/// "Now" for real-mode screens, refreshed every second.
final realNowProvider = NotifierProvider<RealNow, DateTime>(RealNow.new);

class RealNow extends Notifier<DateTime> {
  @override
  DateTime build() {
    final clock = ref.watch(realClockProvider);
    final t = Timer.periodic(
      const Duration(seconds: 1),
      (_) => state = clock(),
    );
    ref.onDispose(t.cancel);
    return clock();
  }
}

/// Simple words for an error code. Never shows technical details.
String realErrorText(AppLocalizations l, String code) => switch (code) {
  'offline' => l.realErrorOffline,
  'anonymous_disabled' => l.realErrorAnonymousDisabled,
  'bad_key' => l.realErrorGeneric('bad_key — המפתח הציבורי לא תקין'),
  'schema_missing' => l.realErrorSchema,
  'invalid_phone' => l.realErrorInvalidPhone,
  'invalid_name' => l.realErrorInvalidName,
  'rate_limited' => l.realErrorRateLimited,
  'too_many_open_invitations' => l.realErrorTooManyInvites,
  _ => l.realErrorGeneric(code),
};

String inviteProblemText(AppLocalizations l, String? code) => switch (code) {
  'used' => l.realInviteProblemUsed,
  'expired' => l.realInviteProblemExpired,
  'own' => l.realInviteProblemOwn,
  _ => l.realInviteProblemNotFound,
};

String offerStatusText(AppLocalizations l, OfferStatus s) => switch (s) {
  OfferStatus.pending => l.realOfferPending,
  OfferStatus.accepted => l.realOfferAccepted,
  OfferStatus.declined => l.realOfferDeclined,
  OfferStatus.expired => l.realOfferExpired,
  OfferStatus.cancelled => l.realOfferCancelled,
};

/// Color moods of the full-screen moments (see the approved design).
enum MomentStyle { light, coral, green, dark }

extension MomentColors on MomentStyle {
  Color get background => switch (this) {
    MomentStyle.light => AppColors.cream,
    MomentStyle.coral => AppColors.terracotta,
    MomentStyle.green => AppColors.sageDark,
    MomentStyle.dark => AppColors.driverBg,
  };

  /// Two soft rings behind the picture.
  (Color, Color) get rings => switch (this) {
    MomentStyle.light => (AppColors.blush, AppColors.blushDeep),
    MomentStyle.coral => (const Color(0xFFE06B4F), const Color(0xFFE77F63)),
    MomentStyle.green => (const Color(0xFF367A63), const Color(0xFF3F8A70)),
    MomentStyle.dark => (const Color(0xFF1B1F2D), const Color(0xFF1F2434)),
  };

  Color get text => this == MomentStyle.light ? AppColors.ink : Colors.white;
  Color get softText => switch (this) {
    MomentStyle.light => AppColors.inkSoft,
    MomentStyle.dark => const Color(0xFFC9CCDA),
    _ => Colors.white.withValues(alpha: 0.9),
  };
  bool get onColor => this != MomentStyle.light;
}

/// Round avatar with a white rim; [online] adds the green "free" ring + dot.
class RealAvatar extends StatelessWidget {
  const RealAvatar({
    super.key,
    required this.person,
    this.size = 64,
    this.online = false,
    this.rim = Colors.white,
  });
  final Person person;
  final double size;
  final bool online;
  final Color rim;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.25;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(person.avatarColor),
              border: Border.all(color: rim, width: size * 0.05),
              boxShadow: [
                if (online)
                  BoxShadow(color: AppColors.sage, spreadRadius: size * 0.035),
              ],
              image: person.photo == null
                  ? null
                  : DecorationImage(
                      image: MemoryImage(person.photo!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: person.photo != null
                ? null
                : Text(
                    person.initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          if (online)
            PositionedDirectional(
              bottom: size * 0.02,
              end: size * 0.02,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: dot * 0.18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The big avatar of a moment, inside a white ring with a soft shadow.
class HeroAvatar extends StatelessWidget {
  const HeroAvatar({
    super.key,
    required this.person,
    this.size = 168,
    this.ring = Colors.white,
  });
  final Person person;
  final double size;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ring,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x47501408),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: RealAvatar(
        person: person,
        size: size - 16,
        rim: Colors.transparent,
      ),
    );
  }
}

/// Main action of a moment: a big pill. On a colored background it is white
/// with the background's color as text; on cream it is coral.
class PrimaryPill extends StatelessWidget {
  const PrimaryPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.style = MomentStyle.light,
    this.height = 76,
    this.color,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final MomentStyle style;
  final double height;

  /// Override (e.g. the driver's green "yes").
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg =
        color ??
        switch (style) {
          MomentStyle.light => AppColors.terracotta,
          MomentStyle.dark => AppColors.sage,
          _ => Colors.white,
        };
    final fg = color != null
        ? Colors.white
        : switch (style) {
            MomentStyle.coral => AppColors.coralDeep,
            MomentStyle.green => AppColors.sageDark,
            _ => Colors.white,
          };
    final big = height >= 100;
    return SizedBox(
      height: height,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: style.onColor ? 6 : 2,
          shadowColor: const Color(0x55501408),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2.2),
          ),
          textStyle: TextStyle(
            fontFamily: 'Rubik',
            fontSize: big ? 32 : 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: big ? 40 : 28),
              const SizedBox(width: 12),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// Secondary action: an outlined pill (on color) or a dark slab (driving).
class SecondaryPill extends StatelessWidget {
  const SecondaryPill({
    super.key,
    required this.label,
    required this.onTap,
    this.style = MomentStyle.light,
    this.height = 60,
  });
  final String label;
  final VoidCallback? onTap;
  final MomentStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = TextStyle(
      fontFamily: 'Rubik',
      fontSize: height >= 80 ? 26 : 19,
      fontWeight: FontWeight.w700,
    );
    if (style == MomentStyle.dark) {
      return SizedBox(
        height: height,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.driverCard,
            foregroundColor: Colors.white,
            textStyle: text,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          onPressed: onTap,
          child: Text(label),
        ),
      );
    }
    final fg = style.onColor ? Colors.white : AppColors.ink;
    return SizedBox(
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          textStyle: text,
          side: BorderSide(
            color: style.onColor
                ? Colors.white.withValues(alpha: 0.7)
                : const Color(0xFFE6D6CB),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}

/// Kept for screens that still use it (big icon button).
class BigActionButton extends StatelessWidget {
  const BigActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppColors.sageDark,
    this.dark = false,
    this.height = 84,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final bool dark;
  final double height;

  @override
  Widget build(BuildContext context) => PrimaryPill(
    label: label,
    icon: icon,
    onTap: onTap,
    color: color,
    height: height,
  );
}

/// A small rounded label on a colored moment ("Yoni · driving · 25 min").
class MomentChip extends StatelessWidget {
  const MomentChip({
    super.key,
    required this.text,
    this.style = MomentStyle.light,
    this.icon,
    this.dot,
  });
  final String text;
  final MomentStyle style;
  final IconData? icon;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final fg = switch (style) {
      MomentStyle.dark => const Color(0xFF9CD9BE),
      MomentStyle.light => AppColors.sageDark,
      _ => Colors.white,
    };
    final bg = switch (style) {
      MomentStyle.dark => AppColors.sage.withValues(alpha: 0.16),
      MomentStyle.light => AppColors.mint,
      _ => Colors.white.withValues(alpha: 0.18),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen layout for the moments that matter (offer, waiting, call):
/// a colored ground with soft rings, one picture, a line or two, and up to
/// three big buttons at the bottom.
class MomentLayout extends ConsumerWidget {
  const MomentLayout({
    super.key,
    required this.top,
    required this.actions,
    this.style = MomentStyle.light,
    this.footer,
    this.header,
  });
  final Widget top;
  final List<Widget> actions;
  final MomentStyle style;
  final String? footer;

  /// Optional chip at the very top.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final st = style;
    final listening = ref.watch(realProvider.select((s) => s.listening));
    final (r1, r2) = st.rings;
    return Scaffold(
      backgroundColor: st.background,
      body: Stack(
        children: [
          // Soft decorative rings, centered behind the picture.
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: const Alignment(0, -0.38),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 430,
                      height: 430,
                      decoration: BoxDecoration(
                        color: r1,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        color: r2,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (header != null) Center(child: header),
                  Expanded(
                    child: Center(child: SingleChildScrollView(child: top)),
                  ),
                  if (listening)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            color: st.onColor
                                ? AppColors.sand
                                : AppColors.terracotta,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              l.driverListening,
                              style: TextStyle(
                                color: st.onColor
                                    ? AppColors.sand
                                    : AppColors.terracotta,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final a in actions) ...[a, const SizedBox(height: 14)],
                  if (footer != null)
                    Text(
                      footer!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: st.softText, fontSize: 13),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MomentText extends StatelessWidget {
  const MomentText(
    this.text, {
    super.key,
    this.size = 26,
    this.style = MomentStyle.light,
    this.soft = false,
  });
  final String text;
  final double size;
  final MomentStyle style;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final st = style;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: soft ? st.softText : st.text,
        fontSize: size,
        fontWeight: soft ? FontWeight.w500 : FontWeight.w800,
        height: 1.15,
      ),
    );
  }
}

/// A white rounded card of settings rows with a small title above.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
              child: Text(
                title!,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Color(0xFFF1E6DD),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
