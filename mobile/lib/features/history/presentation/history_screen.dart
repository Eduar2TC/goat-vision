import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goatvision/core/constants/app_colors.dart';
import 'package:goatvision/data/repositories/repository_providers.dart';
import 'package:goatvision/data/repositories/drift_measurement_repository.dart';
import 'package:goatvision/domain/entities/animal.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animalRepo = ref.watch(animalRepositoryProvider);
    final measurementRepo = ref.watch(measurementRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: SafeArea(
        child: FutureBuilder(
          future: Future.wait([
            animalRepo.getAnimals(),
            measurementRepo.getAllMeasurements(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar historial'));
            }

            final data = snapshot.data!;
            final animals = (data[0] as List<dynamic>).cast<Animal>();
            final records =
                (data[1] as List<dynamic>).cast<MeasurementRecord>();

            if (records.isEmpty) {
              return const Center(
                child: Text('Aún no hay mediciones registradas'),
              );
            }

            final animalById = {for (final a in animals) a.id: a.name};

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = records[index];
                final d = r.timestamp;
                final animalName = animalById[r.animalId] ?? 'Desconocida';
                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${d.day}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            const [
                              'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
                              'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
                            ][d.month - 1],
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
                  title: Text(
                    '≈ ${r.estimatedWeightKg.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '$animalName · '
                    '${r.lowerWeightKg.toStringAsFixed(1)}–${r.upperWeightKg.toStringAsFixed(1)} kg',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(r.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Text(
                        'confianza',
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}