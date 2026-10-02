import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'real_controller.dart';
import 'real_models.dart';

/// Incoming links: `https://<invite site>/i/<token>` and
/// `drivetalk://invite/<token>`.
/// (Includes the link that launched the app.)
final incomingLinksProvider = Provider<Stream<Uri>>((ref) {
  try {
    return AppLinks().uriLinkStream.handleError((Object _) {});
  } catch (_) {
    return const Stream.empty();
  }
});

/// Opens invitation links in real mode (switching to it if needed).
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  StreamSubscription<Uri>? _sub;
  String? _lastToken;
  DateTime? _lastAt;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(incomingLinksProvider).listen(_onLink);
  }

  void _onLink(Uri uri) {
    final token = parseInviteToken(uri.toString());
    if (token == null) return;
    // The same link can arrive twice (launch + stream); open it once.
    final now = DateTime.now();
    if (token == _lastToken &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 10)) {
      return;
    }
    _lastToken = token;
    _lastAt = now;
    ref.read(appModeProvider.notifier).set(AppMode.real);
    ref.read(realProvider.notifier).openInvite(token);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
