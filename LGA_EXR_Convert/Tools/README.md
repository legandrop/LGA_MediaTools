# Tools

Herramientas descargadas/preparadas para evaluar alternativas al pipeline actual.

## OpenEXR 3.4.11

Instalado via conda-forge en:

`LGA_EXR_Convert/Tools/conda_exrtools/`

Ejecutables verificados:

- `Library/bin/exrmetrics.exe`
- `Library/bin/exrheader.exe`

Verificacion:

- `exrmetrics --version` devuelve `OpenEXR 3.4.11`.
- `exrmetrics --help` muestra opciones modernas `-m`, `-t n` y `--convert`.
- Prueba real OK: conversion de un frame a DWAA con `--convert -m -t 6 -z dwaa -l 60`.

## OpenImageIO 2.5.18

Instalado via conda-forge en el mismo entorno:

`LGA_EXR_Convert/Tools/conda_exrtools/`

Estado:

- La libreria OpenImageIO 2.5.18 esta instalada.
- Los bindings Python `py-openimageio` funcionan.
- Verificacion OK: `import OpenImageIO as oiio`, lectura de un EXR de prueba y metadata basica.
- Limitacion: el paquete conda-forge `openimageio` para Windows no incluye `oiiotool.exe`.

Esto permite probar una implementacion Python directa con OIIO 2.5.18, pero no permite probar `oiiotool --parallel-frames` por CLI desde este paquete.

## OpenImageIO pitvfx prebuilt

Tambien se probo el prebuilt Windows de pitvfx:

`LGA_EXR_Convert/Tools/OpenImageIO_pitvfx/`

Estado:

- Incluye `oiiotool.exe`.
- Funciona, pero reporta `OpenImageIO 2.4.11.1`, igual que la version ya incluida en el repo.
- No incluye `--parallel-frames`.
- Queda descartado como candidato nuevo.

## Temp

`LGA_EXR_Convert/Tools/temp/` se usa para zips, extracciones y outputs chicos de prueba. Esta ignorado por Git.
