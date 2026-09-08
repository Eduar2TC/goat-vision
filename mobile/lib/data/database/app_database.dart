import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:goatvision/core/constants/app_constants.dart';

part 'app_database.g.dart';

class Animals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get breed => text().nullable()();
  TextColumn get sex => text().nullable()();
  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Measurements extends Table {
  TextColumn get id => text()();
  TextColumn get animalId => text().references(Animals, #id)();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get estimatedWeightKg => real()();
  RealColumn get lowerWeightKg => real()();
  RealColumn get upperWeightKg => real()();
  RealColumn get confidence => real()();
  RealColumn get bcs => real().nullable()();
  TextColumn get modelVersion => text()();
  TextColumn get datasetVersion => text()();
  TextColumn get captureId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Captures extends Table {
  TextColumn get id => text()();
  TextColumn get measurementId => text().references(Measurements, #id)();
  TextColumn get imagePath => text()();
  TextColumn get viewType => text()();
  IntColumn get imageWidth => integer()();
  IntColumn get imageHeight => integer()();
  TextColumn get calibrationMethod => text()();
  RealColumn get calibrationScale => real()();
  RealColumn get qualityScore => real()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class MorphometricMeasurements extends Table {
  TextColumn get id => text()();
  TextColumn get measurementId => text().references(Measurements, #id)();
  RealColumn get bodyLengthCm => real()();
  RealColumn get withersHeightCm => real()();
  RealColumn get rumpHeightCm => real()();
  RealColumn get chestDepthCm => real()();
  RealColumn get chestWidthCm => real()();
  RealColumn get rumpWidthCm => real()();
  RealColumn get rumpLengthCm => real()();
  RealColumn get pawHeightCm => real()();
  RealColumn get bodyAreaCm2 => real()();
  RealColumn get bodyAspectRatio => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Animals,
  Measurements,
  Captures,
  MorphometricMeasurements,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);
  AppDatabase.forNative(super.e);

  @override
  int get schemaVersion => AppConstants.dbVersion;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, AppConstants.dbName));
      return NativeDatabase.createInBackground(file);
    });
  }
}