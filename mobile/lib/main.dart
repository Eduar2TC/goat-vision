import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goatvision/app/app.dart';
import 'package:goatvision/core/storage/app_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStorage.initialize();

  runApp(
    const ProviderScope(
      child: GoatVisionApp(),
    ),
  );
}
