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
  - Muestra progreso en tiempo real con códigos de color para indicar estado de archivos.
  - Escribe resúmenes por carpeta indicando archivos válidos o corruptos encontrados.
- **Requisitos**:
  - OpenEXR (exrcheck), ya incluido en el repositorio.

<br>

### EE_MOV+MXF

Procesa un archivo .MOV para crear versiones MOV y MXF con overlays y textos específicos.

- **Versión actual**: v1.7
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
  - Convierte colores de ACES a Rec.709 para el thumbnail.
  - Utiliza códecs ProRes para MOV y DNxHD para MXF.
- **Requisitos**:
  - FFmpeg, ya incluido en el repositorio.
  - OIIO (oiiotool), ya incluido en el repositorio.
  - OpenColorIO, ya incluido en el repositorio.
  - Estructura de carpetas específica con _input, FgPlate, y EditRef.

<br>

### EXR_to_MOV_LT

Convierte secuencias EXR en ACES 2065-1 a archivos MOV en Rec.709 usando ProRes LT.

- **Versión actual**: v1.0
- **Uso**: Arrastra una carpeta con una secuencia EXR sobre el archivo EXR_to_MOV_LT.bat.
- **Funcionalidades**:
  - Detecta automáticamente el patrón de numeración de frames en la secuencia EXR.
  - Convierte automáticamente el espacio de color de ACES 2065-1 a Rec.709 usando OpenColorIO.
  - Proceso de dos pasos: oiiotool para conversión de color + FFmpeg para crear MOV.
  - Genera archivos MOV con compresión ProRes LT (profile 1) en formato YUV 422 10-bit.
  - El archivo de salida se guarda en el directorio padre de la carpeta arrastrada.
  - El nombre del archivo MOV se toma del nombre de la carpeta de origen.
  - Limpieza automática de archivos temporales.
  - Muestra progreso en tiempo real con información detallada del proceso.
  - Calcula y muestra tiempo total de procesamiento y tamaño del archivo generado.
  - Maneja automáticamente secuencias con diferentes números de frame inicial.
- **Requisitos**:
  - FFmpeg, ya incluido en el repositorio.
  - OIIO (oiiotool), ya incluido en el repositorio.
  - OpenColorIO, ya incluido en el repositorio.

<br>

### MOV_to_PNG_997

Convierte archivos MOV a secuencias de archivos PNG comenzando desde el frame 0997.

- **Versión actual**: v1.0
- **Uso**: Arrastra un archivo .MOV sobre el archivo MOV_to_PNG_997.bat.
- **Funcionalidades**:
  - Acepta archivos .MOV arrastrados al .bat.
  - Crea una subcarpeta con el nombre del archivo MOV (sin extensión).
  - Si la carpeta ya existe y contiene archivos, agrega un número al final para crear una carpeta única.
  - Genera una secuencia PNG numerada comenzando desde 0997 (4 dígitos).
  - Preserva la calidad de video original en formato PNG con máxima calidad.
  - Muestra información detallada del video (resolución, frame rate, duración, total de frames).
  - Calcula y muestra tiempo total de procesamiento y tamaño de archivos generados.
  - Utiliza formato RGB24 para compatibilidad máxima.
  - Nomenclatura de archivos: `nombre_archivo_0997.png`, `nombre_archivo_0998.png`, etc.
- **Requisitos**:
  - FFmpeg, ya incluido en el repositorio.

<br>

### EXR_to_DWAA

Convierte archivos EXR de cualquier compresión a compresión DWAA.

- **Versión actual**: v1.2
- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXR_to_DWAA.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión.
  - Aplica compresión DWAA con calidad 60.
  - Maneja automáticamente renombrado de canales específicos.
  - Muestra progreso en tiempo real con información de tamaños de archivo.
  - Calcula y muestra tiempo total de procesamiento.
  - Reemplaza "piz" por "dwaa" en nombres de carpetas o agrega "-dwaa" al final.
  - La salida se guarda en una nueva carpeta con la compresión DWAA aplicada.
- **Requisitos**:
  - OIIO (oiiotool), ya incluido en el repositorio.

<br>

### EXR_to_ZIP

Convierte archivos EXR de cualquier compresión a compresión ZIP.

