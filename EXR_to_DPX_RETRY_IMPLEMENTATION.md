# EXR_to_DPX - Implementación de Lógica de Reintento Crítica

## 📋 Estado Actual del Proyecto

### ✅ Lo que YA FUNCIONA:
- **Script EXR_to_DPX.ps1** v1.5 - Funciona correctamente con timeout de 30s
- **Script quick_monitor.ps1** - Monitoreo en tiempo real con historial
- **Timeout robusto** - Previene procesos colgados indefinidamente
- **Logging mejorado** - Tiempos y estados detallados

### ❌ El PROBLEMA CRÍTICO:
Actualmente, si un archivo falla durante la conversión, el script simplemente **lo salta** y continúa con el siguiente. **Esto deja archivos sin convertir**, lo cual es inaceptable.

## 🎯 Requisitos de la Solución

### **Comportamiento Requerido:**
1. **3 intentos por archivo** - Si falla, reintentar automáticamente hasta 3 veces
2. **2 segundos de espera** entre reintentos para posibles problemas temporales
3. **Si falla 3 veces** - DETENER TODO EL PROCESO con mensaje crítico claro
4. **Logging detallado** - Mostrar cada reintento y resultado

### **Resultado Final:**
- ✅ **Archivos exitosos**: Procesados normalmente (1 intento)
- ✅ **Archivos con problemas temporales**: Reintentados hasta 3 veces
- ✅ **Archivos definitivamente corruptos**: Detienen el proceso con error claro

## 🔧 Detalles de Implementación

### **Ubicación del Código:**
Archivo: `LGA_Tools\EXR_to_DPX.ps1`
Sección: Loop `foreach ($file in $files)` (alrededor de línea 320)

### **Código Actual (PROBLEMÁTICO):**
```powershell
# Crear DPX con metadata completa en una sola operación
Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Procesando: $($file.Name) -> $fileName.dpx" -ForegroundColor Yellow
if (Create-DPXWithMetadata -exrPath $file.FullName -dpxPath $outputPath) {
    # ✅ Éxito - procesa normalmente
    $convertedSize = (Get-Item $outputPath).Length
    $totalConvertedSize += $convertedSize
    # ... logging de éxito
} else {
    # ❌ Falla - SOLO LOGEA Y CONTINÚA (PROBLEMA)
    Write-Host "  Error al convertir." -ForegroundColor Red
}
```

### **Código Requerido (SOLUCIÓN):**
```powershell
# LÓGICA DE REINTENTO CRÍTICA - NUNCA DEJAR UN ARCHIVO SIN CONVERTIR
$maxRetries = 3
$retryCount = 0
$conversionSuccess = $false

while ($retryCount -lt $maxRetries -and -not $conversionSuccess) {
    $retryCount++

    if ($retryCount -gt 1) {
        Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [RETRY] Reintentando archivo $($file.Name) (intento $retryCount de $maxRetries)" -ForegroundColor Yellow
    }

    Write-Host "Convirtiendo archivo $currentFile de $fileCount..." -NoNewline -ForegroundColor DarkYellow

    # Crear DPX con metadata completa - INTENTO $retryCount DE $maxRetries
    Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Procesando: $($file.Name) -> $fileName.dpx" -ForegroundColor Yellow

    if (Create-DPXWithMetadata -exrPath $file.FullName -dpxPath $outputPath) {
        if (Test-Path $outputPath) {
            $convertedSize = (Get-Item $outputPath).Length
            $totalConvertedSize += $convertedSize

            $originalSizeFormatted = Format-FileSize $originalSize
            $convertedSizeFormatted = Format-FileSize $convertedSize
            Write-Host "  $originalSizeFormatted -> $convertedSizeFormatted" -ForegroundColor DarkYellow
            Write-Host "  Metadata aplicada correctamente" -ForegroundColor Green

            $conversionSuccess = $true
            Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [SUCCESS] Archivo $($file.Name) convertido exitosamente en intento $retryCount" -ForegroundColor Green
        } else {
            Write-Host "  Error: No se pudo crear el archivo DPX" -ForegroundColor Red
        }
    } else {
        Write-Host "  Error al convertir." -ForegroundColor Red

        if ($retryCount -lt $maxRetries) {
            Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [WARNING] Intento $retryCount falló para $($file.Name), esperando 2 segundos antes de reintentar..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
}

# VERIFICACIÓN CRÍTICA: Si falló después de todos los reintentos, DETENER TODO
if (-not $conversionSuccess) {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                          ERROR CRÍTICO - CONVERSIÓN FALLIDA                     ║" -ForegroundColor Red
    Write-Host "╠══════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Red
    Write-Host "║ Archivo: $($file.Name)" -ForegroundColor Red
    Write-Host "║ Intentos realizados: $maxRetries" -ForegroundColor Red
    Write-Host "║ Estado: TODOS LOS INTENTOS FALLARON" -ForegroundColor Red
    Write-Host "║ Acción: DETENIENDO PROCESO COMPLETO" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "El archivo '$($file.Name)' no pudo ser convertido después de $maxRetries intentos." -ForegroundColor Red
    Write-Host "Revise el archivo o los permisos y ejecute nuevamente el script." -ForegroundColor Red
    Write-Host ""
    Write-Host "PROCESO DETENIDO POR ERROR CRÍTICO" -ForegroundColor Red
    exit 1
}
```

