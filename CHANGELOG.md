# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

## [Unreleased]

## 2026-09-08

### Añadido
- **CI/CD** — `.github/workflows/ci.yml`: suite ML (21 tests) + Flutter
  (build_runner → analyze → test → APK debug subido como artefacto) en cada
  push a `main`. Instala Android SDK, Java 17, SQLite nativo para los tests
  drift y desinstala la suposición "aquí no compila".
- **Recolección de dataset (modo dev)** — campo opcional "Peso real en
  báscula (kg)" en la pantalla de resultados; al guardar, `DatasetLogService`
  registra una fila (features + objetivo) en `dataset_log.jsonl`.
  Configuración → **Exportar dataset (CSV)** genera `dataset.csv` con las
  8 columnas de `FEATURE_COLUMNS` + metadatos (`real_weight_kg` = objetivo).
- **Tests Dart nuevos** — `history_filter_test` (filtro puro extraído),
  `drift_animal_repository_test` (borrado en cascada con DB en memoria vía
  `AppDatabase.forTesting`), `settings_screen_test` (informe científico y
  modal de modelos), `dataset_log_format_test` (JSONL/CSV y escaping).
- **Scaffold de integración TFLite documentado** — `docs/ml/integration-mobile.md`
  define el contrato assets ↔ interfaces, cableado de providers, calibración
  real y la regla de "no mocks en RunMode.real".
- **Fuentes Inter** — los 4 TTFs (Regular/Medium/SemiBold/Bold, OFL) + LICENSE
  en `assets/fonts`: eran referenciados por el tema y el pubspec pero no
  existían, así que `flutter build` no podía completarse en ninguna máquina.

### Corregido
- **Import latente de `RunMode`** — `settings`, `capture` y `results` usaban
  `RunMode` sin importarlo; ahora `providers.dart` lo reexporta
  (`export ... show AnalysisPipeline, RunMode`). Sin esto, `flutter analyze`
  habría fallado en CI.

### Documentado
- `README.md` — badge CI, recolección de datos, pipeline CI.
- `mobile/README.md` — sección de funcionalidades (escaneo rápido, cabras,
  historial/búsqueda, ajustes e informe científico).
- `docs/ml/integration-mobile.md` — nuevo (ver arriba).

### Añadido
- **Predictor de peso de referencia (literatura)** — `ReferenceWeightPredictor`
  (Dart) + `ml/literature/reference_weight.py` (numpy puro): ecuación stepwise
  de Paredes-Chocce et al. (2025), `BW = -45.642 + 0.71·TG + 0.21·RH + 0.99·RW`
  (R²=0.644, RSE=6.305 kg, n=356). El perímetro torácico (TG) se estima como
  perímetro de elipse (Ramanujan) desde profundidad y ancho de pecho, porque
  no se mide en vista lateral. Intervalo 80% honesto (RSE publicado), no un
  PICP medido. `capture`/`analysis` ya predicen pesos reales (antes mock).
- **Escaneo rápido** — Botón "Escanear cabra" en el dashboard; la captura no
  requiere animal previo. Al guardar sin cabra seleccionada se auto-registra
  "Cabra sin registrar · fecha" (renombrable luego) y se persiste la imagen.
- **Unidad kg/lb funcional** — `UnitConverter` aplicado en resultado,
  historial, dashboard y detalle. Preferencia persistida en `AppStorage`.
- **Modo oscuro** — Ajuste Claro/Oscuro/Sistema persistido
  (`themeModeProvider`), conectado a `MaterialApp` (antes hardcodeado a claro).
- **Edición de cabras** — `AddAnimalScreen` soporta edición (prefill,
  conserva id/`createdAt`); ruta `/animals/edit` y botón editar en el detalle.
- **Eliminación de cabras en cascada** — borra mediciones + medidas +
  capturas + archivos de imagen en una transacción, con diálogo de
  confirmación indicando cuántas mediciones se eliminarán.
- **Búsqueda en historial** — campo de texto que filtra por nombre de cabra
  o peso aproximado; cada entrada navega al detalle de su cabra.
- **Informe científico** en Configuración — ecuación completa, métricas,
  rango de aplicación, cita y DOI copiables, y advertencias de incertidumbre.
- `AnalysisPipeline.reference()` — la etapa de peso del pipeline usa la
  fórmula de referencia (CV simulada); `analysisPipelineProvider` la devuelve.
- Tests: 6 nuevos de `ReferenceWeight` (numpy puro) → **21 tests ML**;
  tests Dart de `UnitConverter` y del predictor de referencia.
- Insignia "Modo desarrollador · CV simulada" en captura cuando `RunMode.mock`
  está activo (transparencia: la CV no es producción).

### Corregido
- **`Positioned` inválido** dentro de un `Column` en los controles de captura
  (solo es válido en un `Stack`): habría lanzado assert en debug/widget tests.
  `QualityIndicator` ahora es un hijo estirado.
- **Toggle de idioma muerto** eliminado: la app es es-MX (locale hardcodeado) y
  la preferencia no se consumía; se quitó `preferredLanguage` para no vender
  una función inexistente.
- Import sin uso (`app_exceptions`) en `analysis_pipeline.dart`.
- "Rehacer" en resultados ahora conserva la cabra seleccionada.
- `gitignore` raíz y eliminación del provider muerto `onboardingSeenProvider`
  (dentro del commit inicial).

### Documentado
- `README.md` — uso sin herramientas, ajustes, historial/búsqueda, informe
  científico, conteo de tests ML (21).
- `docs/research/research-notes.md` — ecuación de referencia completa con
  estadísticas descriptivas, método elipse-Ramanujan y advertencias.
- `mobile/README.md` — predictor de referencia vs CV simulada.
- Este archivo.

## [Interno / no versionado]

Hitos del desarrollo previo al commit inicial (2026-09-07):

- Pipeline ML E2E (30 animales → 145 capturas), splits por animal 70/15/15 sin
  leakage, columnas de features cotejadas entre Dart y Python (8/8).
- Flujo móvil capture → analysis → result con guardado en transacción
  (medición + morfometría + captura); ajustes persistidos (unidad/idioma);
  eliminación de providers muertos; README de integración en máquina real.
- Auditoría: obtención y extracción del paper clave de referencia
  (Biodiversitas, DOI 10.13057/biodiv/d260710).