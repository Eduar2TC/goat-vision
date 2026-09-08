import 'package:drift/drift.dart';
import 'package:goatvision/data/database/app_database.dart';
import 'package:goatvision/domain/entities/model_info.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';
import 'package:goatvision/domain/entities/prediction.dart';

class MeasurementRecord {
  final String id;
  final String animalId;
  final DateTime timestamp;
  final double estimatedWeightKg;
  final double lowerWeightKg;
  final double upperWeightKg;
  final double confidence;
  final double? bcs;
  final String modelVersion;
  final String datasetVersion;
  final String? captureId;

  const MeasurementRecord({
    required this.id,
    required this.animalId,
    required this.timestamp,
    required this.estimatedWeightKg,
    required this.lowerWeightKg,
    required this.upperWeightKg,
    required this.confidence,
    this.bcs,
    required this.modelVersion,
    required this.datasetVersion,
    this.captureId,
  });

  factory MeasurementRecord.fromMap(Map<String, Object?> map) {
    return MeasurementRecord(
      id: map['id'] as String,
      animalId: map['animal_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      estimatedWeightKg: (map['estimated_weight_kg'] as num).toDouble(),
      lowerWeightKg: (map['lower_weight_kg'] as num).toDouble(),
      upperWeightKg: (map['upper_weight_kg'] as num).toDouble(),
      confidence: (map['confidence'] as num).toDouble(),
      bcs: (map['bcs'] as num?)?.toDouble(),
      modelVersion: map['model_version'] as String,
      datasetVersion: map['dataset_version'] as String,
      captureId: map['capture_id'] as String?,
    );
  }

  Prediction toPrediction() => Prediction(
        estimatedWeightKg: estimatedWeightKg,
        lowerBoundKg: lowerWeightKg,
        upperBoundKg: upperWeightKg,
        confidence: confidence,
        modelVersion: modelVersion,
      );
}

class MorphometricRecord {
  final String id;
  final String measurementId;
  final Map<String, double> values;

  const MorphometricRecord({
    required this.id,
    required this.measurementId,
    required this.values,
  });

  MorphometricFeatures toFeatures() => MorphometricFeatures(
        bodyLengthCm: values['body_length_cm'] ?? 0,
        withersHeightCm: values['withers_height_cm'] ?? 0,
        rumpHeightCm: values['rump_height_cm'] ?? 0,
        chestDepthCm: values['chest_depth_cm'] ?? 0,
        chestWidthCm: values['chest_width_cm'] ?? 0,
        rumpWidthCm: values['rump_width_cm'] ?? 0,
        rumpLengthCm: values['rump_length_cm'] ?? 0,
        pawHeightCm: values['paw_height_cm'] ?? 0,
        bodyAreaCm2: values['body_area_cm2'] ?? 0,
        bodyAspectRatio: values['body_aspect_ratio'] ?? 1,
      );
}

class DriftMeasurementRepository {
  final AppDatabase _db;

  DriftMeasurementRepository(this._db);

  Future<void> saveMeasurement(MeasurementRecord record) async {
    await _db.into(_db.measurements).insert(
          MeasurementsCompanion.insert(
            id: record.id,
            animalId: record.animalId,
            timestamp: record.timestamp,
            estimatedWeightKg: record.estimatedWeightKg,
            lowerWeightKg: record.lowerWeightKg,
            upperWeightKg: record.upperWeightKg,
            confidence: record.confidence,
            bcs: Value(record.bcs),
            modelVersion: record.modelVersion,
            datasetVersion: record.datasetVersion,
            captureId: Value(record.captureId),
          ),
        );
  }

  Future<void> saveMorphometrics(MorphometricRecord record) async {
    await _db.into(_db.morphometricMeasurements).insert(
          MorphometricMeasurementsCompanion.insert(
            id: record.id,
            measurementId: record.measurementId,
            bodyLengthCm: record.values['body_length_cm'] ?? 0,
            withersHeightCm: record.values['withers_height_cm'] ?? 0,
            rumpHeightCm: record.values['rump_height_cm'] ?? 0,
            chestDepthCm: record.values['chest_depth_cm'] ?? 0,
            chestWidthCm: record.values['chest_width_cm'] ?? 0,
            rumpWidthCm: record.values['rump_width_cm'] ?? 0,
            rumpLengthCm: record.values['rump_length_cm'] ?? 0,
            pawHeightCm: record.values['paw_height_cm'] ?? 0,
            bodyAreaCm2: record.values['body_area_cm2'] ?? 0,
            bodyAspectRatio: record.values['body_aspect_ratio'] ?? 1,
          ),
        );
  }

  Future<List<MeasurementRecord>> getMeasurementsForAnimal(String animalId) async {
    final rows = await (_db.select(_db.measurements)
          ..where((t) => t.animalId.equals(animalId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
    return rows.map(_toRecord).toList();
  }

  Future<List<MeasurementRecord>> getAllMeasurements() async {
    final rows = await (_db.select(_db.measurements)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
    return rows.map(_toRecord).toList();
  }

  Future<MeasurementRecord?> getMeasurement(String id) async {
    final row = await (_db.select(_db.measurements)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  Future<MorphometricRecord?> getMorphometrics(String measurementId) async {
    final row = await (_db.select(_db.morphometricMeasurements)
          ..where((t) => t.measurementId.equals(measurementId)))
        .getSingleOrNull();
    if (row == null) return null;
    return MorphometricRecord(
      id: row.id,
      measurementId: row.measurementId,
      values: {
        'body_length_cm': row.bodyLengthCm,
        'withers_height_cm': row.withersHeightCm,
        'rump_height_cm': row.rumpHeightCm,
        'chest_depth_cm': row.chestDepthCm,
        'chest_width_cm': row.chestWidthCm,
        'rump_width_cm': row.rumpWidthCm,
        'rump_length_cm': row.rumpLengthCm,
        'paw_height_cm': row.pawHeightCm,
        'body_area_cm2': row.bodyAreaCm2,
        'body_aspect_ratio': row.bodyAspectRatio,
      },
    );
  }

  Future<void> deleteMeasurement(String id) async {
    await (_db.delete(_db.morphometricMeasurements)..where((t) => t.measurementId.equals(id))).go();
    await (_db.delete(_db.measurements)..where((t) => t.id.equals(id))).go();
  }

  MeasurementRecord _toRecord(MeasurementRow row) {
    return MeasurementRecord(
      id: row.id,
      animalId: row.animalId,
      timestamp: row.timestamp,
      estimatedWeightKg: row.estimatedWeightKg,
      lowerWeightKg: row.lowerWeightKg,
      upperWeightKg: row.upperWeightKg,
      confidence: row.confidence,
      bcs: row.bcs,
      modelVersion: row.modelVersion,
      datasetVersion: row.datasetVersion,
      captureId: row.captureId,
    );
  }
}