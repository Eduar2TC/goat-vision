import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/data/providers/providers.dart';
import 'package:goatvision/domain/entities/calibration.dart';
import 'package:goatvision/features/results/presentation/result_screen.dart';

void main() {
  final calibration = Calibration(
    markerWidthPixels: 100,
    markerHeightPixels: 100,
    realWidthCm: 30,
    cmPerPixel: 0.3,
    confidence: 0.9,
    timestamp: DateTime(2026, 9, 7),
    method: 'marker',
  );

  testWidgets('Result screen shows weight estimation with uncertainty',
      (tester) async {
    final session = AnalysisSessionState(
      animalId: 'goat-1',
      estimatedWeightKg: 43.2,
      lowerWeightKg: 40.8,
      upperWeightKg: 45.6,
      confidence: 0.87,
      modelVersion: 'goat-weight-v1.0',
      datasetVersion: 'goat-dataset-2026-09',
      morphometrics: {
        'body_length_cm': 72.5,
        'withers_height_cm': 64.3,
      },
      timestamp: DateTime(2026, 9, 7),
      calibration: calibration,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analysisSessionProvider.overrideWith((ref) => session),
        ],
        child: const MaterialApp(home: ResultScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('≈ 43.2 kg'), findsOneWidget);
    expect(find.textContaining('40.8'), findsOneWidget);
    expect(find.textContaining('45.6'), findsOneWidget);
    expect(find.textContaining('87 %'), findsOneWidget);
    expect(find.textContaining('visión artificial'), findsOneWidget);
    // Metadatos de la medición guardada: método de calibración real + escala.
    // La línea queda al final de un ListView lazy: hay que hacer scroll para
    // que se construya en el viewport de test.
    await tester.dragUntilVisible(
      find.textContaining('Calibración: Marcador · 0.300 cm/px'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Calibración: Marcador · 0.300 cm/px'),
      findsOneWidget,
    );
  });

  testWidgets('Result screen shows fallback when no data', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analysisSessionProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: ResultScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('No hay resultados disponibles'), findsOneWidget);
  });
}