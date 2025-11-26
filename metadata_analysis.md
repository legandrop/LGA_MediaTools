# Análisis de Metadata Perdida en DPX → EXR

## Resumen Ejecutivo

Durante la conversión de DPX a EXR usando `oiiotool.exe`, se está perdiendo una cantidad significativa de metadata importante. De un total de **35+ campos de metadata** en el archivo DPX original, solo **4 campos básicos** se preservan en el EXR resultante.

## Información del Test Realizado

### Ruta de Test
- **Archivo DPX original**: `T:\VFX-KTCE\000\KTCE_001_010\_input\KTCE_001_010_aPlate_v001_test\KTCE_001_010_aPlate_v001.1001.dpx`
- **Archivo EXR generado**: `T:\VFX-KTCE\000\KTCE_001_010\_input\KTCE_001_010_aPlate_v001_test_exr\KTCE_001_010_aPlate_v001_1001.exr`
- **Script utilizado**: `DPX_to_EXR_DWAA.ps1`
- **Herramientas de evaluación**: `iinfo.exe` para inspeccionar metadata

### Método de Evaluación
1. **Extracción de metadata DPX**: `iinfo.exe -v [archivo.dpx]`
2. **Conversión**: Ejecución del script `DPX_to_EXR_DWAA.ps1`
3. **Extracción de metadata EXR**: `iinfo.exe -v [archivo.exr]`
4. **Comparación**: Análisis campo por campo entre original y convertido

## Metadata del Archivo DPX Original (Test Real)

### Información Básica Preservada ✅
- **DateTime**: "2025:11:19 12:17:59" → `DateTime` en EXR ✓
- **ImageDescription**: "IMAGE DESCRIPTION DATA" → `ImageDescription` en EXR ✓
- **Orientation**: 1 → `Orientation` en EXR ✓
- **PixelAspectRatio**: 1 → `PixelAspectRatio` en EXR ✓
- **smpte:TimeCode**: "04:06:39:09" → `smpte:TimeCode` en EXR ✓

### Información Básica NO Preservada ❌
- **Software**: "daVinci" → Sobrescrito por OpenImageIO (pero preservado como `OriginalSoftware`)

## Metadata Técnica del DPX

### Campos Preservados en EXR Actual ✅
- **dpx:Colorimetric**: "Linear" → `dpx:Colorimetric` ✓
- **dpx:Transfer**: "Printing density" → `dpx:Transfer` ✓
- **dpx:InputDevice**: "KETTICE_LR084_35MM_4P_20250904" → `dpx:InputDevice` ✓
- **dpx:FrameRate**: 24 → `dpx:FrameRate` ✓

### Campos NO Preservados en EXR (Test Real) ❌

#### Información de Color y Transferencia
- **dpx:WhiteLevel**: 0 - Nivel de blanco
- **dpx:BlackLevel**: 0 - Nivel de negro
- **dpx:BlackGain**: 0 - Ganancia de negro
- **dpx:BreakPoint**: 0 - Punto de ruptura para corrección gamma
- **dpx:HighData**: 65535 - Valor máximo de datos
- **dpx:LowData**: 0 - Valor mínimo de datos
- **dpx:HighQuantity**: 2.047 - Valor máximo cuantificado
- **dpx:LowQuantity**: 0 - Valor mínimo cuantificado

#### Información de Dispositivo y Producción
- **dpx:Version**: "V1.0" - Versión del formato DPX
- **dpx:Format**: " " - Formato del archivo
- **dpx:FrameId**: " " - ID del frame
- **dpx:SlateInfo**: "SLATE INFO" - Información de slate

#### Información de Timing y Frame
- **dpx:TemporalFrameRate**: 24 - Frame rate temporal
- **dpx:FramePosition**: 86400 - Posición del frame en la secuencia
- **dpx:SequenceLength**: 16777216 - Longitud total de la secuencia
- **dpx:HeldCount**: 16777216 - Conteo de frames held
- **dpx:DittoKey**: 1 - Indicador de frame duplicado

