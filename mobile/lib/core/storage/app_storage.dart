import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppStorage {
  AppStorage._();

  static bool hasSeenOnboarding = false;
  static String preferredUnit = 'kg';
  static String themeMode = 'light';
  static String? _baseDirectory;

  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _baseDirectory = dir.path;
    await _loadPrefs();
  }

  static Future<void> _loadPrefs() async {
    try {
      final file = File(_settingsPath);
      if (!await file.exists()) return;
      final lines = await file.readAsLines();
      for (final line in lines) {
        final idx = line.indexOf('=');
        if (idx <= 0) continue;
        final key = line.substring(0, idx).trim();
        final value = line.substring(idx + 1).trim();
        switch (key) {
          case 'hasSeenOnboarding':
            hasSeenOnboarding = value == 'true';
          case 'preferredUnit':
            preferredUnit = value;
          case 'themeMode':
            themeMode = value;
        }
      }
    } catch (_) {}
  }

  static Future<void> setOnboardingSeen() async {
    hasSeenOnboarding = true;
    await _writePrefs({'hasSeenOnboarding': 'true'});
  }

  static Future<void> setPreferredUnit(String unit) async {
    preferredUnit = unit;
    await _writePrefs({'preferredUnit': unit});
  }

  static Future<void> setThemeMode(String mode) async {
    themeMode = mode;
    await _writePrefs({'themeMode': mode});
  }

  static Future<void> _writePrefs(Map<String, String> kv) async {
    try {
      final file = File(_settingsPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        kv.entries.map((e) => '${e.key}=${e.value}').join('\n'),
        flush: true,
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  static String get _settingsPath =>
      p.join(_baseDirectory ?? '.', 'settings.json');

  static String get baseDirectory => _baseDirectory ?? Directory.current.path;
  static String get imagesDirectory => p.join(baseDirectory, 'images');
  static String get capturesDirectory => p.join(baseDirectory, 'captures');
  static String get dbDirectory => baseDirectory;
}