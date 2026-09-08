import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/features/settings/presentation/settings_screen.dart';

void main() {
  Widget buildApp() {
    return const ProviderScope(
      child: MaterialApp(home: SettingsScreen()),
    );
  }

  testWidgets('settings shows science report with honest caveats',
      (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('Configuración'), findsOneWidget);

    await tester.tap(find.text('Información científica'));
    await tester.pumpAndSettle();

    expect(find.text('Informe científico'), findsOneWidget);
    expect(find.textContaining('Paredes-Chocce'), findsNWidgets(2));
    expect(find.textContaining('BW (kg) = -45.642 + 0.71·TG'), findsOneWidget);
    expect(find.textContaining('R² ajustado = 0.644'), findsOneWidget);
    expect(find.textContaining('10.13057/biodiv/d260710'), findsOneWidget);
    expect(
      find.textContaining('NO son una cobertura (PICP)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('no es un valor de báscula'),
      findsOneWidget,
    );
  });

  testWidgets('models modal lists the reference weight model', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.text('Modelos'));
    await tester.pumpAndSettle();

    expect(find.text('Fórmula (literatura)'), findsOneWidget);
    expect(find.textContaining('R²=0.644 · RSE=6.305 kg'), findsOneWidget);
    expect(find.text('goat_detector.tflite'), findsOneWidget);
  });
}