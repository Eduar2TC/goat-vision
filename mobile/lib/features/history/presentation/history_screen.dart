import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goatvision/core/constants/app_colors.dart';
import 'package:goatvision/core/utils/unit_converter.dart';
import 'package:goatvision/data/repositories/repository_providers.dart';
import 'package:goatvision/data/repositories/drift_capture_repository.dart';
import 'package:goatvision/data/repositories/drift_measurement_repository.dart';
import 'package:goatvision/domain/entities/animal.dart';
import 'package:goatvision/features/history/domain/history_filter.dart';

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
    final captureRepo = ref.watch(captureRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: SafeArea(
        child: FutureBuilder(
          future: Future.wait([
            animalRepo.getAnimals(),
            measurementRepo.getAllMeasurements(),
            captureRepo.getCapturesById(),
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
            final capturesById = data[2]
                as Map<String, CaptureRecord>;

            final animalById = {for (final a in animals) a.id: a.name};

            final records = filterHistoryRecords(
              records: allRecords,
              animalNamesById: animalById,
              query: _query,
            );

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
                        final capture = capturesById[r.captureId];
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$animalName · '
                                '${UnitConverter.range(r.lowerWeightKg, r.upperWeightKg)}',
                              ),
                              const SizedBox(height: 4),
                              // Columna de calibración: método y escala cm/px
                              // de la captura (datos persistidos en Captures).
                              _CalibrationChip(capture: capture),
                            ],
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

/// Chip con el método de calibración y la escala cm/px de la captura
/// asociada a la medición. Sin captura (mediciones antiguas o sin imagen),
/// se marca como "sin escala" para el operador — no se inventa.
///
/// Metodología (`method`) mostrada como etiqueta legible:
/// - `marker` → ArUco tag36h11 (30 cm)
/// - `ar / fixed` y demás → método crudo + nota
/// - desconocido/vacío → "sin escala"
class _CalibrationChip extends StatelessWidget {
  final CaptureRecord? capture;

  const _CalibrationChip({this.capture});

  @override
  Widget build(BuildContext context) {
    final capture = this.capture;
    final hasScale = capture != null && capture.calibrationScale > 0;
    final method = hasScale
        ? switch (capture.calibrationMethod) {
            'marker' => 'ArUco 30 cm',
            '' => 'sin método',
            final other => other,
          }
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: hasScale
            ? AppColors.primary.withValues(alpha: 0.10)
            : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        hasScale
            ? '$method · ${capture!.calibrationScale.toStringAsFixed(3)} cm/px'
            : 'Calibración sin escala',
        style: TextStyle(
          fontSize: 11,
          color: hasScale
              ? AppColors.primary
              : Theme.of(context).hintColor,
        ),
      ),
    );
  }
}