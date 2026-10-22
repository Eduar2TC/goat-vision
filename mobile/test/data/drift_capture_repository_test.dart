import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/data/database/app_database.dart';
import 'package:goatvision/data/repositories/drift_capture_repository.dart';

void main() {
  late AppDatabase db;
  late DriftCaptureRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftCaptureRepository(db);
  });

  tearDown(() => db.close());

  Future<void> insertMeasurement(String id, String animalId) async {
    final now = DateTime(2026, 1, 1);
    await db.into(db.animals).insert(
          AnimalsCompanion.insert(
            id: animalId,
            name: 'Cabra $animalId',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.measurements).insert(
          MeasurementsCompanion.insert(
            id: id,
            animalId: animalId,
            timestamp: now,
            estimatedWeightKg: 45,
            lowerWeightKg: 40,
            upperWeightKg: 50,
            confidence: 0.7,
            modelVersion: 'test',
            datasetVersion: 'test',
          ),
        );
  }

  Future<void> insertCapture(
    String id,
    String measurementId,
    String animalId, {
    String method = 'marker',
    double scale = 0.042,
  }) async {
    final now = DateTime(2026, 1, 1, 12);
    await db.into(db.captures).insert(
          CapturesCompanion.insert(
            id: id,
            measurementId: measurementId,
            imagePath: 'img/$id.png',
            viewType: 'side',
            imageWidth: 1280,
            imageHeight: 720,
            calibrationMethod: method,
            calibrationScale: scale,
            qualityScore: 0.9,
            createdAt: now,
          ),
        );
  }

  test('getCapturesById devuelve método y escala por captureId de la medición',
      () async {
    await insertMeasurement('m1', 'a1');
    await insertMeasurement('m2', 'a2');
    await insertCapture('c1', 'm1', 'a1',
        method: 'marker', scale: 0.0421);
    await insertCapture('c2', 'm2', 'a2',
        method: 'ar', scale: 0.0150);

    final map = await repo.getCapturesById();

    expect(map.keys, unorderedEquals(['c1', 'c2']));
    expect(map['c1']!.calibrationMethod, 'marker');
    expect(map['c1']!.calibrationScale, closeTo(0.0421, 1e-9));
    expect(map['c2']!.calibrationMethod, 'ar');
    expect(map['c2']!.calibrationScale, closeTo(0.0150, 1e-9));
  });

  test('sin capturas → mapa vacío (el historial mostrará "sin escala")',
      () async {
    expect(await repo.getCapturesById(), isEmpty);
  });
}
