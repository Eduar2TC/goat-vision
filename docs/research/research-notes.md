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