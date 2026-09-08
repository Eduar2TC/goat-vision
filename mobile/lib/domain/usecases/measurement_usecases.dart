import 'package:goatvision/domain/entities/animal.dart';
import 'package:goatvision/domain/repositories/animal_repository.dart';
import 'package:goatvision/domain/repositories/measurement_repository.dart';

class SaveMeasurementUseCase {
  final dynamic measurementRepository;

  SaveMeasurementUseCase(this.measurementRepository);

  Future<void> execute(Object measurement) async {
    await measurementRepository.saveMeasurement(measurement);
  }
}

class GetMeasurementHistoryUseCase {
  final dynamic measurementRepository;

  GetMeasurementHistoryUseCase(this.measurementRepository);

  Future<List<Object>> execute(String animalId) async {
    return await measurementRepository.getMeasurementsForAnimal(animalId);
  }
}

class DeleteMeasurementUseCase {
  final dynamic measurementRepository;

  DeleteMeasurementUseCase(this.measurementRepository);

  Future<void> execute(String id) async {
    await measurementRepository.deleteMeasurement(id);
  }
}

class LoadModelUseCase {
  final dynamic modelRepository;

  LoadModelUseCase(this.modelRepository);

  Future<void> execute(void input) async {
    await modelRepository.load();
  }
}

class AnimalStatsExtension {
  static Map<String, Object?> getStats(
    List<Animal> animals,
    List<Object> measurements,
  ) {
    return {};
  }
}