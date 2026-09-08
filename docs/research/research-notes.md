# Notas de investigación

## Referencias metodológicas

1. **Gonçalves et al. (2025)** — *Prediction of Weight and Body Condition
   Score of Dairy Goats Using Digital Images*, MDPI Animals.
   Metodología de referencia para el pipeline imagen → variables
   biométricas → ML.

2. **Trillo-Zárate et al.** — *Using biometric analysis to estimate body
   weight in Creole goats.* Justifica estimación de peso por medidas
   corporales en cabras criollas.

3. **Sood et al.** — *Recent advances in computer vision for non-contact
   phenotyping and weight estimation in livestock.* Panorámica de pipelines
   CV modernos y desafíos.

**No copiar modelos de forma ciega:** usar sus metodologías como referencia
y entrenar modelos propios sobre datos propios.

## Modelo de referencia (fallback) — Paredes-Chocce et al. (2025)

Ecuaciones para estimar peso vivo (BW) en cabras criollas peruanas
(n = 356), usadas como predictor de referencia en la app hasta que exista
un modelo entrenado con datos propios:

- **Stepwise** (AIC 928.29, R²aj = 0.644, RSE = 6.305 kg):
  `BW = -45.642 + 0.71·TG + 0.21·RH + 0.99·RW`
- **Alternativo** (R²aj = 0.645):
  `BW = -46.73 + 0.01·CW + 0.71·TG + 0.09·WH + 0.14·RH + 0.96·RW`

donde TG = perímetro torácico, RH = altura de grupa, RW = ancho de grupa,
CW = ancho de pecho, WH = altura de cruz (cm), BW (kg).

Estadísticas descriptivas de referencia:

| Variable | Media ± SD | Rango |
|----------|-----------|-------|
| BW (kg)  | 48.06 ± 10.51 | 23.2–75.0 |
| TG (cm)  | 84.97 ± 7.32  | 65.0–103.0 |
| CW (cm)  | 18.98 ± 2.75  | 12.0–27.0 |
| WH (cm)  | 70.49 ± 6.79  | — |
| RH (cm)  | 72.61 ± 6.57  | 51.0–89.2 |
| RW (cm)  | 17.17 ± 2.82  | 8.7–27.0 |

Referencia: Paredes-Chocce, J. F. et al. (2025). *Predicting body weight
using body measurements in Peruvian creole goats.* Biodiversitas
26(7):3193-3198. DOI 10.13057/biodiv/d260710.

### TG estimado desde medidas laterales

El pipeline de GoatVision mide en vista lateral (medidas lineales), no el
perímetro torácico. `TG` se **estima** como el perímetro de la elipse de la
sección transversal del pecho (aprox. de Ramanujan) con semiejes
`a = chest_depth/2` y `b = chest_width/2`:

```
TG ≈ π[3(a+b) − √((3a+b)(a+3b))]
```

Sanidad: con las medias del paper (CW 18.98, TG 84.97) el ajuste implica
~34 cm de profundidad de pecho, plausible para animales adultos. El rango
de TG 65–103 cm se reproduce con D ∈ [22, 45] cm.

⚠️ **Honestidad:** el intervalo de predicción usa el RSE publicado (R²≈0.64),
no es un PICP medido por GoatVision. Solo un modelo entrenado con datos
propios puede medir su cobertura real.

## Hipótesis principal

> Las características morfométricas obtenidas automáticamente mediante CV
> a partir de imágenes 2D pueden estimar el peso vivo de cabras con un error
> suficientemente bajo para un seguimiento no invasivo práctico.

La hipótesis debe demostrarse con datos reales, nunca con valores simulados.

## Variables biométricas clave

```
body_length, withers_height, rump_height, chest_depth,
chest_width, rump_width, rump_length, paw_height
```

Más: bodyArea, bodyAspectRatio, bodyBoundingWidth, bodyBoundingHeight.

## Calibración

- MVP: marcador físico de 30 cm (ArUco/AprilTag) → `cmPerPixel`.
- Precaución: la perspectiva y la proximidad al animal importan
  (misma profundidad aproximada).
- Futuras: ARCore, Depth, Manual.

## BCS (Body Condition Score)

- Escala 1–5.
- Implementación posterior; requiere dataset propio con BCS anotado.
- No habilitar como funcionalidad crítica sin datos suficientes.

## Dirección futura

- V2: vista trasera + multi-view (side + rear) con fusión de features
  (robustez en chestWidth/rumpWidth).
- V3: RGB + Depth → representación 3D → medidas → ML multimodal
  (RGB + Depth + morfometría + edad + sexo + raza).

## Advertencias

- Los resultados nunca son exactos de báscula.
- Error crece con iluminación pobre y condiciones extremas de cuerpo.
- Reportar dónde funciona peor el modelo.