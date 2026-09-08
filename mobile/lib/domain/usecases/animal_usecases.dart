import 'package:goatvision/domain/entities/animal.dart';
import 'package:goatvision/domain/entities/prediction.dart';

abstract class UseCase<Input, Output> {
  Future<Output> execute(Input input);
}

class CreateAnimalUseCase implements UseCase<Animal, void> {
  final dynamic repository;

  CreateAnimalUseCase(this.repository);

  @override
  Future<void> execute(Animal animal) async {
    await repository.saveAnimal(animal);
  }
}

class UpdateAnimalUseCase implements UseCase<Animal, void> {
  final dynamic repository;

  UpdateAnimalUseCase(this.repository);

  @override
  Future<void> execute(Animal animal) async {
    await repository.updateAnimal(animal);
  }
}

class DeleteAnimalUseCase implements UseCase<String, void> {
  final dynamic repository;

  DeleteAnimalUseCase(this.repository);

  @override
  Future<void> execute(String id) async {
    await repository.deleteAnimal(id);
  }
}

class GetAnimalUseCase implements UseCase<String, Animal?> {
  final dynamic repository;

  GetAnimalUseCase(this.repository);

  @override
  Future<Animal?> execute(String id) async {
    return await repository.getAnimal(id);
  }
}

class GetAllAnimalsUseCase implements UseCase<void, List<Animal>> {
  final dynamic repository;

  GetAllAnimalsUseCase(this.repository);

  @override
  Future<List<Animal>> execute(void input) async {
    return await repository.getAnimals();
  }
}