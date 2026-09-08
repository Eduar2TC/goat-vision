abstract class MeasurementRepository {
  Future<void> saveMeasurement(Object measurement);
  Future<Object?> getMeasurement(String id);
  Future<List<Object>> getMeasurementsForAnimal(String animalId);
  Future<List<Object>> getAllMeasurements();
  Future<void> deleteMeasurement(String id);
}