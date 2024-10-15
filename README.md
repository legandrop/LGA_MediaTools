# LGA Media Tools

Este repositorio contiene una colección de herramientas para el procesamiento y conversión de archivos multimedia, especialmente enfocadas en archivos EXR y video. Estas herramientas fueron desarrolladas por Lega Pugliese para facilitar diversas tareas de procesamiento de medios.

## Herramientas disponibles

### EXR_Checker

Verifica la integridad de archivos EXR en una carpeta y sus subcarpetas recursivamente.

- **Uso**: Arrastra una carpeta que contenga archivos EXR sobre el archivo EXR_Checker.bat.
- **Funcionalidades**:
  - Recibe una carpeta arrastrada como argumento.
  - Llama a un script de PowerShell para procesar los archivos EXR.
  - Usa exrcheck (de OpenEXR) para verificar la integridad de cada archivo EXR.
  - Genera un reporte de archivos corruptos, si los hay.


### EE_MOV+MXF

Procesa un archivo .MOV para crear versiones MOV y MXF con overlays y textos específicos.

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


### EXR_to_DWAA

Convierte archivos EXR de cualquier compresión a compresión DWAA.

- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXR_to_DWAA.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión.
  - La salida se guarda en una nueva carpeta con la compresión DWAA aplicada.


### EXR_to_PXR24

Convierte archivos EXR de cualquier compresión a compresión PXR24.

- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXR_to_PXR24.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión.
  - La salida se guarda en una nueva carpeta con la compresión PXR24 aplicada.


### EXRmC_to_PXR24

Convierte archivos EXR multicanal a archivos EXR individuales por canal, con compresión Pxr24.

- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXR_to_Channels_Pxr24.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión y exrheader para leer los canales.
  - Corrige los nombres de los canales eliminando "FinalImageMovieRenderQueue_" y reemplazando ActorHitProxyMask por CryptoMatte.
  - La salida se guarda en nuevas subcarpetas con los archivos divididos por canal y con la compresión Pxr24 aplicada.


### Versioning

Script para versionar archivos .py antes de realizar cambios.

- **Uso**: Arrastra un archivo .py sobre Versioning.bat.
- **Funcionalidades**:
  - Copia el archivo a la carpeta +OLD.
  - Asigna un nuevo número de versión.


### Release Generator

Script para generar un archivo zip del proyecto, excluyendo ciertos archivos y carpetas.

- **Uso**: Ejecuta +Release_generator.bat.
- **Funcionalidades**:
  - Crea un archivo zip del proyecto LGA_MediaTools.
  - Excluye archivos y carpetas especificados en .exclude.lst.


## Requisitos

- FFmpeg, Oiio y OpenColorIO, que son parte de este repositorio.
- Estructura de carpetas específica con _input, FgPlate, y EditRef para algunas herramientas.
- 7-Zip debe estar instalado para el Release Generator.



Lega Pugliese | 2024
