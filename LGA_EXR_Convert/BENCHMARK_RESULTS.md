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

## Run 02 - Primeros 100 Frames

- Fecha: `2026-05-04_22-22-09`
- Frames: `1001-1100`
- Resize: no
- OCIO/color conversion: no
- CPU logica reportada por Python: `32`
- Raw output: `LGA_EXR_Convert/+building_blocks/_benchmark_output/2026-05-04_22-22-09/`
- Nota: se agregaron retries al validador de metadata porque `iinfo -v` tuvo timeouts espurios en la corrida anterior, sin diferencias reales de metadata.

| Method | Workers | Seconds | FPS | OK | Output/Input Size | Metadata unexpected diffs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `oiiotool_sequential` | - | 17.613 | 5.68 | 100/100 | 0.295 | 0 |
| `oiiotool_parallel_4w` | 4 | 7.124 | 14.04 | 100/100 | 0.295 | 0 |
| `oiiotool_parallel_8w` | 8 | 6.506 | 15.37 | 100/100 | 0.295 | 0 |
| `oiiotool_parallel_12w` | 12 | 6.755 | 14.80 | 100/100 | 0.295 | 0 |
| `oiiotool_parallel_16w` | 16 | 7.025 | 14.24 | 100/100 | 0.295 | 0 |
| `oiiotool_parallel_24w` | 24 | 6.741 | 14.84 | 100/100 | 0.295 | 0 |
| `exrmetrics_sequential` | - | 63.017 | 1.59 | 100/100 | 0.249 | 0 |
| `oiiotool_frames_single_process` | - | 13.127 | 7.62 | 100/100 | 0.295 | 0 |

## Observaciones Run 02

- `8 workers` es el mejor resultado claro en 100 frames: `15.37 fps`.
- Subir a `12`, `16` o `24` workers no mejora; parece que se satura CPU/I/O alrededor de `8 workers`.
- Contra el baseline secuencial, `8 workers` mejora de `17.613s` a `6.506s`, aprox. `2.7x`.
- `oiiotool --frames` sigue funcionando, pero no compite con el paralelo desde Python en esta version instalada.
- `exrmetrics` comprime mas chico (`0.249` vs `0.295`), pero es demasiado lento para este objetivo.
- Todas las variantes preservaron metadata segun `iinfo -v`, ignorando solo diferencias esperadas de compresion/DWA.

## Metodos Descartados Para Siguientes Benchmarks

Estos metodos quedan descartados para performance y no se siguen probando salvo que aparezca una razon nueva:

- `oiiotool_sequential`: demasiado lento contra paralelismo por frame.
- `exrmetrics_sequential`: preserva metadata y comprime mas chico, pero es muy lento.
- `oiiotool_frames_single_process`: funciona, pero no compite con Python + `oiiotool` paralelo en esta version de OIIO.

## Estado

Mejor candidato actual: Python orquestando `oiiotool` en paralelo por frame con default inicial de `8 workers`.

Proximo paso sugerido: probar la secuencia completa con `8 workers` y quizas `6/10 workers` para afinar el default. Despues de eso, pasar a benchmarks con resize.

## Run 03 - Secuencia Completa Sin Resize

- Fecha: `2026-05-04_22-30-32`
- Frames: `181`
- Resize: no
- OCIO/color conversion: no
- Modo: `--parallel-only`
- Raw output: `LGA_EXR_Convert/+building_blocks/_benchmark_output/2026-05-04_22-30-32/`

| Method | Workers | Seconds | FPS | OK | Output/Input Size | Metadata unexpected diffs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `oiiotool_parallel_6w` | 6 | 11.692 | 15.48 | 181/181 | 0.295 | 0 |
| `oiiotool_parallel_8w` | 8 | 11.790 | 15.35 | 181/181 | 0.295 | 0 |
| `oiiotool_parallel_10w` | 10 | 11.904 | 15.21 | 181/181 | 0.295 | 0 |

## Observaciones Run 03

- En la secuencia completa, `6 workers` fue apenas el mejor: `15.48 fps`.
- La diferencia entre `6`, `8` y `10` es chica; el sistema parece saturar alrededor de `6-8 workers`.
- `6 workers` parece mejor default conservador: mantiene maximo rendimiento y deja mas margen al sistema/disco.
- La metadata sigue OK en los 181 frames segun `iinfo -v`.

## Estado Actual

Mejor candidato actual: Python orquestando `oiiotool` en paralelo por frame con default inicial de `6 workers` y opcion configurable.

Proximo paso sugerido: empezar benchmarks con resize usando solo el metodo paralelo.

## Resize

Resize queda explicitamente fuera de esta primera etapa. Se benchmarkea despues de elegir los mejores candidatos sin resize.
