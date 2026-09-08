# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

## [Unreleased]

## 2026-09-08

### Añadido

**Producto:**
- **Predictor de peso de referencia (literatura)** — Ecuación stepwise de
  Paredes-Chocce et al. (2025): `BW = -45.642 + 0.71·TG + 0.21·RH + 0.99·RW`
  (R²=0.644, RSE=6.305 kg, n=356). Implementado en Dart
  (`ReferenceWeightPredictor`) y Python (`ml/literature/reference_weight.py`).
  TG se estima como perímetro de elipse (Ramanujan) desde profundidad + ancho
  de pecho. Intervalo 80% honesto (RSE publicado, no PICP medido por GoatVision).
- **Escaneo rápido** — Botón "Escanear cabra" en el dashboard; captura sin
  animal previo. Al guardar se auto-registra "Cabra sin registrar · fecha"
  (renombrable) y se persiste la imagen.
- **Unidad kg/lb funcional** — `UnitConverter` aplicado en resultado, historial,
  dashboard y detalle. Preferencia persistida en `AppStorage`.
- **Modo oscuro** — Ajuste Claro/Oscuro/Sistema persistido
  (`themeModeProvider`), conectado a `MaterialApp`.
- **Edición de cabras** — `AddAnimalScreen` con prefill (isEditing), ruta
  `/animals/edit` y botón editar en el detalle.
- **Eliminación de cabras en cascada** — Borra en transacción: captures →
  morphometrics → measurements → animal, y limpia archivos de imagen
  (best-effort). Diálogo de confirmación con conteo de mediciones.
- **Búsqueda en historial** — Campo de filtro por nombre de cabra o peso
  aproximado. Lógica extraída a función pura testeable (`history_filter.dart`).
- **Informe científico** — Modal expandido en Configuración: ecuación completa,
  R²/RSE, método elipse-Ramanujan, rangos de aplicación, DOI copiable y
  advertencias de honestidad.
- **Insignia dev** — "Modo desarrollador · CV simulada" en captura cuando
  `RunMode.mock` está activo.
- **Recolección de dataset (modo dev)** — Campo "Peso real en báscula (kg)"
  en resultados; registra fila JSONL (`dataset_log.jsonl`). Configuración →
  Exportar dataset (CSV) con las 8 columnas de features + `real_weight_kg`.
- **Pipeline `AnalysisPipeline.reference()`** — Peso usa fórmula de referencia;
  CV sigue simulada. `analysisPipelineProvider` la devuelve por defecto.

**Tests:**
- 6 tests de `ReferenceWeight` (numpy puro) → **21 tests ML** totales.
- `history_filter_test` — filtro puro del historial.
- `drift_animal_repository_test` — borrado en cascada con DB en memoria
  (`AppDatabase.forTesting(NativeDatabase.memory())`).
- `settings_screen_test` — informe científico y modal de modelos.
- `dataset_log_format_test` — JSONL/CSV, escaping, cabeceras.
- `unit_converter_test` — conversiones kg/lb.

**CI/CD:**
- `.github/workflows/ci.yml` — En cada push a `main`:
  - **ML (Python):** instala numpy/pandas/sklearn/opencv, ejecuta 21 tests.
  - **Flutter:** build_runner → analyze → test → debug APK subido como artefacto.
  - Comenta el log de fallo en el commit (requiere `contents: write`).
  - Genera archivos `.g.dart`/`.freezed.dart` que están en `.gitignore`.

**Fuentes:**
- Inter TTFs (Regular/Medium/SemiBold/Bold, OFL) + LICENSE en `assets/fonts`.
  Eran referenciados por el tema pero no existían → el build nunca podía
  completarse.

**Documentación:**
- `docs/ml/integration-mobile.md` — Blueprint exacto para conectar `.tflite`
  reales (contratos, assets, providers, regla de no-mocks).
- `CHANGELOG.md`, `README.md` (badge CI, dataset, tests), `mobile/README.md`
  (funcionalidades).

### Corregido
- **Import latente de `RunMode`** — settings, capture y results usaban
  `RunMode` sin importarlo; `providers.dart` ahora lo reexporta.
- **`Positioned` inválido** en controles de captura — `QualityIndicator` es
  hijo estirado (antes dentro de `Column`, que requiere `Stack`).
- **Toggle de idioma muerto** eliminado (app es es-MX hardcodeada).
- Import sin uso (`app_exceptions`), provider muerto (`onboardingSeenProvider`).
- **Balance de llaves** verificado en todos los archivos editados.

### Pendiente (requiere host con Flutter)
- **CI en espera** — Los 2 jobs (ML + Flutter) fallan en GitHub Actions:
  - ML: 1 de los 21 tests falla con pandas/sklearn/opencv instalados (no se
    puede reproducir en Termux). Log posteado como comentario del commit.
  - Flutter pub get: posible conflicto de resolución de dependencias con el
    Dart SDK estable (2026). Log posteado como comentario del commit.
- **Verificación completa** — `flutter analyze`, `flutter test`, `flutter build
  apk` solo se validan en un host real con el SDK de Flutter.
- **Tests de integración de TFLite** — Requieren modelo `.tflite` y dispositivo.

## [Interno / no versionado]

Hitos del desarrollo previo al commit inicial (2026-09-07):

- Pipeline ML E2E (30 animales → 145 capturas), splits por animal 70/15/15 sin
  leakage, columnas de features cotejadas entre Dart y Python (8/8).
- Flujo móvil capture → analysis → result con guardado en transacción
  (medición + morfometría + captura); ajustes persistidos (unidad/idioma);
  eliminación de providers muertos; README de integración en máquina real.
- Auditoría: obtención y extracción del paper clave de referencia
  (Biodiversitas, DOI 10.13057/biodiv/d260710).
