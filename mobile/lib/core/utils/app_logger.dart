import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  AppLogger._();

  static final AppLogger _instance = AppLogger._();
  static AppLogger get instance => _instance;

  final bool _debugMode = kDebugMode;

  void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {
    if (_debugMode || level == LogLevel.error) {
      final timestamp = DateTime.now().toIso8601String();
      final prefix = _levelPrefix(level);
      debugPrint('[$prefix][$timestamp] $message');
      if (error != null) debugPrint('  ERROR: $error');
      if (stackTrace != null) debugPrint('  STACK: $stackTrace');
    }
  }

  void debug(String message) => log(LogLevel.debug, message);
  void info(String message) => log(LogLevel.info, message);
  void warning(String message) => log(LogLevel.warning, message);
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, message, error: error, stackTrace: stackTrace);

  String _levelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO ';
      case LogLevel.warning:
        return 'WARN ';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}