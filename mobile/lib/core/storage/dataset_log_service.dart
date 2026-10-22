import 'dart:convert';
import 'dart:io';

import 'package:goatvision/core/storage/app_storage.dart';
import 'package:goatvision/core/storage/dataset_log_format.dart';
import 'package:goatvision/core/utils/app_logger.dart';

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
    } catch (e) {
      // Dev tool: registrar el fallo sin bloquear el guardado normal.
      AppLogger.instance.warning('DatasetLogService.append error: $e');
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
          // Preserve null values for numeric fields, don't convert to empty string
          rows.add(Map<String, Object>.from(decoded));
        }
      }
    } catch (e) {
      AppLogger.instance.warning('DatasetLogService.readRows error: $e');
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
