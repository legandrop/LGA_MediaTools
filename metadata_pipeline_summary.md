# Resumen rápido: DPX ➜ EXR ➜ DPX sin pérdida de metadata

> **Build test:** 27-Nov-2025 — `KTCE_001_010_aPlate_v001.1001` (ruta abajo).  
> **Scripts:** `DPX_to_EXR_DWAA.ps1 v1.05` y `EXR_to_DPX.ps1 v1.1`

## Rutas de test
- DPX original: `T:\VFX-KTCE\000\KTCE_001_010\_input\KTCE_001_010_aPlate_v001_test\`
- EXR convertido: `...\KTCE_001_010_aPlate_v001_test_exr\`
- DPX reconstruido: `...\KTCE_001_010_aPlate_v001_test_exr_dpx\`

## Flujo resumido
1. **DPX ➜ EXR** (`DPX_to_EXR_DWAA.ps1`)
   - Convierte a EXR DWAA (quality 60) con `oiiotool`.
   - Extrae 30+ campos DPX vía `iinfo -v` y los aplica con una sola llamada a `exrstdattr`.
   - Lee la cabecera DPX completa (hasta `image_data_offset`, 8192 bytes en el test), la comprime (deflate) y la guarda en el EXR como `lga:DPXHeaderZ`. También se guarda tamaño (`lga:DPXHeaderSize`) y magia (`lga:DPXMagic`).
2. **EXR ➜ DPX** (`EXR_to_DPX.ps1`)
   - Busca los atributos `lga:*`, descomprime la cabecera original y la usa como plantilla.
   - Genera un DPX temporal con `oiiotool -d uint16` para obtener solo los datos de imagen.
   - Si la magia original era `SDPX` (big-endian) y el temporal es `XPDS`, hace byte-swap par a par.
   - Actualiza `file_size`, reescribe el bloque `Creator` a `LGA EXR_to_DPX v1.0`, y ensambla `cabecera + datos` en el DPX destino.

## Metadata crítica verificada (`iinfo -v *.dpx`)
| Campo | Original | DPX reconstruido |
| --- | --- | --- |
| `dpx:Transfer` | `"Printing density"` | `"Printing density"` |
| `dpx:TemporalFrameRate` | `24` | `24` |
| `dpx:InputDevice` | `"KETTICE_LR084_35MM_4P_20250904"` | Igual |
| `dpx:SlateInfo` | `"SLATE INFO"` | Igual |
| `dpx:FramePosition / SequenceLength / HeldCount` | `86400 / 16777216 / 16777216` | Iguales |
| `dpx:UserData` | `[6144 x uint8]` | `[6144 x uint8]` |
| `dpx:White/Black/High/Low` | `0 / 0 / 65535 / 0` | Iguales |
| `Software` | `"daVinci"` (solo campo permitido a cambiar, pero se preservó) | `"daVinci"` |

## Cómo se preserva el “log”
- `dpx:Transfer` se guarda tal cual venga del DPX (en el test: `"Printing density"`, el equivalente a log).
- Si se necesita forzar otro valor, basta con editar el atributo `dpx:Transfer` en el EXR antes de correr `EXR_to_DPX.ps1`. El header final se regenerará con esa modificación, manteniendo coherencia con el resto de la metadata.

## Validación rápida
```powershell
# DPX original vs DPX reconstruido
& $env:LGA_TOOLS\OIIO\iinfo.exe -v T:\...\_test\KTCE_001_010_aPlate_v001.1001.dpx |
    findstr "dpx:"

& $env:LGA_TOOLS\OIIO\iinfo.exe -v T:\...\_test_exr_dpx\KTCE_001_010_aPlate_v001.1001.dpx |
    findstr "dpx:"
```
Las listas coinciden uno a uno (ver tabla superior). Diferencias aceptadas: tamaño de archivo (por nueva escritura) y campo `Software` si se decide cambiar.

## Checklist antes de publicar
1. Confirmar que cada EXR tenga los tres atributos nuevos (`lga:DPXHeaderZ/Size/Magic`).  
2. Revisar `iinfo -v EXR | findstr lga` si hay dudas.
3. Al reconvertir, verificar que `EXR_to_DPX.ps1` no reporte advertencias y que el DPX final contenga `dpx:UserData` y `dpx:Transfer` correctos.
4. Para depurar un frame: 
   - borrar `...\_test_exr` y `...\_test_exr_dpx`,
   - ejecutar ambos scripts en orden,
   - comparar metadatos con `iinfo`.

Con este flujo, el DPX final es binariamente consistente con el original en todos los campos relevantes (color, timing, device, user data). Solo se modifica el bloque de imagen —el header se reconstruye con los bytes exactos extraídos del DPX de referencia.

