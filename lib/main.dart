import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/conversation_starters.dart';
import 'app/providers.dart';
import 'domain/models.dart';
import 'matching/matching_config.dart';
import 'services/fake/fake_world.dart';

const _meKey = 'me.v1';
const _prefsKey = 'prefs.v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = MatchingConfig.fromJson(
    jsonDecode(await rootBundle.loadString('assets/config/matching.json'))
        as Map<String, dynamic>,
  );
  final starters = ConversationStarters.fromJson(
    jsonDecode(await rootBundle.loadString('assets/content/starters_he.json'))
        as Map<String, dynamic>,
  );

  // Phase 1 keeps only MY profile & settings on this phone between launches.
  // Everyone else is fake data that is regenerated on every launch.
  SharedPreferences? store;
  try {
    store = await SharedPreferences.getInstance();
  } catch (_) {
    store = null; // e.g. blocked storage in a browser preview
  }
  final world = FakeWorld(
    onProfileChanged: (me, prefs) {
      store?.setString(_meKey, jsonEncode(me.toJson()));
      store?.setString(_prefsKey, jsonEncode(prefs.toJson()));
    },
  );
  try {
    final me = store?.getString(_meKey);
    final prefs = store?.getString(_prefsKey);
    if (me != null) {
      world.me = Person.fromJson(
        (jsonDecode(me) as Map).cast<String, Object?>(),
        world.me,
      );
    }
    if (prefs != null) {
      world.prefs = MyPreferences.fromJson(
        (jsonDecode(prefs) as Map).cast<String, Object?>(),
        world.prefs,
      );
    }
  } catch (_) {
    // Corrupt or old data: start fresh.
  }

  runApp(
    ProviderScope(
      overrides: [
        matchingConfigProvider.overrideWithValue(config),
        startersProvider.overrideWithValue(starters),
        fakeWorldProvider.overrideWithValue(world),
      ],
      child: const DriveTalkApp(),
    ),
  );
}