- **Versión actual**: v1.0
- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXR_to_ZIP.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión.
  - Aplica compresión ZIP para reducir tamaño de archivos.
  - Maneja automáticamente renombrado de canales específicos.
  - Muestra progreso en tiempo real con información de tamaños de archivo.
  - Calcula y muestra tiempo total de procesamiento.
  - Si la carpeta contiene "dwaa", se cambiará por "zip", sino se agregará "-zip" al final.
  - La salida se guarda en una nueva carpeta con la compresión ZIP aplicada.
- **Requisitos**:
  - OIIO (oiiotool), ya incluido en el repositorio.

<br>

### EXR_to_PIZ

Convierte archivos EXR de cualquier compresión a compresión PIZ.

- **Versión actual**: v1.0
- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXR_to_PIZ.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión.
  - Aplica compresión PIZ para archivos de alta calidad.
  - Maneja automáticamente renombrado de canales específicos.
  - Muestra progreso en tiempo real con información de tamaños de archivo.
  - Calcula y muestra tiempo total de procesamiento.
  - Si la carpeta contiene "dwaa", se cambiará por "piz", sino se agregará "-piz" al final.
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
  - Aplica compresión PXR24 para balance entre calidad y tamaño.
  - Maneja automáticamente renombrado de canales específicos.
  - Elimina "FinalImageMovieRenderQueue_" y reemplaza "ActorHitProxyMask" por "Cryptomatte".
  - Maneja casos especiales como "FinalImagePPM_MRQ_05_SceneDepth" a "MRQ_SceneDepth".
  - Muestra progreso en tiempo real con información de tamaños de archivo.
  - Calcula y muestra tiempo total de procesamiento.
  - Reemplaza "piz" por "pxr24" en nombres o agrega "-pxr24" al final.
  - La salida se guarda en una nueva carpeta con la compresión PXR24 aplicada.
- **Requisitos**:
  - OIIO (oiiotool), ya incluido en el repositorio.

<br>

### EXRmC_to_PXR24

Convierte archivos EXR multicanal a archivos EXR individuales por canal, con compresión Pxr24.

- **Versión actual**: v1.4
- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXRmCh_to_PXR24.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión y exrheader para leer los canales.
  - Separa automáticamente archivos multicanal en archivos individuales por canal.
  - Corrige los nombres de los canales eliminando "FinalImageMovieRenderQueue_" y reemplazando ActorHitProxyMask por CryptoMatte.
  - Maneja casos especiales de renombrado de canales específicos.
  - Agrupa canales con numeración consecutiva automáticamente.
  - Inserta nombres de canal en posiciones apropiadas del nombre de archivo.
  - Calcula tamaños totales originales vs convertidos.
  - Muestra tiempo total de procesamiento.
  - La salida se guarda en nuevas subcarpetas con los archivos divididos por canal y con la compresión Pxr24 aplicada.
- **Requisitos**:
  - OIIO (oiiotool), ya incluido en el repositorio.
  - OpenEXR (exrheader), ya incluido en el repositorio.

<br>

### EXRmC_to_PXR24+DWAA

Convierte archivos EXR multicanal a archivos EXR individuales por canal, con compresión Pxr24 y DWAA.

- **Versión actual**: v1.3
- **Uso**: Arrastra una carpeta con archivos EXR sobre el archivo EXRmCh_to_PXR24+DWAA.bat.
- **Funcionalidades**:
  - Utiliza oiiotool para realizar la conversión y exrheader para leer los canales.
  - Separa automáticamente archivos multicanal en archivos individuales por canal.
  - Corrige los nombres de los canales eliminando "FinalImageMovieRenderQueue_" y reemplazando ActorHitProxyMask por CryptoMatte.
  - El canal RGBA se convierte a DWAA, mientras que los demás canales se convierten a Pxr24.
  - Aplica compresión inteligente según el tipo de canal (RGBA=DWAA, otros=Pxr24).
  - Agrupa canales con numeración consecutiva automáticamente.
  - Maneja renombrado inteligente de archivos según compresión aplicada.
  - Calcula tamaños totales originales vs convertidos.
  - Muestra tiempo total de procesamiento.
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
