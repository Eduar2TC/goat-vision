import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/data/database/app_database.dart';
import 'package:goatvision/data/database/database_provider.dart';
import 'package:goatvision/features/history/presentation/history_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> seed({
    required String measurementId,
    String? method,
    double scale = 0.042,
  }) async {
    final now = DateTime(2026, 3, 15, 9);
    await db.into(db.animals).insert(
          AnimalsCompanion.insert(
            id: 'a-$measurementId',
            name: 'Cabra de prueba',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.measurements).insert(
          MeasurementsCompanion.insert(
            id: measurementId,
            animalId: 'a-$measurementId',
            timestamp: now,
            estimatedWeightKg: 41.2,
            lowerWeightKg: 36.5,
            upperWeightKg: 45.9,
            confidence: 0.71,
            modelVersion: 'test',
            datasetVersion: 'test',
            captureId: Value('cap-$measurementId'),
          ),
        );
    await db.into(db.captures).insert(
          CapturesCompanion.insert(
            id: 'cap-$measurementId',
            measurementId: measurementId,
            imagePath: 'img/$measurementId.png',
            viewType: 'side',
            imageWidth: 1280,
            imageHeight: 720,
            calibrationMethod: method ?? '',
            calibrationScale: scale,
            qualityScore: 0.9,
            createdAt: now,
          ),
        );
  }

  Widget buildApp() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistoryScreen()),
      );

  testWidgets(
    'historial muestra método de calibración y escala cm/px de la captura',
    (tester) async {
      await seed(
        measurementId: 'm1',
        method: 'marker',
        scale: 0.0423,
      );
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('ArUco 30 cm · 0.042 cm/px'), findsOneWidget);
    },
  );

  testWidgets(
    'medición sin escala útil (0.0) muestra "Calibración sin escala"',
    (tester) async {
      await seed(measurementId: 'm2', method: 'marker', scale: 0.0);
      await tester.pumpWidget(buildApp()          );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Calibración sin escala'), findsOneWidget);
    },
  );

  testWidgets(
    'captura inexistente para la medición también cae en "sin escala"',
    (tester) async {
      // Medición sin fila de Captures asociada.
      final now = DateTime(2026, 3, 15, 9);
      await db.into(db.animals).insert(
            AnimalsCompanion.insert(
              id: 'a-solo',
              name: 'Cabra sin captura',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.measurements).insert(
            MeasurementsCompanion.insert(
              id: 'm3',
              animalId: 'a-solo',
              timestamp: now,
              estimatedWeightKg: 39.9,
              lowerWeightKg: 34.0,
              upperWeightKg: 45.0,
              confidence: 0.8,
              modelVersion: 'test',
              datasetVersion: 'test',
            ),
                    );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Calibración sin escala'), findsOneWidget);
    },
  );
}
