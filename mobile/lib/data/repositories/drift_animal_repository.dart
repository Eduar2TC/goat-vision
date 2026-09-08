import 'package:drift/drift.dart';
import 'package:goatvision/core/storage/image_storage_service.dart';
import 'package:goatvision/data/database/app_database.dart';
import 'package:goatvision/domain/entities/animal.dart';
import 'package:goatvision/domain/repositories/animal_repository.dart';

class DriftAnimalRepository implements AnimalRepository {
  final AppDatabase _db;

  DriftAnimalRepository(this._db);

  @override
  Future<void> saveAnimal(Animal animal) async {
    await _db.into(_db.animals).insertOnConflictUpdate(
          AnimalsCompanion.insert(
            id: animal.id,
            name: animal.name,
            breed: Value(animal.breed),
            sex: Value(animal.sex),
            birthDate: Value(animal.birthDate),
            notes: Value(animal.notes),
            createdAt: animal.createdAt,
            updatedAt: animal.updatedAt,
          ),
        );
  }

  @override
  Future<List<Animal>> getAnimals() async {
    final rows = await (_db.select(_db.animals)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<Animal?> getAnimal(String id) async {
    final row = await (_db.select(_db.animals)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> updateAnimal(Animal animal) async {
    await saveAnimal(animal);
  }

  @override
  Future<void> deleteAnimal(String id) async {
    final imagePaths = <String>[];
    await _db.transaction(() async {
      final measurements = await (_db.select(_db.measurements)
            ..where((t) => t.animalId.equals(id)))
          .get();
      final measurementIds = measurements.map((m) => m.id).toList();

      if (measurementIds.isNotEmpty) {
        // Cascade: captures -> morphometrics -> measurements -> animal.
        final captures = await (_db.select(_db.captures)
              ..where((t) => t.measurementId.isIn(measurementIds)))
            .get();
        imagePaths.addAll(
          captures.map((c) => c.imagePath).where((p) => p.isNotEmpty),
        );
        await (_db.delete(_db.captures)
              ..where((t) => t.measurementId.isIn(measurementIds)))
            .go();
        await (_db.delete(_db.morphometricMeasurements)
              ..where((t) => t.measurementId.isIn(measurementIds)))
            .go();
      }

      await (_db.delete(_db.measurements)
            ..where((t) => t.animalId.equals(id)))
          .go();
      await (_db.delete(_db.animals)..where((t) => t.id.equals(id))).go();
    });

    // Best-effort physical cleanup of stored capture images.
    if (imagePaths.isEmpty) return;
    try {
      final storage = await ImageStorageService.create();
      for (final path in imagePaths) {
        await storage.deleteCapture(path);
      }
    } catch (e) {
      // Image cleanup must never block the DB delete.
    }
  }

  @override
  Future<List<Animal>> searchAnimals(String query) async {
    final term = '%$query%';
    final rows = await (_db.select(_db.animals)
          ..where((t) => t.name.like(term) | t.breed.like(term)))
        .get();
    return rows.map(_toEntity).toList();
  }

  Animal _toEntity(AnimalRow row) {
    return Animal(
      id: row.id,
      name: row.name,
      breed: row.breed,
      sex: row.sex,
      birthDate: row.birthDate,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}