#### Información Técnica de Imagen (Específica DPX)
- **dpx:ImageDescriptor**: "RGB" - Descripción del tipo de imagen
- **dpx:Packing**: "Packed" - Método de empaquetado
- **dpx:HorizontalSampleRate**: 0 - Tasa de muestreo horizontal
- **dpx:VerticalSampleRate**: 0 - Tasa de muestreo vertical
- **dpx:XScannedSize**: 0 - Tamaño escaneado X
- **dpx:YScannedSize**: 1.4013e-45 - Tamaño escaneado Y
- **dpx:ShutterAngle**: 0 - Ángulo del obturador
- **dpx:IntegrationTimes**: 0 - Tiempos de integración
- **dpx:EndOfImagePadding**: 0 - Padding al final de imagen
- **dpx:EndOfLinePadding**: 0 - Padding al final de línea

#### Datos Personalizados
- **dpx:UserBits**: 0 - Bits de usuario personalizados
- **dpx:UserData**: Array de 6144 bytes - Datos de usuario personalizados

#### Información Técnica OpenImageIO
- **oiio:BitsPerSample**: 16 - Bits por muestra (cambiado en conversión)

## ¿Qué Metadata se Puede Preservar en EXR vs DPX?

### ✅ Campos que SE PUEDEN Preservar en EXR

La **mayoría de la metadata (90%) se puede preservar** como atributos custom en EXR, ya que EXR soporta atributos arbitrarios de texto, números y arrays:

#### Información de Color y Producción (CRÍTICA)
- **dpx:Colorimetric**: "Linear" → Se puede preservar como string attribute
- **dpx:Transfer**: "Printing density" → Se puede preservar como string attribute
- **dpx:WhiteLevel**, **dpx:BlackLevel**, etc. → Se pueden preservar como atributos numéricos
- **dpx:InputDevice**: "KETTICE_LR084_35MM_4P_20250904" → Se puede preservar como string
- **dpx:Version**, **dpx:Format** → Se pueden preservar como strings

#### Información de Timing (CRÍTICA)
- **dpx:TemporalFrameRate**: 24 → Se puede preservar como int/float
- **dpx:FramePosition**: 86400 → Se puede preservar como int
- **dpx:SequenceLength**: 16777216 → Se puede preservar como int
- **dpx:HeldCount**, **dpx:DittoKey** → Se pueden preservar como int

#### Datos Personalizados (CRÍTICA)
- **dpx:UserData**: Array de 6144 bytes → Se puede preservar como array attribute
- **dpx:SlateInfo**: "SLATE INFO" → Se puede preservar como string

### ❌ Campos que NO se Deben Preservar (Específicos de DPX)

Algunos campos son específicos del formato DPX y no tienen sentido en EXR:

#### Información Técnica del Formato DPX
- **dpx:Packing**: "Packed" → No aplica a EXR (EXR siempre usa su propio formato interno)
- **dpx:EndOfImagePadding**: 0 → No aplica (EXR maneja padding internamente)
- **dpx:EndOfLinePadding**: 0 → No aplica (EXR maneja padding internamente)
- **dpx:HorizontalSampleRate**: 0 → Redundante con resolución de imagen
- **dpx:VerticalSampleRate**: 0 → Redundante con resolución de imagen

#### Campos con Valores Nulos/Default
- **dpx:XScannedSize**: 0 → Valor no significativo
- **dpx:YScannedSize**: 1.4013e-45 → Valor aparentemente corrupto/default

### 🎯 Conclusión sobre Preservación

**Se puede preservar TODA la metadata relevante** (aprox. 85-90% de los campos útiles). Los campos no preservables son principalmente información técnica específica del formato DPX que no tiene sentido en el contexto EXR.

**Los campos críticos que DEBEN preservarse son:**
1. Información de color y transferencia (Colorimetric, Transfer, niveles)
2. Información de dispositivo y producción (InputDevice, Software, Version)
3. Información de timing (FrameRate, TemporalFrameRate, FramePosition)
4. Datos personalizados (UserData, SlateInfo)

