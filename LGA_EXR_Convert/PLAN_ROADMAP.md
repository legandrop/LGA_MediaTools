# LGA EXR Convert - Plan y Roadmap

## Objetivo

Crear una tool Python para convertir secuencias EXR a DWAA mucho mas rapido que las tools actuales basadas en `.bat` + PowerShell.

La herramienta final deberia cubrir:

- conversion EXR -> EXR DWAA;
- procesamiento de secuencias largas;
- uso eficiente de CPU/cores;
- resize opcional;
- conversion de color opcional via OCIO;
- preservacion de metadata sin modificarla, salvo atributos que necesariamente cambian por la conversion, como `compression` y nivel DWA;
- reportes claros de tiempo, fps, errores y diferencias de metadata.

## Contexto Actual

Las tools existentes que convierten a DWAA usan OIIO / `oiiotool.exe`:

- `EXR_to_DWAA`
- `EXR_to_DWAA_input`
- `DPX_to_EXR_DWAA`
- `EXRmCh_to_PXR24+DWAA`

El problema principal observado es que son muy lentas. La hipotesis inicial es que el flujo actual procesa frame por frame de forma secuencial desde PowerShell, llamando a `oiiotool` con `Start-Process -Wait` para cada archivo. Aunque `oiiotool` puede usar threads internamente, eso no necesariamente paraleliza la secuencia completa.

## Hallazgos Iniciales

- `oiiotool` soporta opciones de threading como `--threads`.
- Versiones modernas de OpenImageIO incluyen procesamiento de secuencias con `--frames` y paralelismo entre frames con `--parallel-frames`.
- OpenEXR soporta lectura/escritura multithreaded a nivel libreria.
- DWAA es una compresion lossy; no conserva pixeles exactos, pero si deberia permitir conservar metadata del EXR.
- OpenColorIO puede correr transformaciones en CPU o GPU, pero la GPU ayuda principalmente a la transformacion de color. La escritura/compresion DWAA sigue siendo un cuello de botella de CPU/I/O.
- La API Python de OpenEXR es util para inspeccion y operaciones simples, pero no parece el mejor camino para conversion masiva de alto rendimiento.
- `exrmetrics`, si esta disponible, puede servir para benchmarkear lectura, escritura, compresion, threads y conversion.

## Metodos a Benchmarkear

Los benchmarks iniciales se haran primero sobre los primeros 10 frames de:

`T:\VFX-TEST\ERSO_000_310_FgPlate_v02`

Metodos propuestos:

1. Baseline equivalente a la tool actual:
   - `oiiotool` por frame, secuencial.

2. Python orquestando `oiiotool` en paralelo:
   - `ProcessPoolExecutor`;
   - cantidad de workers configurable: 2, 4, 8, cores disponibles;
   - medir punto optimo entre CPU, disco y overhead de procesos.

3. `oiiotool` con secuencia completa:
   - probar `--frames`;
   - probar `--parallel-frames`;
   - validar si el patron de nombres de la secuencia encaja bien.

4. Python con bindings de OpenImageIO:
   - leer EXR;
   - copiar `ImageSpec` y atributos;
   - aplicar compresion DWAA;
   - probar resize y OCIO si el binding local lo permite.

5. `exrmetrics` / herramientas OpenEXR:
   - solo si el binario esta disponible;
   - usarlo como benchmark tecnico de compresion, threads y conversion.

6. OCIO:
   - `oiiotool --colorconvert`;
   - comparar costo con/sin conversion de color;
   - evaluar GPU solo si la transformacion de color demuestra ser el cuello principal.

## Resize

Muchas conversiones tambien necesitan resize. Los benchmarks deberian contemplar:

- conversion sin resize;
- resize simple a una resolucion fija;
- orden de operaciones:
  - resize antes de compresion;
  - color convert antes/despues de resize, segun convenga para calidad y performance;
- impacto del resize en metadata y atributos de resolucion/data window/display window.

Estado actual: resize queda para la segunda etapa. Primero se decide el mejor metodo de conversion sin resize y despues se mide el costo real de agregar resize.

## Preservacion de Metadata

Cada metodo candidato debe compararse contra el input usando:

- `iinfo -v`;
- `exrheader`, si aplica;
- comparacion automatizada de atributos.

Las diferencias deben clasificarse como:

- esperadas: `compression`, atributos DWA, dimensiones si hay resize;
- esperadas si hay OCIO: atributos de color/config si se decide escribirlos;
- no deseadas: perdida, renombrado o modificacion accidental de metadata original.

## Criterios de Decision

Para elegir el enfoque final:

