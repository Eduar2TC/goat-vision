import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goatvision/core/constants/app_colors.dart';
import 'package:goatvision/data/repositories/repository_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animals = ref.watch(animalRepositoryProvider);
    final measurements = ref.watch(measurementRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, color: AppColors.primary),
            SizedBox(width: 8),
            Text('GoatVision'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: Future.wait([
            animals.getAnimals(),
            measurements.getAllMeasurements(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar datos'));
            }

            final data = snapshot.data as List<Object?>;
            final animalList = data[0] as List<dynamic>;
            final allMeasurements = data[1] as List<dynamic>;

            double? avgWeight;
            if (allMeasurements.isNotEmpty) {
              double total = 0;
              for (final m in allMeasurements) {
                final rec = m;
                total += rec.estimatedWeightKg as double;
              }
              avgWeight = total / allMeasurements.length;
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatCard(
                  icon: Icons.pets,
                  label: 'Mis cabras',
                  value: '${animalList.length}',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                _StatCard(
                  icon: Icons.monitor_weight,
                  label: 'Peso promedio',
                  value: avgWeight == null
                      ? '—'
                      : '${avgWeight.toStringAsFixed(1)} kg',
                  color: AppColors.accent,
                ),
                const SizedBox(height: 12),
                _StatCard(
                  icon: Icons.history,
                  label: 'Últimas mediciones',
                  value: '${allMeasurements.length}',
                  color: AppColors.info,
                ),
                const SizedBox(height: 24),
                Text(
                  'Últimas estimaciones',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (allMeasurements.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Aún no hay mediciones. Toca "Escanear cabra" para '
                        'estimar el peso solo con la cámara.',
                      ),
                    ),
                  )
                else
                  for (final m in allMeasurements.take(5))
                    _MeasurementTile(measurement: m),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/capture'),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Escanear cabra'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/animals'),
                  icon: const Icon(Icons.pets),
                  label: const Text('Administrar cabras'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(label),
      ),
    );
  }
}

class _MeasurementTile extends StatelessWidget {
  final dynamic measurement;

  const _MeasurementTile({required this.measurement});

  @override
  Widget build(BuildContext context) {
    final rec = measurement;
    final weight = (rec.estimatedWeightKg as double?) ?? 0;
    final ts = (rec.timestamp as DateTime?) ?? DateTime.now();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.monitor_weight),
        title: Text('≈ ${weight.toStringAsFixed(1)} kg'),
        subtitle: Text('${ts.day}/${ts.month}/${ts.year}'),
      ),
    );
  }
}