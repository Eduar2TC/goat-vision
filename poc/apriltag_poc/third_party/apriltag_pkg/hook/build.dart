// Copyright (c) 2026, rainyl. All rights reserved. Use of this source code is governed by a
// Apache-2.0 license that can be found in the LICENSE file.

// ignore_for_file: avoid_print, dead_code

// ignore: unused_import
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_cmake/native_toolchain_cmake.dart';

void main(List<String> args) async {
  await build(args, _builder);
}

Future<void> _builder(BuildInput input, BuildOutputBuilder output) async {
  final packageName = input.packageName;
  final packagePath = Uri.directory(await getPackagePath(packageName));
  final sourceDir = packagePath.resolve('src/apriltag');
  final userDefines = input.userDefines;
  final defsOptions = userDefines["options"] as Map<String, dynamic>?;

  final debugMode = defsOptions?['debug'] as bool? ?? false;
  final buildLocal = defsOptions?['build_local'] as bool? ?? false;

  final logger = Logger("")
    ..level = Level.ALL
    ..onRecord.listen((record) => debugMode ? stderr.writeln(record.message) : print(record.message));

  final defsDefines = userDefines["defines"] as Map<String, dynamic>?;
  final defsCommon = (defsDefines?['common'] as Map<String, dynamic>? ?? {}).cast<String, String>();
  final defsPlatform = switch (input.config.code.targetOS) {
    OS.android => (defsDefines?["android"] as Map<String, dynamic>? ?? {}).cast<String, String>(),
    OS.iOS => (defsDefines?["ios"] as Map<String, dynamic>? ?? {}).cast<String, String>(),
    OS.linux => (defsDefines?["linux"] as Map<String, dynamic>? ?? {}).cast<String, String>(),
    OS.macOS => (defsDefines?["macos"] as Map<String, dynamic>? ?? {}).cast<String, String>(),
    OS.windows => (defsDefines?["windows"] as Map<String, dynamic>? ?? {}).cast<String, String>(),
    _ => <String, String>{},
  };
  final defines = {...defsCommon, ...defsPlatform};

  logger.info("defines: $defines");

  final builder = CMakeBuilder.create(
    name: packageName,
    sourceDir: sourceDir,
    generator: Generator.ninja,
    buildLocal: buildLocal,
    targets: ['install'],
    defines: {
      'CMAKE_EXPORT_COMPILE_COMMANDS': 'ON',
      'CMAKE_INSTALL_PREFIX': input.outputDirectory.resolve('install').toFilePath(),
      "BUILD_SHARED_LIBS": "ON",
      "BUILD_EXAMPLES": "OFF",
      "BUILD_PYTHON_WRAPPER": "OFF",
      ...defines,
    },
  );

  await builder.run(input: input, output: output, logger: logger);

  // [PoC patch, goat-vision] CMake installs libapriltag.so as a *symlink*
  // (libapriltag.so -> .so.3 -> .so.3.4.5). findCodeAssets walks with
  // followLinks:false and skips non-File entities, so exact-name matching on
  // 'apriltag' (libapriltag.so) never finds anything and the FFI asset id
  // 'package:apriltag/apriltag.dart' stays empty. Match the real
  // versioned file instead. Reported upstream:
  // https://github.com/rainyl/apriltag.dart
  await output.findAndAddCodeAssets(
    input,
    outDir: input.outputDirectory.resolve('install'),
    names: {r'libapriltag\.so(\.\d+)*$': 'apriltag.dart'},
    regExp: true,
    logger: logger,
  );
}
