# LGA Media Tools

Este repositorio contiene una colección de herramientas para el procesamiento y conversión de archivos multimedia, especialmente enfocadas en archivos EXR y video. Estas herramientas fueron desarrolladas por Lega Pugliese para facilitar diversas tareas de procesamiento de medios.


## Herramientas disponibles



### EXR_Checker

Verifica la integridad de archivos EXR en una carpeta y sus subcarpetas recursivamente.

- **Versión actual**: v1.3
- **Uso**: Arrastra una carpeta que contenga archivos EXR sobre el archivo EXR_Checker.bat.
- **Funcionalidades**:
  - Recibe una carpeta arrastrada como argumento.
  - Opción para verificar solo carpetas que contengan "input" en su nombre.
  - Llama a un script de PowerShell para procesar los archivos EXR.
  - Usa exrcheck (de OpenEXR) para verificar la integridad de cada archivo EXR.
  - Genera un reporte RTF de archivos corruptos, si los hay.
  - Permite cancelar la operación presionando Ctrl+C en cualquier momento.
- **Requisitos**:
  - OpenEXR (exrcheck), ya incluido en el repositorio.

<br>

### EE_MOV+MXF

Procesa un archivo .MOV para crear versiones MOV y MXF con overlays y textos específicos.

- **Versión actual**: v1.6
- **Uso**: Arrastra un archivo .MOV sobre el archivo EE_MOV+MXF.bat.
- **Funcionalidades**:
  - Verifica la estructura del nombre del archivo de entrada.
  - Busca la carpeta FgPlate y el archivo EditRef más recientes.
  - Compara el número de frames entre el MOV de entrada, la secuencia FgPlate y el EditRef.
  - Crea un thumbnail a partir del primer frame de la secuencia FgPlate.
  - Genera una placa con el thumbnail y textos informativos.
  - Produce un archivo MOV con barras negras semitransparentes 2.35:1, placa inicial y textos.
  - Crea una versión MXF sin las barras 2.35:1.
  - Renombra los archivos de salida según reglas específicas.
- **Requisitos**:
  - FFmpeg, ya incluido en el repositorio.
  - OIIO (oiiotool), ya incluido en el repositorio.
  - OpenColorIO, ya incluido en el repositorio.
  - Estructura de carpetas específica con _input, FgPlate, y EditRef.

<br>

### EXR_to_DWAA

Convierte archivos EXR de cualquier compresión a compresión DWAA.

- **Versión actual**: v1.2
- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXR_to_DWAA.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión.
  - La salida se guarda en una nueva carpeta con la compresión DWAA aplicada.
- **Requisitos**:
  - OIIO (oiiotool), ya incluido en el repositorio.

<br>


### EXR_to_PIZ

Convierte archivos EXR de cualquier compresión a compresión PIZ.

- **Versión actual**: v1.0
- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXR_to_PIZ.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión.
  - La salida se guarda en una nueva carpeta con la compresión PIZ aplicada.
- **Requisitos**:
  - OIIO (oiiotool), ya incluido en el repositorio.

<br>

### EXR_to_PXR24

Convierte archivos EXR de cualquier compresión a compresión PXR24.

- **Versión actual**: v1.1
- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXR_to_PXR24.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión.
  - La salida se guarda en una nueva carpeta con la compresión PXR24 aplicada.
- **Requisitos**:
  - OIIO (oiiotool), ya incluido en el repositorio.

<br>

### EXRmC_to_PXR24

Convierte archivos EXR multicanal a archivos EXR individuales por canal, con compresión Pxr24.

- **Versión actual**: v1.4
- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXRmC_to_PXR24.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión y exrheader para leer los canales.
  - Corrige los nombres de los canales eliminando "FinalImageMovieRenderQueue_" y reemplazando ActorHitProxyMask por CryptoMatte.
  - La salida se guarda en nuevas subcarpetas con los archivos divididos por canal y con la compresión Pxr24 aplicada.
- **Requisitos**:
  - OIIO (oiiotool), ya incluido en el repositorio.
  - OpenEXR (exrheader), ya incluido en el repositorio.

<br>

### EXRmC_to_PXR24+DWAA

Convierte archivos EXR multicanal a archivos EXR individuales por canal, con compresión Pxr24 y DWAA.

- **Versión actual**: v1.3
- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXRmC_to_PXR24+DWAA.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión y exrheader para leer los canales.
  - Corrige los nombres de los canales eliminando "FinalImageMovieRenderQueue_" y reemplazando ActorHitProxyMask por CryptoMatte.
  - El canal RGBA se convierte a DWAA, mientras que los demás canales se convierten a Pxr24.
  - La salida se guarda en nuevas subcarpetas con los archivos divididos por canal y con la compresión correspondiente aplicada.
- **Requisitos**:
  - OIIO (oiiotool), ya incluido en el repositorio.
  - OpenEXR (exrheader), ya incluido en el repositorio.

<br>

### Versioning

Script para versionar archivos antes de realizar cambios.

- **Versión actual**: v1.4
- **Uso**: Arrastra un archivo sobre Versioning.bat.
- **Funcionalidades**:
  - Copia el archivo a la carpeta +OLD.
  - Asigna un nuevo número de versión.
  - Funciona con cualquier tipo de archivo, no solo .py.
- **Requisitos**:
  - No requiere software adicional.

<br>

### Release Generator

Script para generar un archivo zip del proyecto, excluyendo ciertos archivos y carpetas.

- **Versión actual**: v1.0
- **Uso**: Ejecuta +Release_generator.bat.
- **Funcionalidades**:
  - Crea un archivo zip del proyecto LGA_MediaTools.
  - Excluye archivos y carpetas especificados en .exclude.lst.
- **Requisitos**:
  - 7-Zip debe estar instalado en el sistema.

<br><br>

Lega Pugliese | 2024
