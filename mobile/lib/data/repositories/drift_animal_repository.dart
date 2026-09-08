import 'package:drift/drift.dart';
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
    await (_db.delete(_db.animals)..where((t) => t.id.equals(id))).go();
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