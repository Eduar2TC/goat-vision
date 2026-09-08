import 'dart:convert';
import 'dart:io';

import 'package:goatvision/core/storage/app_storage.dart';
import 'package:goatvision/core/storage/dataset_log_format.dart';

/// Persistencia del dataset recolectado en modo desarrollador.
///
/// Dev tool: nunca bloquea el flujo principal; cualquier error se ignora.
class DatasetLogService {
  DatasetLogService._();

  static File get _file =>
      File.fromUri(Uri.file('${AppStorage.baseDirectory}/dataset_log.jsonl'));

  static Future<void> append(Map<String, Object> row) async {
    try {
      final file = _file;
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${encodeJsonl(row)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Best effort: fallar en silencio no debe afectar el guardado normal.
    }
  }

  static Future<List<Map<String, Object>>> readRows() async {
    final rows = <Map<String, Object>>[];
    try {
      final file = _file;
      if (!await file.exists()) return rows;
      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          rows.add(decoded.map((k, v) => MapEntry(k, v ?? '')));
        }
      }
    } catch (_) {
      return rows;
    }
    return rows;
  }

  static Future<File> exportCsv() async {
    final rows = await readRows();
    final csv = rowsToCsv(rows);
    final file = File.fromUri(
      Uri.file('${AppStorage.baseDirectory}/dataset.csv'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(csv, flush: true);
    return file;
  }
}