# GoatVision — Aplicación móvil

App Android (Flutter) para estimar el peso vivo de cabras mediante visión
artificial, 100% offline. Documentación general en el [README raíz](../README.md).

## Arquitectura

```
lib/
├── app/            # MaterialApp, routing (go_router)
├── core/           # cámara, ml (interfaces + mocks), calibración, almacenamiento, tema
├── data/           # providers (Riverpod), DB Drift/SQLite, repositorios
├── domain/         # entidades, casos de uso, interfaces de repositorios
└── features/       # onboarding, capture, analysis, results, animals, history, settings
```

- **Estado:** Riverpod
- **Navegación:** go_router
- **Persistencia:** Drift/SQLite
- **ML:** TFLite (offline). Los modelos `.tflite` aún no están integrados:
  - La CV (detección/segmentación/landmarks) corre con mocks de desarrollo en
    `lib/core/ml/mock_ml_services.dart`.
  - El peso real usa la fórmula de referencia de Paredes-Chocce et al. (2025)
    en `reference_weight_predictor.dart` (r²=0.644, RSE 6.305 kg); un modelo
    TFLite propio la sustituirá cuando se integre.

## Flujo de captura

```
capture → analysis → result → Guardar
```

La imagen se persiste en el momento de la captura; al pulsar **Guardar** en la
pantalla de resultados se persisten medición + medidas biométricas + captura.

## Generación de código

Drift y dependencias generan `*.g.dart` / `*.freezed.dart` (en `.gitignore`,
no versionados). Re-generar en una máquina con el SDK de Flutter:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Tests

```bash
flutter analyze
flutter test
```

> `RunMode.real` lanza `UnimplementedError` a propósito hasta que se integren
> los modelos `.tflite` (ver `lib/data/providers/providers.dart`). Los mocks
> nunca se activan en producción por accidente.