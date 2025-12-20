# Pipeline DPX ↔ EXR con preservación completa de metadata

## Resumen
Dos herramientas enlazadas garantizan roundtrip perfecto:
- `DPX_to_EXR_DWAA.ps1`: convierte DPX a EXR (DWAA) y embebe el header DPX completo.
- `EXR_to_DPX.ps1` v2.0 (FAST END): reconstruye DPX usando el header embebido, forzando endianness para evitar byte-swap y sin DPX temporal.

## Concepto clave: metadata íntegra
- El DPX original se guarda dentro del EXR como:
  - `lga:DPXHeaderZ` (header DPX completo, comprimido deflate + base64)
  - `lga:DPXHeaderSize` (tamaño del header)
  - `lga:DPXMagic` ("SDPX"/"XPDS" para endianness)
- Además, se preservan 32+ campos `dpx:*` críticos en el EXR.
- El DPX final reemplaza solo los píxeles; el header proviene del original embebido.

## Flujo DPX → EXR (`DPX_to_EXR_DWAA.ps1` v1.04)
1) Lee metadata completa del DPX con `iinfo`.
2) Fuerza `dpx:Transfer = "Printing density"` (log DPX).
3) Comprime el header completo y lo embebe como `lga:DPXHeaderZ`, `lga:DPXHeaderSize`, `lga:DPXMagic`.
4) Escribe EXR DWAA con 32+ atributos `dpx:*` críticos.

## Flujo EXR → DPX (`EXR_to_DPX.ps1` v2.0 FAST END)
1) Lee solo atributos lga con `oiiotool --info -v --metamatch "lga:"`.
2) Descomprime el header original; detecta tamaño y endianness.
3) Ejecuta `oiiotool` una sola vez para escribir el DPX final, forzando `oiio:Endian` igual al original → evita byte-swap del payload.
4) Patch in-place del header original:
   - Ajusta `image data offset` si difiere.
   - Actualiza `file size`.
   - Escribe Creator y el header completo al inicio.
5) Sin DPX temporal, sin swap (cuando coincide endianness), con timeouts y reintentos.

## Mejora vs versión anterior (v1.5)
- Antes: `iinfo -v` completo, DPX temporal, lectura y reescritura completa del payload, posible byte-swap masivo.
- Ahora: una sola escritura de `oiiotool`, sin DPX temporal, sin swap al forzar endianness → ~0.5 s/frame (antes ~6 s/frame en pruebas recientes), headers idénticos al original.

## Archivos y launchers
- `LGA_Tools/DPX_to_EXR_DWAA.ps1` — conversión DPX→EXR (DWAA) con metadata embebida.
- `LGA_Tools/EXR_to_DPX.ps1` — reconstrucción EXR→DPX v2.0 FAST END.
- `DPX_to_EXR_DWAA.bat` llama al script DPX→EXR.
- `EXR_to_DPX.bat` llama al script EXR→DPX.

## Metadata preservada (dpx:*)
- Crítica: `dpx:Transfer` ("Printing density"), `dpx:Colorimetric`, `dpx:InputDevice`, `dpx:SlateInfo`, `dpx:FramePosition`, `dpx:TemporalFrameRate`, `dpx:WhiteLevel`, `dpx:BlackLevel`, `dpx:UserData` (6144 bytes).
- Técnica: `dpx:ImageDescriptor`, `dpx:Packing`, `dpx:HorizontalSampleRate`, `dpx:VerticalSampleRate`, `dpx:XScannedSize`, `dpx:YScannedSize`, `dpx:ShutterAngle`, `dpx:IntegrationTimes`, `dpx:SequenceLength`, `dpx:HeldCount`, `dpx:DittoKey`.
- Específicos: `dpx:Interlace`=0, `dpx:VideoSignal`=255, `dpx:FieldNumber`=255.

## Validación rápida
```bash
# DPX original
& "OIIO\\iinfo.exe" -v "original.dpx" | findstr "dpx:"
# DPX reconstruido
& "OIIO\\iinfo.exe" -v "reconstruido.dpx" | findstr "dpx:"
# Atributos lga en EXR
& "OIIO\\oiiotool.exe" --info -v --metamatch "lga:" "source.exr"
```
Los campos críticos deben coincidir; el header reconstruido es el embebido.

## Notas
- Campo `Software/Creator` puede forzarse; resto de metadata proviene del DPX original.
- DWAA reduce tamaño del EXR (~60% vs DPX), útil para composición.
