import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goatvision/core/constants/app_colors.dart';
import 'package:goatvision/core/utils/unit_converter.dart';
import 'package:goatvision/data/repositories/repository_providers.dart';
import 'package:goatvision/data/repositories/drift_measurement_repository.dart';
import 'package:goatvision/domain/entities/animal.dart';

class AnimalDetailScreen extends ConsumerWidget {
  final String animalId;

  const AnimalDetailScreen({super.key, required this.animalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animalRepo = ref.watch(animalRepositoryProvider);
    final measurementRepo = ref.watch(measurementRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/capture?animalId=$animalId'),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Medir ahora'),
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: Future.wait([
            animalRepo.getAnimal(animalId),
            measurementRepo.getMeasurementsForAnimal(animalId),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar datos'));
            }

            final data = snapshot.data!;
            final animal = data[0] as Animal?;
            final records =
                (data[1] as List<dynamic>).cast<MeasurementRecord>();

            if (animal == null) {
              return const Center(child: Text('Cabra no encontrada'));
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                _Header(animal: animal),
                const SizedBox(height: 8),
                if (records.isNotEmpty) _WeightChart(records: records),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Historial',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                if (records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No hay mediciones. Toca "Medir ahora" para estimar el peso.',
                    ),
                  )
                else
                  for (final record in records)
                    _HistoryTile(record: record),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Animal animal;
  const _Header({required this.animal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.pets,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (animal.breed != null)
                      Text(
                        animal.breed!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _InfoChip(label: 'Sexo', value: animal.sex ?? '—'),
              _InfoChip(label: 'Edad', value: animal.ageDisplay ?? '—'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<MeasurementRecord> records;
  const _WeightChart({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.length < 2) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Peso actual: ≈ ${UnitConverter.weight(records.first.estimatedWeightKg)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final sorted = records.reversed.toList();
    final minWeight = records
        .map((r) => r.lowerWeightKg)
        .reduce((a, b) => a < b ? a : b);
    final maxWeight = records
        .map((r) => r.upperWeightKg)
        .reduce((a, b) => a > b ? a : b);

    final spots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      spots.add(
        FlSpot(i.toDouble(), sorted[i].estimatedWeightKg),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Evolución del peso',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  'Último: ≈ ${UnitConverter.weight(sorted.last.estimatedWeightKg)}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: minWeight - 2,
                  maxY: maxWeight + 2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sorted.length) {
                            return const SizedBox.shrink();
                          }
                          final d = sorted[index].timestamp;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${d.day}/${d.month}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final MeasurementRecord record;
  const _HistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final d = record.timestamp;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.monitor_weight, color: AppColors.primary),
        title: Text(
          '≈ ${UnitConverter.weight(record.estimatedWeightKg)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${d.day} ${_monthName(d.month)} · '
          'Rango: ${UnitConverter.range(record.lowerWeightKg, record.upperWeightKg)}',
        ),
        trailing: Text(
          '${(record.confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return months[month - 1];
  }
}