import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:goatvision/core/storage/app_storage.dart';
import 'package:goatvision/core/utils/app_logger.dart';
import 'package:goatvision/domain/entities/animal.dart';

class ImageStorageService {
  ImageStorageService._(this._baseDir);

  final String _baseDir;
  static ImageStorageService? _instance;

  static Future<ImageStorageService> create() async {
    final baseDir = AppStorage.capturesDirectory;
    final dir = Directory(baseDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _instance = ImageStorageService(baseDir);
    return _instance!;
  }

  static ImageStorageService get instance => _instance!;

  Future<String> saveCapture({
    required List<int> bytes,
    required String animalId,
  }) async {
    final filename = '${animalId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = p.join(_baseDir, filename);
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    AppLogger.instance.debug('Saved capture to $path');
    return path;
  }

  Future<void> deleteCapture(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.instance.warning('Failed to delete capture $path: $e');
    }
  }

  Future<File?> getCapture(String path) async {
    final file = File(path);
    if (await file.exists()) return file;
    return null;
  }

  Future<int> cleanupUnusedImages(
    Set<String> retainedPaths,
  ) async {
    final dir = Directory(_baseDir);
    if (!await dir.exists()) return 0;

    var removed = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        if (!retainedPaths.contains(entity.path)) {
          try {
            await entity.delete();
            removed++;
          } catch (_) {}
        }
      }
    }
    return removed;
  }

  Future<List<AnimalCaptureInfo>> listCaptures() async {
    final dir = Directory(_baseDir);
    if (!await dir.exists()) return [];

    final result = <AnimalCaptureInfo>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        result.add(
          AnimalCaptureInfo(
            path: entity.path,
            sizeBytes: stat.size,
            createdAt: stat.modified,
          ),
        );
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }
}

class AnimalCaptureInfo {
  final String path;
  final int sizeBytes;
  final DateTime createdAt;

  const AnimalCaptureInfo({
    required this.path,
    required this.sizeBytes,
    required this.createdAt,
  });
}