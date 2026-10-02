import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'matching/matching_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final raw = await rootBundle.loadString('assets/config/matching.json');
  final config = MatchingConfig.fromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );
  runApp(
    ProviderScope(
      overrides: [matchingConfigProvider.overrideWithValue(config)],
      child: const DriveTalkApp(),
    ),
  );
}
