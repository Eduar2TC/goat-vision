import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goatvision/core/constants/app_colors.dart';
import 'package:goatvision/data/repositories/repository_providers.dart';
import 'package:goatvision/domain/entities/animal.dart';

class AnimalListScreen extends ConsumerStatefulWidget {
  const AnimalListScreen({super.key});

  @override
  ConsumerState<AnimalListScreen> createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends ConsumerState<AnimalListScreen> {
  String _query = '';
  bool _ascending = true;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(animalRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis cabras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _ascending = value == 'asc');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'asc',
                child: Text('Ordenar A-Z'),
              ),
              const PopupMenuItem(
                value: 'desc',
                child: Text('Ordenar Z-A'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/animals/add'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cabra'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Animal>>(
          future: repo.getAnimals(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar cabras'));
            }

            var animals = snapshot.data ?? [];
            if (_query.isNotEmpty) {
              animals = animals
                  .where((a) =>
                      a.name.toLowerCase().contains(_query.toLowerCase()))
                  .toList();
            }
            animals.sort((a, b) => _ascending
                ? a.name.compareTo(b.name)
                : b.name.compareTo(a.name));

            if (animals.isEmpty) {
              return const _EmptyState();
            }

            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: animals.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final animal = animals[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(Icons.pets, color: AppColors.primary),
                  ),
                  title: Text(
                    animal.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      if (animal.breed != null) animal.breed!,
                      if (animal.ageDisplay != null) animal.ageDisplay!,
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/animals/${animal.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Buscar cabra',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() => _query = value);
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pets,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text('Aún no hay cabras registradas'),
          const SizedBox(height: 8),
          Text(
            'Toca el botón + para crear tu primera cabra',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}