- velocidad total;
- fps reales;
- estabilidad en secuencias largas;
- preservacion de metadata;
- soporte para resize;
- soporte opcional para OCIO;
- manejo claro de errores;
- facilidad de empaquetar dentro de esta repo;
- dependencia minima de instalaciones externas.

## Estructura del Proyecto

```text
LGA_EXR_Convert/
  PLAN_ROADMAP.md
  LGA_EXR_Convert.py
  +building_blocks/
    ...
```

`+building_blocks` contiene scripts de exploracion, testeo y benchmark. Esos scripts pueden ser descartables o evolucionar, pero no son la tool final.

`LGA_EXR_Convert.py` se creara despues de decidir el metodo ganador.

## Roadmap

1. Crear estructura inicial y documentacion.
2. Crear script de benchmark para primeros 10 frames.
3. Implementar baseline secuencial con `oiiotool`.
4. Implementar benchmark paralelo con Python + `oiiotool`.
5. Probar `oiiotool --frames` / `--parallel-frames`.
6. Probar alternativas con bindings Python si estan disponibles.
7. Agregar validacion automatizada de metadata.
8. Agregar caso con resize.
9. Agregar caso con OCIO.
10. Comparar resultados y elegir arquitectura.
11. Implementar `LGA_EXR_Convert.py` final.

## Estado de Benchmarks

- Descartados para performance: `oiiotool` secuencial, `exrmetrics` secuencial y `oiiotool --frames` single-process.
- Mejor enfoque actual sin resize: Python orquestando `oiiotool` en paralelo por frame.
- Default inicial recomendado: `6 workers`, configurable por usuario.
- Resize probado con el enfoque paralelo:
  - `3840x2160`: correcto, metadata OK, mas lento por procesar casi resolucion completa.
  - `1920x1080`: correcto, metadata OK, mas rapido por menor salida.
- Resize con mas workers:
  - `3840x2160`: mejor resultado observado con `12 workers`.
  - `1920x1080`: mejor resultado observado con `8 workers`, practicamente empatado con `12 workers`.
- Defaults tentativos:
  - sin resize: `6 workers`;
  - con resize: `8 workers`;
  - siempre configurable.
- Siguiente etapa: decidir si probar filtros de resize/calidad o pasar a implementar la tool final inicial.

## Investigacion Externa - Metodos Pendientes

- OIIO >= 2.5.1 agrega `oiiotool --parallel-frames`; la version local 2.4.11 no lo tiene. Candidato real para probar si se actualiza OIIO.
- OpenEXR `exrmetrics` moderno soporta `-m` y `-t n` para multithreading/thread pool; la version local no expone esas opciones. Candidato secundario para recompression pura, sin resize/OCIO.
- RVIO puede convertir secuencias desde linea de comando. Queda como candidato de baja prioridad porque no esta incluido en este repo y habria que validar DWAA + metadata.
- Nuke CLI permite control fuerte de metadata y DWAA, pero no parece buen objetivo para esta tool portable por dependencia/licencia y overhead.
- FFmpeg no es buen candidato para DWAA EXR: el soporte DWA/DWAA es limitado/no recomendado para este flujo.
- GPU/OCIO puede servir para acelerar color transforms, pero no elimina el cuello de encode DWAA, que sigue siendo CPU/I/O.

## Tools Instaladas Para Nuevas Pruebas

- `Tools/conda_exrtools`: entorno local con OpenEXR 3.4.11, OpenImageIO 2.5.18 y `py-openimageio`.
- OpenEXR 3.4.11 verificado:
  - `exrmetrics.exe --version` OK.
  - `exrmetrics.exe --help` incluye `-m`, `-t n` y `--convert`.
  - prueba real de conversion a DWAA OK.
- OpenImageIO 2.5.18 verificado via Python:
  - `import OpenImageIO as oiio` OK.
  - lectura de EXR de prueba OK.
  - limitacion: conda-forge Windows no instala `oiiotool.exe`, solo libreria/bindings.
- `Tools/OpenImageIO_pitvfx`: prebuilt Windows probado; funciona pero es OIIO 2.4.11.1, no sirve para `--parallel-frames`.

## Estado Despues De Probar Tools Nuevas

- Nuevo ganador para recompress puro sin resize: OpenEXR `exrmetrics` 3.4.11.
- Comando base ganador:
  - `exrmetrics --convert -m -t 6 -z dwaa -l 60 input.exr -o output.exr`
- Orquestado desde Python con `6 workers`, cada proceso usando `-t 6`.
- Resultado en secuencia completa de prueba:
  - `181` frames en `10.494s`
  - `17.25 fps`
  - metadata OK
  - output/input size ratio `0.249`
- Python + `oiiotool` paralelo sigue siendo necesario para resize y probablemente para OCIO.
- OIIO 2.5.18 via Python bindings probado y descartado por performance.
