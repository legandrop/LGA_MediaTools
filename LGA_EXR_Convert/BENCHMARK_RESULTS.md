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

Resize se empezo a benchmarkear despues de descartar los metodos lentos y elegir el camino paralelo.

## Run 04 - Resize 3840x2160, Primeros 100 Frames

- Fecha: `2026-05-04_22-42-41`
- Frames: `1001-1100`
- Resize: `3840x2160`
- OCIO/color conversion: no
- Workers: `6`
- Raw output: `LGA_EXR_Convert/+building_blocks/_benchmark_output/2026-05-04_22-42-41/`
- Validacion: output confirmado con `iinfo` como `3840 x 2160, 3 channel, half openexr`

| Method | Workers | Seconds | FPS | OK | Output/Input Size | Metadata unexpected diffs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `oiiotool_parallel_6w_resize_3840x2160` | 6 | 14.306 | 6.99 | 100/100 | 0.290 | 0 |

## Run 05 - Resize 1920x1080, Primeros 100 Frames

- Fecha: `2026-05-04_22-43-20`
- Frames: `1001-1100`
- Resize: `1920x1080`
- OCIO/color conversion: no
- Workers: `6`
- Raw output: `LGA_EXR_Convert/+building_blocks/_benchmark_output/2026-05-04_22-43-20/`
- Validacion: output confirmado con `iinfo` como `1920 x 1080, 3 channel, half openexr`

| Method | Workers | Seconds | FPS | OK | Output/Input Size | Metadata unexpected diffs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `oiiotool_parallel_6w_resize_1920x1080` | 6 | 9.626 | 10.39 | 100/100 | 0.092 | 0 |

## Observaciones Resize

- Resize cambia mucho el costo: sin resize la secuencia completa dio ~`15.48 fps`; con resize a `3840x2160` baja a `6.99 fps`.
- Downscale a `1920x1080` es mas rapido que `3840x2160`, probablemente por menor escritura/compresion final, aunque igual agrega costo de resampling.
- La metadata se mantiene OK segun `iinfo -v`; se ignoran solo cambios esperados de compresion/DWA y ventanas de imagen por resize.
- `3840x2160` es un caso importante para normalizar el ancho raro `3841`, pero es caro porque sigue procesando casi toda la resolucion original.

## Estado Resize

Mejor candidato con resize sigue siendo Python + `oiiotool` paralelo.

## Run 06 - Resize 3840x2160, Workers Comparison

- Fecha: `2026-05-04_22-46-26`
- Frames: `1001-1100`
- Resize: `3840x2160`
- OCIO/color conversion: no
- Raw output: `LGA_EXR_Convert/+building_blocks/_benchmark_output/2026-05-04_22-46-26/`

| Method | Workers | Seconds | FPS | OK | Output/Input Size | Metadata unexpected diffs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `oiiotool_parallel_4w_resize_3840x2160` | 4 | 15.483 | 6.46 | 100/100 | 0.290 | 0 |
| `oiiotool_parallel_6w_resize_3840x2160` | 6 | 14.783 | 6.76 | 100/100 | 0.290 | 0 |
| `oiiotool_parallel_8w_resize_3840x2160` | 8 | 14.529 | 6.88 | 100/100 | 0.290 | 0 |
| `oiiotool_parallel_10w_resize_3840x2160` | 10 | 14.487 | 6.90 | 100/100 | 0.290 | 0 |
| `oiiotool_parallel_12w_resize_3840x2160` | 12 | 14.260 | 7.01 | 100/100 | 0.290 | 0 |

## Run 07 - Resize 1920x1080, Workers Comparison

- Fecha: `2026-05-04_22-48-26`
- Frames: `1001-1100`
- Resize: `1920x1080`
- OCIO/color conversion: no
- Raw output: `LGA_EXR_Convert/+building_blocks/_benchmark_output/2026-05-04_22-48-26/`

| Method | Workers | Seconds | FPS | OK | Output/Input Size | Metadata unexpected diffs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `oiiotool_parallel_4w_resize_1920x1080` | 4 | 10.796 | 9.26 | 100/100 | 0.092 | 0 |
| `oiiotool_parallel_6w_resize_1920x1080` | 6 | 10.052 | 9.95 | 100/100 | 0.092 | 0 |
| `oiiotool_parallel_8w_resize_1920x1080` | 8 | 9.925 | 10.08 | 100/100 | 0.092 | 0 |
| `oiiotool_parallel_10w_resize_1920x1080` | 10 | 10.017 | 9.98 | 100/100 | 0.092 | 0 |
| `oiiotool_parallel_12w_resize_1920x1080` | 12 | 9.934 | 10.07 | 100/100 | 0.092 | 0 |

## Observaciones Workers Con Resize

- Con resize, mas workers ayudan mas que en el caso sin resize, pero la curva sigue bastante plana.
- Para `3840x2160`, `12 workers` fue mejor (`7.01 fps`), con una mejora moderada contra `6 workers` (`6.76 fps`).
- Para `1920x1080`, `8 workers` fue apenas mejor (`10.08 fps`), practicamente empatado con `12 workers` (`10.07 fps`).
- Todos los casos preservaron metadata segun `iinfo -v`.
- Recomendacion: default general `6 workers` sin resize; para resize, permitir override y considerar default `8 workers`.