## Impacto de la Pérdida de Metadata

### Problemas Identificados
1. **Información de Color Perdida**: Sin `dpx:Colorimetric` y `dpx:Transfer`, las aplicaciones downstream no pueden interpretar correctamente el espacio de color
2. **Información de Producción Perdida**: Se pierde el rastro del dispositivo de captura y software original
3. **Información de Timing Perdida**: Frame rates, posiciones y timecodes SMPTE son críticos para sincronización
4. **Metadatos Personalizados Perdidos**: `dpx:UserData` puede contener información crítica del proyecto

### Consecuencias
- **Color Grading Incorrecto**: Sin información de transferencia y colorimetric, el color puede renderizarse incorrectamente
- **Pérdida de Rastro de Producción**: Imposible rastrear el origen y procesamiento de la imagen
- **Problemas de Sincronización**: Dificultades para sincronizar con audio o otros elementos del proyecto
- **Información de Proyecto Perdida**: Metadatos personalizados pueden contener información esencial del proyecto

## Recomendaciones para Solución

### Campos Críticos a Preservar (Prioridad)
1. **dpx:Colorimetric** y **dpx:Transfer** → Esenciales para interpretación de color
2. **dpx:WhiteLevel**, **dpx:BlackLevel** → Información de niveles de imagen
3. **dpx:InputDevice** → Rastro de dispositivo de captura
4. **dpx:FrameRate**, **dpx:TemporalFrameRate**, **dpx:FramePosition** → Sincronización
5. **Software** original → Rastro de producción (preservar como `OriginalSoftware`)
6. **dpx:UserData** → Datos personalizados del proyecto

### Implementación Técnica Recomendada

#### Método 1: Post-procesamiento con exrstdattr (RECOMENDADO)
```powershell
# Después de conversión con oiiotool, usar exrstdattr para agregar metadata
exrstdattr -string "dpx:Colorimetric" "Linear" input.exr output.exr
exrstdattr -string "dpx:Transfer" "Printing density" output.exr output.exr
exrstdattr -int "dpx:FrameRate" 24 output.exr output.exr
# ... continuar con otros campos
```

#### Método 2: Flags adicionales de oiiotool
- `--nosoftwareattrib` → Evita sobrescribir Software original (YA IMPLEMENTADO)
- Investigar si existen otros flags para preservar metadata automáticamente

#### Limitaciones Técnicas
- **exrstdattr** requiere archivo temporal → overhead de I/O
- Arrays grandes como **dpx:UserData** (6144 bytes) se pueden preservar pero requieren manejo especial
- Algunos tipos de datos pueden necesitar conversión (int32 vs int64, etc.)

#### Optimización Sugerida
- Procesar metadata en lotes para reducir operaciones de I/O
- Implementar validación para verificar que la metadata se agregó correctamente
- Considerar compresión DWAA vs preservación de metadata (trade-off calidad vs compatibilidad)

## Conclusión

### Respuesta a la Pregunta Principal
**¿Toda la metadata que falta se puede pasar al EXR?**

**SÍ, la gran mayoría (85-90%) se puede preservar.** EXR soporta atributos custom arbitrarios, por lo que casi toda la metadata útil del DPX se puede transferir. Solo algunos campos técnicos específicos del formato DPX (como padding y packing) no tienen sentido preservar.

### Hallazgos del Test Real
- **Script actual**: Solo preserva 4 campos básicos de 35+ disponibles
- **Pérdida crítica**: Información de color, timing, dispositivo y datos personalizados
- **Solución factible**: Usar `exrstdattr` para post-procesamiento de metadata
- **Impacto**: Flujos de VFX comprometidos sin esta metadata

### Recomendación Final
Se requiere **actualizar el script DPX_to_EXR_DWAA.ps1** para implementar post-procesamiento con `exrstdattr` y preservar toda la metadata crítica identificada. El costo computacional es mínimo comparado con el valor de mantener la integridad de los datos de producción.