## ⚠️ **PRECAUCIONES CRÍTICAS**

### **NO ROMPER estos elementos:**
1. **La función `Create-DPXWithMetadata`** - Ya funciona perfectamente
2. **Los timeouts de 30s** - Ya están implementados y funcionando
3. **El logging básico** - Mantener compatibilidad
4. **La estructura general** - Variables `$currentFile`, `$totalOriginalSize`, etc.

### **VALIDACIONES OBLIGATORIAS:**
1. **Sintaxis PowerShell** - Verificar con: `$ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path "script.ps1"), [ref]$null, [ref]$null)`
2. **Llaves balanceadas** - Cada `{` debe tener su `}`
3. **Sin bucles `while ($true)` anidados** - Solo uno al final del script
4. **Variables scoping** - Asegurar que `$conversionSuccess`, `$retryCount`, etc. sean locales

## 🧪 **Testing**

### **Escenario 1 - Archivo normal:**
```
Convirtiendo archivo 1 de 178... ✅ Metadata aplicada correctamente
[SUCCESS] Archivo archivo1.exr convertido exitosamente en intento 1
```

### **Escenario 2 - Archivo con problema temporal:**
```
Convirtiendo archivo 5 de 178... ❌ Error al convertir.
[RETRY] Reintentando archivo archivo5.exr (intento 2 de 3)
Convirtiendo archivo 5 de 178... ❌ Error al convertir.
[RETRY] Reintentando archivo archivo5.exr (intento 3 de 3)
Convirtiendo archivo 5 de 178... ✅ Metadata aplicada correctamente
[SUCCESS] Archivo archivo5.exr convertido exitosamente en intento 3
```

### **Escenario 3 - Archivo definitivamente corrupto:**
```
Convirtiendo archivo 10 de 178... ❌ Error al convertir.
[RETRY] Reintentando archivo archivo10.exr (intento 2 de 3)
Convirtiendo archivo 10 de 178... ❌ Error al convertir.
[RETRY] Reintentando archivo archivo10.exr (intento 3 de 3)
Convirtiendo archivo 10 de 178... ❌ Error al convertir.

╔══════════════════════════════════════════════════════════════════════════════╗
║                          ERROR CRÍTICO - CONVERSIÓN FALLIDA                     ║
║ Archivo: archivo10.exr                                                   ║
║ Intentos realizados: 3                                                   ║
║ Acción: DETENIENDO PROCESO COMPLETO                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

PROCESO DETENIDO POR ERROR CRÍTICO
```

## 📋 **Checklist de Implementación**

- [ ] Respaldar script original
- [ ] Implementar variables de reintento (`$maxRetries`, `$retryCount`, `$conversionSuccess`)
- [ ] Crear loop `while` para reintentos
- [ ] Agregar logging de reintentos
- [ ] Implementar pausa de 2 segundos entre reintentos
- [ ] Crear bloque de error crítico con `exit 1`
- [ ] Verificar sintaxis PowerShell
- [ ] Probar con archivos de prueba
- [ ] Verificar que no se rompa el flujo normal

## 🎯 **Resultado Esperado**

Un script que **NUNCA** deja archivos sin convertir, pero que tampoco se queda colgado indefinidamente. La lógica de reintento asegura robustez mientras mantiene la eficiencia.

---

**Implementador**: Por favor, lee esto detenidamente antes de modificar el código. El script actual funciona bien, pero necesita esta mejora crítica de reintentos.