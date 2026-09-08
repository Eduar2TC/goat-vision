import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goatvision/core/storage/app_storage.dart';

ThemeMode _fromPref(String value) {
  switch (value) {
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return ThemeMode.light;
  }
}

String themeModeToPref(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
    default:
      return 'light';
  }
}

final themeModeProvider = StateProvider<ThemeMode>(
  (ref) => _fromPref(AppStorage.themeMode),
);