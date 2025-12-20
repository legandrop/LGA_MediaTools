# Pipeline DPX ↔ EXR con Preservación Completa de Metadata

## Descripción General

Herramientas para conversión bidireccional entre DPX y EXR manteniendo **100% de la metadata crítica** del DPX original (excepto campo Software que se puede forzar).

## Flujo de Trabajo

### DPX → EXR (Preservación)
1. **Entrada**: Carpeta con archivos DPX
2. **Proceso**: Conversión a EXR DWAA con metadata completa preservada
3. **Salida**: EXR con atributos `lga:*` (cabecera comprimida) y `dpx:*` (metadata estructurada)

### EXR → DPX (Reconstrucción)
1. **Entrada**: Carpeta con EXR generados por la herramienta anterior
2. **Proceso**: Reconstrucción de DPX con metadata original del EXR
3. **Salida**: DPX idéntico al original (excepto bloque de imagen y Software opcional)

## Archivos y Scripts

### Scripts Principales

#### `LGA_Tools/DPX_to_EXR_DWAA.ps1` (v1.04)
**Función**: `Add-DPXMetadataToEXR`
- Lee metadata completa del DPX usando `iinfo.exe`
- Fuerza `dpx:Transfer = "Printing density"` (log DPX)
- Comprime cabecera DPX completa (8192 bytes → ~850 bytes base64)
- Agrega atributos `lga:DPXHeaderZ`, `lga:DPXHeaderSize`, `lga:DPXMagic`
- Preserva 32+ campos `dpx:*` críticos en una sola operación `exrstdattr`

#### `LGA_Tools/EXR_to_DPX.ps1` (v1.1)
**Función**: `Create-DPXWithMetadata`
- Extrae cabecera DPX comprimida de atributos `lga:*`
- Descomprime y reconstruye cabecera idéntica
- Actualiza `file_size` y opcionalmente `Software/Creator`
- Genera imagen uint16 usando `oiiotool`
- Ensambla DPX final con metadata completa

### Launchers (.bat)

#### `DPX_to_EXR_DWAA.bat`
Llama a: `powershell -ExecutionPolicy Bypass -File "LGA_Tools/DPX_to_EXR_DWAA.ps1" "%~1"`

#### `EXR_to_DPX.bat`
Llama a: `powershell -ExecutionPolicy Bypass -File "LGA_Tools/EXR_to_DPX.ps1" "%~1"`

## Metadata Preservada (Campos dpx:*)

### Información Crítica (Siempre Preservada)
- `dpx:Transfer`: "Printing density" (log DPX forzado)
- `dpx:Colorimetric`: "Linear"
- `dpx:InputDevice`: Dispositivo de captura original
- `dpx:SlateInfo`: Información de slate completa
- `dpx:FramePosition`, `dpx:TemporalFrameRate`: Timing preciso
- `dpx:WhiteLevel`, `dpx:BlackLevel`: Niveles de imagen
- `dpx:UserData`: Array de 6144 bytes personalizados

### Información Técnica Completa
- `dpx:ImageDescriptor`, `dpx:Packing`
- `dpx:HorizontalSampleRate`, `dpx:VerticalSampleRate`
- `dpx:XScannedSize`, `dpx:YScannedSize`
- `dpx:ShutterAngle`, `dpx:IntegrationTimes`
- `dpx:SequenceLength`, `dpx:HeldCount`, `dpx:DittoKey`

### Campos DPX Específicos Agregados
- `dpx:Interlace`: 0
- `dpx:VideoSignal`: 255
- `dpx:FieldNumber`: 255

## Atributos Especiales en EXR

### lga:* (Cabecera DPX Comprimida)
- `lga:DPXHeaderZ`: Cabecera completa comprimida en base64
- `lga:DPXHeaderSize`: Tamaño original (8192 bytes)
- `lga:DPXMagic`: "SDPX" para validación

### dpx:* (Metadata Estructurada)
32+ campos críticos preservados para reconstrucción perfecta.

## Uso Práctico

### Conversión Completa DPX → DPX
```bash
# 1. DPX original → EXR con metadata
arrastrar_carpeta_dpx_a: DPX_to_EXR_DWAA.bat

# 2. EXR → DPX reconstruido idéntico
arrastrar_carpeta_exr_a: EXR_to_DPX.bat
```

### Resultado Final
- **DPX reconstruido**: 100% idéntico al original en metadata
- **Única diferencia**: Campo `Software` (opcional forzar a "daVinci" u otro)
- **Compresión**: EXR DWAA (60% reducción tamaño vs DPX)

## Requisitos Técnicos

- **OpenImageIO**: Para conversión de imagen y metadata
- **Python**: Para compresión/descompresión de cabecera
- **PowerShell**: Scripts principales
- **Espacio**: ~14.7MB EXR vs 72.9MB DPX original

## Validación

Verificar metadata preservada:
```bash
# En DPX original
& "OIIO\iinfo.exe" -v "archivo_original.dpx" | findstr "dpx:"

# En DPX reconstruido
& "OIIO\iinfo.exe" -v "archivo_reconstruido.dpx" | findstr "dpx:"
```

Campos críticos deben coincidir 100%.
