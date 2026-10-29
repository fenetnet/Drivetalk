import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../common/labels.dart';
import 'real_common.dart';

/// "What is DriveBond" in three photos (owner's pictures and words): before
/// joining, and again from About. Swipe or tap to go on.
class IntroTour extends StatefulWidget {
  const IntroTour({super.key, required this.onDone, this.doneLabel});

  /// Skip, or "let's start" on the last page.
  final VoidCallback onDone;

  /// The last button (About: "got it"; before joining: "let's start").
  final String? doneLabel;

  @override
  State<IntroTour> createState() => _IntroTourState();
}

class _IntroTourState extends State<IntroTour> {
  var _intro = 0;
  static const _pages = 3;

  void _next() {
    if (_intro == _pages - 1) {
      widget.onDone();
    } else {
      setState(() => _intro++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Each photo keeps its point in view (the offer on the phone is low).
    final (photo, focus, title, body) = switch (_intro) {
      0 => (
        'assets/intro/1-traffic.jpg',
        Alignment.center,
        l.intro1Title,
        l.intro1Body,
      ),
      1 => (
        'assets/intro/2-friend.jpg',
        const Alignment(0, 0.75),
        l.intro2Title,
        l.intro2Body,
      ),
      _ => (
        'assets/intro/3-talk.jpg',
        Alignment.center,
        l.intro3Title,
        l.intro3Body,
      ),
    };
    final last = _intro == _pages - 1;
    return Scaffold(
      body: GestureDetector(
        // RTL: a swipe to the right goes on, to the left goes back.
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v > 200) _next();
          if (v < -200 && _intro > 0) setState(() => _intro--);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The photo fills the top, behind the status bar.
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Image.asset(
                        photo,
                        key: ValueKey(photo),
                        fit: BoxFit.cover,
                        alignment: focus,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    // The heart of it: the app noticed you're both free.
                    if (_intro == 1)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x40000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.terracotta,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    l.intro2Badge,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.terracotta,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!last)
                      PositionedDirectional(
                        top: MediaQuery.paddingOf(context).top + 8,
                        start: 12,
                        child: TextButton(
                          onPressed: () => widget.onDone(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.black38,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(l.skip),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _intro ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _intro
                          ? AppColors.terracotta
                          : AppColors.terracotta.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            // The words always fit in full; the photo takes what's left
            // (small phones, large text: the words scroll at most).
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            MomentText(title, size: 28),
                            const SizedBox(height: 10),
                            MomentText(body, size: 16, soft: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    PrimaryPill(
                      label: last ? widget.doneLabel ?? l.introStart : l.next,
                      onTap: _next,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
