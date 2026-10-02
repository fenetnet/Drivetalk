import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
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

/// A huge, high-contrast button (driver-friendly).
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
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: TextStyle(
            fontFamily: 'Rubik',
            fontSize: height >= 100 ? 30 : 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: height >= 100 ? 40 : 32),
        label: Text(label),
      ),
    );
  }
}

/// Full-screen layout for the moments that matter (offer, waiting, call):
/// one picture, one or two lines, up to three big buttons.
class MomentLayout extends ConsumerWidget {
  const MomentLayout({
    super.key,
    required this.top,
    required this.actions,
    this.dark = false,
    this.footer,
  });
  final Widget top;
  final List<Widget> actions;
  final bool dark;
  final String? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final listening = ref.watch(realProvider.select((s) => s.listening));
    return Scaffold(
      backgroundColor: dark ? AppColors.driverBg : AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        color: dark ? AppColors.sand : AppColors.terracotta,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l.driverListening,
                          style: TextStyle(
                            color: dark ? AppColors.sand : AppColors.terracotta,
                            fontSize: 18,
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
                  style: TextStyle(
                    color: dark ? Colors.white38 : AppColors.inkSoft,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MomentText extends StatelessWidget {
  const MomentText(
    this.text, {
    super.key,
    this.size = 26,
    this.dark = false,
    this.soft = false,
  });
  final String text;
  final double size;
  final bool dark;
  final bool soft;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: dark
          ? (soft ? Colors.white70 : Colors.white)
          : (soft ? AppColors.inkSoft : AppColors.ink),
      fontSize: size,
      fontWeight: soft ? FontWeight.w400 : FontWeight.w600,
      height: 1.25,
    ),
  );
}
