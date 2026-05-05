# LGA_EXR_Convert

Tool portable para convertir frames EXR, principalmente a DWAA, con soporte de resize y conversion OCIO.

El script esta pensado para ser llamado desde Hiero/Nuke Studio con un manifest JSON por job. Todas las rutas internas de tools se resuelven relativas a esta carpeta `BUILD`, asi se puede copiar la carpeta completa a otra repo o maquina.

## Estructura

```text
BUILD/
  LGA_EXR_Convert.py
  LGA_EXR_Convert.MD
  Tools/
    OpenEXR/
      exrmetrics.exe
      *.dll
    OIIO/
      oiiotool.exe
      iinfo.exe
      *.dll
    OCIO/
      configs/
```

## Uso Recomendado Desde Hiero

Hiero deberia generar un manifest con todos los frames y llamar una sola vez al converter:

```powershell
python LGA_EXR_Convert.py --manifest job.json --log-json result.json
```

Cada task debe tener el path de entrada y el path final de salida. Si tu herramienta renombra, conviene enviar directamente `src` y `dst` final por frame, evitando convertir primero y renombrar despues.

## Manifest JSON

```json
{
  "compression": "dwaa",
  "dwa_level": 60,
  "workers": 6,
  "overwrite": true,
  "resize": {
    "width": 3840,
    "height": 2160,
    "filter": "lanczos3"
  },
  "ocio": {
    "config": "T:/show/config.ocio",
    "src_colorspace": "ACEScg",
    "dst_colorspace": "Output - Rec.709"
  },
  "tasks": [
    {
      "src": "T:/in/plate_1001.exr",
      "dst": "D:/out/SHOT_v003_1001.exr"
    },
    {
      "src": "T:/in/plate_1002.exr",
      "dst": "D:/out/SHOT_v003_1002.exr"
    }
  ]
}
```

`resize` y `ocio` pueden ser `null` o estar ausentes.

Si `src` o `dst` son relativos, se resuelven relativos a la carpeta donde esta el manifest. Si `ocio.config` es relativo, se resuelve relativo a la carpeta `BUILD`.

## Uso Manual

Un frame sin resize ni OCIO:

```powershell
python LGA_EXR_Convert.py --input input.exr --output output.exr --overwrite
```

Un frame con resize:

```powershell
python LGA_EXR_Convert.py --input input.exr --output output.exr --resize 3840x2160 --resize-filter lanczos3 --overwrite
```

Un frame con OCIO:

```powershell
python LGA_EXR_Convert.py --input input.exr --output output.exr --ocio-config T:/show/config.ocio --ocio-src ACEScg --ocio-dst "Output - Rec.709" --overwrite
```

## Selector Interno De Tool

El modo default es `--engine auto`.

- Sin resize y sin OCIO: usa OpenEXR `exrmetrics`.
- Con resize: usa `oiiotool`.
- Con OCIO: usa `oiiotool`.
- Con resize + OCIO: usa `oiiotool`.

Motivo: en los benchmarks, `exrmetrics` fue mas rapido para recompress puro EXR -> DWAA, pero no cubre resize ni OCIO. Para transformaciones de imagen, el camino final es `oiiotool` paralelo por frame.

## Parametros Importantes

- `--manifest`: manifest JSON del job.
- `--input` / `--output`: modo manual de un frame.
- `--compression`: default `dwaa`.
- `--dwa-level`: default `60`.
- `--resize`: geometria OIIO, por ejemplo `3840x2160`.
- `--resize-filter`: filtro OIIO, por ejemplo `lanczos3`.
- `--ocio-config`: ruta a `config.ocio`.
- `--ocio-src`: colorspace de entrada.
- `--ocio-dst`: colorspace de salida.
- `--workers`: procesos/frames paralelos, default `6`.
- `--exrmetrics-threads`: threads por proceso de `exrmetrics`, default `6`.
- `--engine`: `auto`, `exrmetrics` u `oiiotool`.
- `--overwrite`: permite pisar outputs existentes.
- `--dry-run`: devuelve comandos planeados sin convertir.
- `--log-json`: escribe el reporte completo a archivo.

## Salida

El script imprime un JSON a stdout. Si se pasa `--log-json`, escribe el mismo reporte en disco.

Exit codes:

- `0`: todos los frames OK.
- `1`: error de configuracion o manifest invalido.
- `2`: uno o mas frames fallaron.

## Metadata

Los benchmarks validaron metadata con `iinfo -v`.

- `exrmetrics --convert` preservo metadata en recompress puro.
- `oiiotool` se ejecuta con `--nosoftwareattrib` para evitar agregar historial de software.
- Cambios esperados: compresion/DWA y dimensiones/ventanas cuando hay resize.

## Notas De Portabilidad

- No depende de tools instaladas globalmente ni del `PATH` del sistema.
- `config.ocio` puede estar dentro de `Tools/OCIO/configs` o venir desde una ruta externa del proyecto.
- En manifest, los paths relativos de frames son relativos al manifest; el path relativo de `ocio.config` es relativo a `BUILD`.
- Para copiar a otra repo, copiar la carpeta `BUILD` completa.
