import 'package:drift/drift.dart';
import 'package:goatvision/data/database/app_database.dart';

class CaptureRecord {
  final String id;
  final String measurementId;
  final String imagePath;
  final String viewType;
  final int imageWidth;
  final int imageHeight;
  final String calibrationMethod;
  final double calibrationScale;
  final double qualityScore;
  final DateTime createdAt;

  const CaptureRecord({
    required this.id,
    required this.measurementId,
    required this.imagePath,
    required this.viewType,
    required this.imageWidth,
    required this.imageHeight,
    required this.calibrationMethod,
    required this.calibrationScale,
    required this.qualityScore,
    required this.createdAt,
  });
}

class DriftCaptureRepository {
  final AppDatabase _db;

  DriftCaptureRepository(this._db);

  Future<void> saveCapture(CaptureRecord record) async {
    await _db.into(_db.captures).insert(
          CapturesCompanion.insert(
            id: record.id,
            measurementId: record.measurementId,
            imagePath: record.imagePath,
            viewType: record.viewType,
            imageWidth: record.imageWidth,
            imageHeight: record.imageHeight,
            calibrationMethod: record.calibrationMethod,
            calibrationScale: record.calibrationScale,
            qualityScore: record.qualityScore,
            createdAt: record.createdAt,
          ),
        );
  }

  Future<CaptureRecord?> getCapture(String id) async {
    final row = await (_db.select(_db.captures)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return CaptureRecord(
      id: row.id,
      measurementId: row.measurementId,
      imagePath: row.imagePath,
      viewType: row.viewType,
      imageWidth: row.imageWidth,
      imageHeight: row.imageHeight,
      calibrationMethod: row.calibrationMethod,
      calibrationScale: row.calibrationScale,
      qualityScore: row.qualityScore,
      createdAt: row.createdAt,
    );
  }

  Future<CaptureRecord?> getCaptureForMeasurement(String measurementId) async {
    final row = await (_db.select(_db.captures)
          ..where((t) => t.measurementId.equals(measurementId)))
        .getSingleOrNull();
    if (row == null) return null;
    return CaptureRecord(
      id: row.id,
      measurementId: row.measurementId,
      imagePath: row.imagePath,
      viewType: row.viewType,
      imageWidth: row.imageWidth,
      imageHeight: row.imageHeight,
      calibrationMethod: row.calibrationMethod,
      calibrationScale: row.calibrationScale,
      qualityScore: row.qualityScore,
      createdAt: row.createdAt,
    );
  }

  Future<List<String>> getAllImagePaths() async {
    final rows = await _db.select(_db.captures).get();
    return rows.where((r) => r.imagePath.isNotEmpty).map((r) => r.imagePath).toList();
  }

  Future<void> deleteCapture(String id) async {
    await (_db.delete(_db.captures)..where((t) => t.id.equals(id))).go();
  }
}