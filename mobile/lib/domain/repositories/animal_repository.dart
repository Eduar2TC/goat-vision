import 'package:goatvision/domain/entities/animal.dart';

abstract class AnimalRepository {
  Future<void> saveAnimal(Animal animal);
  Future<List<Animal>> getAnimals();
  Future<Animal?> getAnimal(String id);
  Future<void> updateAnimal(Animal animal);
  Future<void> deleteAnimal(String id);
  Future<List<Animal>> searchAnimals(String query);
}