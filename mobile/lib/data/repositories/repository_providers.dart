import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goatvision/data/database/database_provider.dart';
import 'package:goatvision/data/repositories/drift_animal_repository.dart';
import 'package:goatvision/data/repositories/drift_capture_repository.dart';
import 'package:goatvision/data/repositories/drift_measurement_repository.dart';

final animalRepositoryProvider = Provider<DriftAnimalRepository>((ref) {
  return DriftAnimalRepository(ref.watch(databaseProvider));
});

final measurementRepositoryProvider =
    Provider<DriftMeasurementRepository>((ref) {
  return DriftMeasurementRepository(ref.watch(databaseProvider));
});

final captureRepositoryProvider = Provider<DriftCaptureRepository>((ref) {
  return DriftCaptureRepository(ref.watch(databaseProvider));
});