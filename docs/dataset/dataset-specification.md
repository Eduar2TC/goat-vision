# Especificación del dataset

## Objetivo

300–500 animales (meta inicial), después 1000+.
Prioridad: diversidad de razas, edades, sexos, tamaños, condición corporal,
fondos, iluminación, teléfonos, distancias y poses.
Si el mercado es México, priorizar cabras mexicanas.

## Metadata por captura

| Campo              | Tipo    |
|--------------------|---------|
| animalId           | string  |
| breed              | string  |
| sex                | string  |
| ageMonths          | int     |
| region             | string  |
| realWeightKg       | float   | ← ground truth de báscula
| bcs                | float   | (opcional, escala 1–5)
| camera             | string  |
| captureDate        | date    |
| lighting           | string  |
| environment        | string  |
| view               | string  | side / rear
| distance           | string  |
| imageWidth/Height  | int     |
| medidas cm         | float   | bodyLength, withersHeight, rumpHeight, chestDepth, chestWidth, rumpWidth, rumpLength, pawHeight

## Ground truth

El peso real debe medirse con báscula al momento (o muy cerca) de la captura.
Guardar imagen, predicción y peso real para cálculo de error.

## Splits (por animal)

```
70%  training
15%  validation
15%  testing
```

Nunca dividir aleatoriamente fotografías del mismo animal entre train y test.

## Augmentación

Aplicable a modelos CV: rotación, crop, brillo, contraste, blur, ruido,
escala, perspectiva, variación de fondo.

**Prohibido** deformar artificialmente las proporciones anatómicas
(no afectar las medidas reales).

## Estructura en disco

```
ml/dataset/
├── raw/<animal_id>/<capture_id>.jpg
├── annotations/<capture_id>.json
├── metadata/animals.json
├── features.csv
└── splits/{train,validation,test}.txt
```

Ver formato de anotaciones en `ml/annotations/spec.md`.