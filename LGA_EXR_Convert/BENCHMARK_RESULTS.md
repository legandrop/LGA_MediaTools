# Benchmark Results

Benchmarks sin resize para evaluar conversion EXR -> DWAA.

Secuencia de prueba:

`T:\VFX-TEST\ERSO_000_310_FgPlate_v02`

## Run 01 - Primeros 10 Frames

- Fecha: `2026-05-04_22-11-50`
- Frames: `1001-1010`
- Resolucion detectada por `iinfo`: `3841 x 2160`
- Canales: `3`
- Tipo: `half`
- Input compression: `piz`
- Resize: no
- OCIO/color conversion: no
- CPU logica reportada por Python: `32`
- Raw output: `LGA_EXR_Convert/+building_blocks/_benchmark_output/2026-05-04_22-11-50/`

| Method | Workers | Seconds | FPS | OK | Output/Input Size | Metadata unexpected diffs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `oiiotool_sequential` | - | 1.792 | 5.58 | 10/10 | 0.295 | 0 |
| `oiiotool_parallel_2w` | 2 | 1.168 | 8.56 | 10/10 | 0.295 | 0 |
| `oiiotool_parallel_4w` | 4 | 0.902 | 11.08 | 10/10 | 0.295 | 0 |
| `oiiotool_parallel_8w` | 8 | 0.807 | 12.40 | 10/10 | 0.295 | 0 |
| `exrmetrics_sequential` | - | 6.382 | 1.57 | 10/10 | 0.249 | 0 |
| `oiiotool_frames_single_process` | - | 1.508 | 6.63 | 10/10 | 0.295 | 0 |

## Observaciones

- La mejora clara viene de paralelizar por frame desde Python.
- En 10 frames, `8 workers` fue el mas rapido, pero la diferencia contra `4 workers` es chica. Hay que repetir con mas frames antes de asumir que 8 es el punto optimo.
- `oiiotool --frames` funciona con esta secuencia, pero en esta version de OIIO no aparece `--parallel-frames` en el help; el modo single-process quedo por debajo del paralelo Python.
- `exrmetrics` preservo metadata y comprimio mas chico, pero fue mucho mas lento en esta prueba.
- Para evitar modificar metadata con historial de comandos, los tests con `oiiotool` usan `--nosoftwareattrib`.
- La validacion de metadata se hizo con `iinfo -v`. Se consideran diferencias esperadas `compression` y atributos DWA.

## Estado

Mejor candidato inicial: Python orquestando `oiiotool` en paralelo por frame.

Proximo paso sugerido: repetir sobre una muestra mas grande, por ejemplo 50 o 100 frames, con workers `4`, `8`, `12`, `16` y quizas `24`, para encontrar el punto real de saturacion CPU/disco.

## Resize

Resize queda explicitamente fuera de esta primera etapa. Se benchmarkea despues de elegir los mejores candidatos sin resize.
