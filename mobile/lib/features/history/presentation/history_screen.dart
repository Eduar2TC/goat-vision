import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goatvision/core/constants/app_colors.dart';
import 'package:goatvision/core/utils/unit_converter.dart';
import 'package:goatvision/data/repositories/repository_providers.dart';
import 'package:goatvision/data/repositories/drift_measurement_repository.dart';
import 'package:goatvision/domain/entities/animal.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
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
            final allRecords =
                (data[1] as List<dynamic>).cast<MeasurementRecord>();

            final animalById = {for (final a in animals) a.id: a.name};

            final query = _query.trim().toLowerCase();
            final records = query.isEmpty
                ? allRecords
                : allRecords.where((r) {
                    final name = (animalById[r.animalId] ?? '').toLowerCase();
                    final weight = r.estimatedWeightKg
                        .toStringAsFixed(1)
                        .toLowerCase();
                    return name.contains(query) || weight.contains(query);
                  }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Buscar por cabra o peso aproximado…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                if (records.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        allRecords.isEmpty
                            ? 'Aún no hay mediciones registradas'
                            : 'Sin resultados para "$_query"',
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final r = records[index];
                        final d = r.timestamp;
                        final animalName = animalById[r.animalId] ?? 'Desconocida';
                        return ListTile(
                          onTap: () =>
                              context.push('/animals/${r.animalId}'),
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
                            '≈ ${UnitConverter.weight(r.estimatedWeightKg)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '$animalName · '
                            '${UnitConverter.range(r.lowerWeightKg, r.upperWeightKg)}',
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
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}