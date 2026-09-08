import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goatvision/data/repositories/repository_providers.dart';
import 'package:goatvision/domain/entities/animal.dart';
import 'package:uuid/uuid.dart';

class AddAnimalScreen extends ConsumerStatefulWidget {
  const AddAnimalScreen({super.key});

  @override
  ConsumerState<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends ConsumerState<AddAnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _notesController = TextEditingController();

  String? _sex;
  DateTime? _birthDate;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? now.subtract(const Duration(days: 365)),
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(animalRepositoryProvider);
    final now = DateTime.now();
    final animal = Animal(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      breed: _breedController.text.trim().isEmpty
          ? null
          : _breedController.text.trim(),
      sex: _sex,
      birthDate: _birthDate,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await repo.saveAnimal(animal);
    if (context.mounted) {
      context.go('/animals');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva cabra')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: Icon(Icons.pets),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Ingresa un nombre'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(
                  labelText: 'Raza',
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text('Sexo'),
              const SizedBox(height: 8),
              SegmentedButton<String?>(
                segments: const [
                  ButtonSegment(value: 'Macho', label: Text('Macho')),
                  ButtonSegment(value: 'Hembra', label: Text('Hembra')),
                ],
                selected: {_sex},
                onSelectionChanged: (selection) {
                  setState(() => _sex = selection.first);
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.cake),
                title: Text(
                  _birthDate == null
                      ? 'Fecha de nacimiento'
                      : 'Nacimiento: ${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickBirthDate,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Guardar cabra'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}