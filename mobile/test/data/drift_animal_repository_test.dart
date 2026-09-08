import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/data/database/app_database.dart';
import 'package:goatvision/data/repositories/drift_animal_repository.dart';
import 'package:goatvision/domain/entities/animal.dart';

void main() {
  late AppDatabase db;
  late DriftAnimalRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftAnimalRepository(db);
  });

  tearDown(() => db.close());

  Future<void> insertAnimal(String id, String name) {
    final now = DateTime(2026, 1, 1);
    return db.into(db.animals).insert(
          AnimalsCompanion.insert(
            id: id,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> insertMeasurement(String id, String animalId,
      {String? captureId}) {
    return db.into(db.measurements).insert(
          MeasurementsCompanion.insert(
            id: id,
            animalId: animalId,
            timestamp: DateTime(2026, 1, 1, 12),
            estimatedWeightKg: 45,
            lowerWeightKg: 40,
            upperWeightKg: 50,
            confidence: 0.7,
            modelVersion: 'test',
            datasetVersion: 'test',
            captureId: Value(captureId),
          ),
        );
  }

  Future<void> insertMorphometrics(String id, String measurementId) {
    return db.into(db.morphometricMeasurements).insert(
          MorphometricMeasurementsCompanion.insert(
            id: id,
            measurementId: measurementId,
            bodyLengthCm: 60,
            withersHeightCm: 58,
            rumpHeightCm: 60,
            chestDepthCm: 34,
            chestWidthCm: 19,
            rumpWidthCm: 17,
            rumpLengthCm: 18,
            pawHeightCm: 12,
            bodyAreaCm2: 2400,
            bodyAspectRatio: 1.4,
          ),
        );
  }

  Future<void> insertCapture(
      String id, String measurementId, String path) {
    return db.into(db.captures).insert(
          CapturesCompanion.insert(
            id: id,
            measurementId: measurementId,
            imagePath: path,
            viewType: 'side',
            imageWidth: 720,
            imageHeight: 1280,
            calibrationMethod: 'marker',
            calibrationScale: 0.24,
            qualityScore: 0.9,
            createdAt: DateTime(2026, 1, 1, 12),
          ),
        );
  }

  test('delete removes animal with children and images in cascade', () async {
    await insertAnimal('a1', 'Luna');
    await insertAnimal('a2', 'Chispa');

    await insertMeasurement('m1', 'a1', captureId: 'c1');
    await insertMorphometrics('mf1', 'm1');
    await insertCapture('c1', 'm1', '/img/c1.jpg');

    await insertMeasurement('m2', 'a1');
    await insertMorphometrics('mf2', 'm2');

    await insertMeasurement('m3', 'a2');

    await repo.deleteAnimal('a1');

    expect(await db.select(db.animals).get(), hasLength(1));
    expect((await db.select(db.animals).get()).single.id, 'a2');

    expect(await db.select(db.measurements).get(), hasLength(1));
    expect(
      (await db.select(db.measurements).get()).single.animalId,
      'a2',
    );

    expect(await db.select(db.captures).get(), isEmpty);
    expect(await db.select(db.morphometricMeasurements).get(), isEmpty);
  });

  test('deleting unknown id is a no-op and keeps siblings', () async {
    await insertAnimal('a1', 'Luna');
    await insertMeasurement('m1', 'a1');

    await repo.deleteAnimal('no-existe');

    expect(await db.select(db.animals).get(), hasLength(1));
    expect(await db.select(db.measurements).get(), hasLength(1));
  });

  test('delete animal without measurements still removes the row', () async {
    await insertAnimal('a3', 'Sola');
    await repo.deleteAnimal('a3');
    expect(await db.select(db.animals).get(), isEmpty);
  });
}