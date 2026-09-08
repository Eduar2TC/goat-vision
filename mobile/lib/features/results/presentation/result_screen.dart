import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goatvision/core/constants/app_colors.dart';
import 'package:goatvision/data/providers/providers.dart';
import 'package:goatvision/data/repositories/drift_measurement_repository.dart';
import 'package:goatvision/data/repositories/drift_capture_repository.dart';
import 'package:goatvision/data/repositories/repository_providers.dart';
import 'package:goatvision/core/utils/app_logger.dart';
import 'package:goatvision/domain/entities/animal.dart';
import 'package:uuid/uuid.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _saving = false;

  Future<void> _save() async {
    final session = ref.read(analysisSessionProvider);
    if (session == null || _saving) return;

    final String animalId;
    try {
      animalId = await _resolveAnimalId(session);
    } catch (e) {
      AppLogger.instance.error('Failed to resolve animal for save', error: e);
      _showMessage('No se pudo registrar la cabra. Intenta de nuevo.');
      return;
    }

    setState(() => _saving = true);
    try {
      final recordId = const Uuid().v4();
      final timestamp = session.timestamp;

      await ref.read(measurementRepositoryProvider).saveMeasurement(
            MeasurementRecord(
              id: recordId,
              animalId: animalId,
              timestamp: timestamp,
              estimatedWeightKg: session.estimatedWeightKg,
              lowerWeightKg: session.lowerWeightKg,
              upperWeightKg: session.upperWeightKg,
              confidence: session.confidence,
              modelVersion: session.modelVersion,
              datasetVersion: session.datasetVersion,
              captureId: session.imagePath != null ? recordId : null,
            ),
          );

      await ref.read(measurementRepositoryProvider).saveMorphometrics(
            MorphometricRecord(
              id: const Uuid().v4(),
              measurementId: recordId,
              values: _cmMap(session),
            ),
          );

      if (session.imagePath != null) {
        await ref.read(captureRepositoryProvider).saveCapture(
              CaptureRecord(
                id: recordId,
                measurementId: recordId,
                imagePath: session.imagePath!,
                viewType: 'side',
                imageWidth: 0,
                imageHeight: 0,
                calibrationMethod: 'marker_aruco',
                calibrationScale: 0,
                qualityScore: session.confidence,
                createdAt: timestamp,
              ),
            );
      }

      AppLogger.instance.info(
        'Saved measurement $recordId for animal $animalId',
      );
      if (!mounted) return;
      context.go('/animals/$animalId');
    } catch (e) {
      AppLogger.instance.error('Failed to save measurement', error: e);
      _showMessage('No se pudo guardar la medición. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Returns the animal to attach the measurement to. If the capture was a
  /// "rapid scan" (no animal selected), a lightweight animal is registered
  /// so the measurement always has a valid owner.
  Future<String> _resolveAnimalId(AnalysisSessionState session) async {
    if (session.animalId.isNotEmpty) return session.animalId;

    final now = DateTime.now();
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final anon = Animal(
      id: const Uuid().v4(),
      name: 'Cabra sin registrar · ${now.day} ${months[now.month - 1]}',
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(animalRepositoryProvider).saveAnimal(anon);
    _showMessage(
      'Medición guardada. Registrada como "${anon.name}" — '
      'edita su nombre cuando quieras.',
    );
    return anon.id;
  }

  Map<String, double> _cmMap(AnalysisSessionState session) {
    return {
      'body_length_cm': session.morphometrics['body_length'] ?? 0,
      'withers_height_cm': session.morphometrics['withers_height'] ?? 0,
      'rump_height_cm': session.morphometrics['rump_height'] ?? 0,
      'chest_depth_cm': session.morphometrics['chest_depth'] ?? 0,
      'chest_width_cm': session.morphometrics['chest_width'] ?? 0,
      'rump_width_cm': session.morphometrics['rump_width'] ?? 0,
      'rump_length_cm': session.morphometrics['rump_length'] ?? 0,
      'paw_height_cm': session.morphometrics['paw_height'] ?? 0,
      'body_area_cm2': session.morphometrics['body_area_cm2'] ?? 0,
      'body_aspect_ratio': session.morphometrics['body_aspect_ratio'] ?? 1,
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _modelLabel(String version) {
    if (version.startsWith('ref-')) {
      return 'Fórmula de referencia (literatura)';
    }
    return version;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(analysisSessionProvider);
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('No hay resultados disponibles')),
      );
    }

    final confidenceColor = session.confidence >= 0.8
        ? AppColors.confidenceHigh
        : session.confidence >= 0.6
            ? AppColors.confidenceMedium
            : AppColors.confidenceLow;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Text(
              'ESTIMACIÓN',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '≈ ${session.estimatedWeightKg.toStringAsFixed(1)} kg',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Rango: ${session.lowerWeightKg.toStringAsFixed(1)}–${session.upperWeightKg.toStringAsFixed(1)} kg',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Confianza: ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: confidenceColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${(session.confidence * 100).toStringAsFixed(0)} %',
                    style: TextStyle(
                      color: confidenceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este es un valor estimado mediante visión artificial. El peso real puede variar.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Medidas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _MeasurementRow(
              label: 'Longitud corporal',
              value: session.morphometrics['body_length'],
            ),
            _MeasurementRow(
              label: 'Altura a la cruz',
              value: session.morphometrics['withers_height'],
            ),
            _MeasurementRow(
              label: 'Altura de grupa',
              value: session.morphometrics['rump_height'],
            ),
            _MeasurementRow(
              label: 'Profundidad de pecho',
              value: session.morphometrics['chest_depth'],
            ),
            _MeasurementRow(
              label: 'Ancho de pecho',
              value: session.morphometrics['chest_width'],
            ),
            _MeasurementRow(
              label: 'Ancho de grupa',
              value: session.morphometrics['rump_width'],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/capture'),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Repetir'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Guardar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Modelo: ${_modelLabel(session.modelVersion)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  final String label;
  final double? value;

  const _MeasurementRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value == null
                ? '—'
                : '${value!.toStringAsFixed(1)} cm',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}