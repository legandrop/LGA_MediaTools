# ______________________________________________________________________________________________________________
#
#   EXR_to_DPX | Lega | v1.5 TIMEOUT FIXED
#
#   Convierte archivos EXR (generados por DPX_to_EXR_DWAA.ps1) de vuelta a DPX.
#   RECUPERA TODA la metadata original del DPX desde el EXR.
#   Reconstruye un DPX profesional con metadata completa.
#   Utiliza la herramienta oiiotool para realizar la conversión.
#   Uso:
#       La carpeta de origen con los archivos EXR se arrastra al archivo .bat, que luego llama a este script.
#       La salida se guarda en una nueva carpeta con el sufijo _dpx.
#
#   v1.5 TIMEOUT FIXED - Control robusto de procesos iinfo/oiiotool con timeout 30s
#                       + Prevención de procesos huérfanos + Logging mejorado con tiempos
#                       + Reconstrucción binaria del header DPX + metadata embebida (lga:DPXHeaderZ)
# ______________________________________________________________________________________________________________

# Obtener la ruta del script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$oiiotoolPath = Join-Path $scriptDir "..\OIIO\oiiotool.exe"
$iinfoBinary = Join-Path $scriptDir "..\OIIO\iinfo.exe"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function ConvertTo-UInt32 {
    param (
        [byte[]]$bytes,
        [bool]$isBigEndian
    )
    $working = $bytes.Clone()
    if ($isBigEndian -and [BitConverter]::IsLittleEndian) {
        [Array]::Reverse($working)
    } elseif (-not $isBigEndian -and -not [BitConverter]::IsLittleEndian) {
        [Array]::Reverse($working)
    }
    return [BitConverter]::ToUInt32($working, 0)
}

function Set-UInt32Bytes {
    param (
        [byte[]]$buffer,
        [int]$offset,
        [uint32]$value,
        [bool]$isBigEndian
    )
    $bytes = [BitConverter]::GetBytes($value)
    if ($isBigEndian -and [BitConverter]::IsLittleEndian) {
        [Array]::Reverse($bytes)
    } elseif (-not $isBigEndian -and -not [BitConverter]::IsLittleEndian) {
        [Array]::Reverse($bytes)
    }
    [Array]::Copy($bytes, 0, $buffer, $offset, 4)
}

function Decompress-Base64Bytes {
    param ([string]$base64String)
    $compressedBytes = [Convert]::FromBase64String($base64String)
    $inputStream = New-Object System.IO.MemoryStream(,$compressedBytes)
    $deflateStream = New-Object System.IO.Compression.DeflateStream(
        $inputStream,
        [System.IO.Compression.CompressionMode]::Decompress
    )
    $outputStream = New-Object System.IO.MemoryStream
    $buffer = New-Object byte[] 4096
    while (($read = $deflateStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $outputStream.Write($buffer, 0, $read)
    }
    $deflateStream.Dispose()
    $inputStream.Dispose()
    $result = $outputStream.ToArray()
    $outputStream.Dispose()
    return $result
}

function Swap-BytePairs {
    param ([byte[]]$buffer)
    for ($i = 0; $i -lt $buffer.Length - 1; $i += 2) {
        $tmp = $buffer[$i]
        $buffer[$i] = $buffer[$i + 1]
        $buffer[$i + 1] = $tmp
    }
}

function Set-FixedAsciiString {
    param (
        [byte[]]$buffer,
        [int]$offset,
        [int]$length,
        [string]$text
    )
    $ascii = [System.Text.Encoding]::ASCII.GetBytes($text)
    # Limpiar bloque
    for ($i = 0; $i -lt $length; $i++) {
        $buffer[$offset + $i] = 0
    }
    $max = [Math]::Min($length, $ascii.Length)
    [Array]::Copy($ascii, 0, $buffer, $offset, $max)
}

# Verificar si oiiotool.exe existe en esa ruta
if (-Not (Test-Path $oiiotoolPath)) {
    Write-Host "Error: No se encuentra oiiotool.exe en la misma carpeta que este script."
    Write-Host "Chequear que oiiotool.exe exista en: $scriptDir"
    Write-Host "Presione ESC para salir"
    while ($true) { if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 27) { exit } }
}

# Obtener el directorio de origen
$sourcePath = $args[0]
if (-Not $sourcePath) {
    Write-Host "Error: Hay que arrastrar una carpeta con EXRs al archivo EXR_to_DPX.bat"
    Write-Host "Presione ESC para salir"
    while ($true) { if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 27) { exit } }
}

$sourceName = Split-Path $sourcePath -Leaf
$sourceDir = Split-Path $sourcePath -Parent

if (-Not (Test-Path -Path $sourcePath -PathType Container)) {
    Write-Host "Error: El elemento arrastrado al .bat no es una carpeta."
    Write-Host "Presione ESC para salir"
    while ($true) { if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 27) { exit } }
}

# Definir nombre de la carpeta destino
$destName = "${sourceName}_dpx"
$destPath = Join-Path $sourceDir $destName

# Crear el directorio destino si no existe
if (-Not (Test-Path $destPath)) {
    New-Item -Path $destPath -ItemType Directory | Out-Null
}

# Contar archivos EXR
$files = Get-ChildItem -Path $sourcePath -Filter "*.exr"
$fileCount = $files.Count

if ($fileCount -eq 0) {
    Write-Host "No se encontraron archivos .exr en la carpeta seleccionada."
    Write-Host "Presione ESC para salir"
    while ($true) { if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 27) { exit } }
}

# Inicializar contador y variables para el tamaño total
$currentFile = 0
$totalOriginalSize = 0
$totalConvertedSize = 0

# Función para convertir bytes a una representación legible
function Format-FileSize {
    param ([long]$size)
    if ($size -gt 1TB) { return "{0:N2} TB" -f ($size / 1TB) }
    if ($size -gt 1GB) { return "{0:N2} GB" -f ($size / 1GB) }
    if ($size -gt 1MB) { return "{0:N2} MB" -f ($size / 1MB) }
    if ($size -gt 1KB) { return "{0:N2} KB" -f ($size / 1KB) }
    return "$size B"
}

function Create-DPXWithMetadata {
    param ([string]$exrPath, [string]$dpxPath)

    Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Create-DPXWithMetadata: Iniciando para $exrPath" -ForegroundColor Magenta

    try {
        Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Create-DPXWithMetadata: Iniciando lectura de metadata con iinfo (timeout 30s)" -ForegroundColor Magenta

        # EJECUCIÓN CONTROLADA CON TIMEOUT PARA EVITAR PROCESOS HUÉRFANOS
        $job = Start-Job -ScriptBlock {
            param($bin, $path)
            try {
                $result = & $bin -v $path 2>$null
                return @{ Output = $result; ExitCode = $LASTEXITCODE }
            } catch {
                return @{ Output = $null; ExitCode = -1; Error = $_.Exception.Message }
            }
        } -ArgumentList $iinfoBinary, $exrPath

        $timeoutSeconds = 30
        $startWaitTime = Get-Date
        Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Esperando finalización de iinfo..." -ForegroundColor Cyan

        $jobCompleted = $job | Wait-Job -Timeout $timeoutSeconds
        $waitDuration = [math]::Round(((Get-Date) - $startWaitTime).TotalSeconds, 2)

        if ($jobCompleted) {
            Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] iinfo completado exitosamente en ${waitDuration}s" -ForegroundColor Green
            $jobResult = Receive-Job $job
            $metadataLines = $jobResult.Output
            $exitCode = $jobResult.ExitCode

            if ($exitCode -ne 0) {
                Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [ERROR] iinfo falló con código de salida $exitCode" -ForegroundColor Red
                Remove-Job $job
                return $false
            }
        } else {
            Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [ERROR] iinfo excedió timeout de ${timeoutSeconds}s (esperó ${waitDuration}s), forzando terminación" -ForegroundColor Red
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job
            return $false
        }

        Remove-Job $job

        $metadataText = $metadataLines -join "`n"
        Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Create-DPXWithMetadata: Metadata leída correctamente (${metadataLines.Count} líneas)" -ForegroundColor Magenta

        $headerMatch = [regex]::Match($metadataText, 'lga:DPXHeaderZ:\s*"([^"]*)"')
        $headerSizeMatch = [regex]::Match($metadataText, 'lga:DPXHeaderSize:\s*(\d+)')
        $magicMatch = [regex]::Match($metadataText, 'lga:DPXMagic:\s*"([^"]*)"')

        if (-not ($headerMatch.Success -and $headerSizeMatch.Success)) {
            Write-Host "  Advertencia: El EXR no contiene la cabecera DPX comprimida necesaria" -ForegroundColor Yellow
            return $false
        }

        $headerBase64 = $headerMatch.Groups[1].Value
        $headerSize = [int]$headerSizeMatch.Groups[1].Value
        $originalMagic = "SDPX"
        if ($magicMatch.Success) {
            $originalMagic = $magicMatch.Groups[1].Value
        }
        $originalBigEndian = $originalMagic -eq "SDPX"

        $headerBytes = Decompress-Base64Bytes -base64String $headerBase64
        if ($headerBytes.Length -ne $headerSize) {
            $targetBytes = New-Object byte[] $headerSize
            $copyLength = [Math]::Min($headerBytes.Length, $headerSize)
            [Array]::Copy($headerBytes, 0, $targetBytes, 0, $copyLength)
            $headerBytes = $targetBytes
        }

        # Convertir EXR a un DPX temporal (solo para obtener los píxeles)
        Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Create-DPXWithMetadata: Iniciando conversión con oiiotool" -ForegroundColor Magenta
        $tempDPX = "$dpxPath.tmp.dpx"
        if (Test-Path $tempDPX) { Remove-Item $tempDPX -Force }
        $arguments = "`"$exrPath`" -d uint16 -o `"$tempDPX`""
        $process = Start-Process -FilePath $oiiotoolPath -ArgumentList $arguments -NoNewWindow -Wait -PassThru

        # VALIDACIÓN ROBUSTA DEL ARCHIVO TEMPORAL
        if ($process.ExitCode -ne 0) {
            Write-Host "  Error: oiiotool falló con código $($process.ExitCode)" -ForegroundColor Red
            return $false
        }

        if (-not (Test-Path $tempDPX)) {
            Write-Host "  Error: oiiotool no creó archivo temporal" -ForegroundColor Red
            return $false
        }

        # NUEVO: Verificar que el archivo temporal tenga contenido válido
        $tempFileInfo = Get-Item $tempDPX
        if ($tempFileInfo.Length -eq 0) {
            Write-Host "  Error: DPX temporal creado pero está vacío ($($tempFileInfo.Length) bytes)" -ForegroundColor Red
            Remove-Item $tempDPX -Force -ErrorAction SilentlyContinue
            return $false
        }

        if ($tempFileInfo.Length -lt 1000000) {  # Menos de 1MB es sospechoso
            Write-Host "  Advertencia: DPX temporal muy pequeño ($($tempFileInfo.Length) bytes)" -ForegroundColor Yellow
        }

        Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Create-DPXWithMetadata: DPX temporal creado correctamente" -ForegroundColor Magenta

        $tempBytes = [System.IO.File]::ReadAllBytes($tempDPX)
        Remove-Item $tempDPX -Force

        $tempMagic = [System.Text.Encoding]::ASCII.GetString($tempBytes, 0, 4)
        $tempBigEndian = $tempMagic -eq "SDPX"

        $tempOffsetBytes = New-Object byte[] 4
        [Array]::Copy($tempBytes, 4, $tempOffsetBytes, 0, 4)
        $tempDataOffset = ConvertTo-UInt32 -bytes $tempOffsetBytes -isBigEndian $tempBigEndian

        $pixelLength = $tempBytes.Length - $tempDataOffset
        if ($pixelLength -le 0) {
            Write-Host "  Error: El DPX temporal no contiene datos de imagen válidos" -ForegroundColor Red
            return $false
        }
        $pixelData = New-Object byte[] $pixelLength
        [Array]::Copy($tempBytes, $tempDataOffset, $pixelData, 0, $pixelLength)

        if ($originalBigEndian -and -not $tempBigEndian) {
            Swap-BytePairs -buffer $pixelData
        } elseif (-not $originalBigEndian -and $tempBigEndian) {
            Swap-BytePairs -buffer $pixelData
        }

        $finalSize = [uint32]($headerBytes.Length + $pixelData.Length)
        Set-UInt32Bytes -buffer $headerBytes -offset 16 -value $finalSize -isBigEndian $originalBigEndian

        # Actualizar Creator para reflejar la tool utilizada
        Set-FixedAsciiString -buffer $headerBytes -offset 160 -length 100 -text "LGA EXR_to_DPX v1.5 TIMEOUT"

        Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Create-DPXWithMetadata: Escribiendo archivo final $dpxPath" -ForegroundColor Magenta
        $fileStream = [System.IO.File]::Open($dpxPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $fileStream.Write($headerBytes, 0, $headerBytes.Length)
            $fileStream.Write($pixelData, 0, $pixelData.Length)
        }
        finally {
            $fileStream.Dispose()
        }

        Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Create-DPXWithMetadata: Completado exitosamente" -ForegroundColor Magenta
        return $true
    }
    catch {
        Write-Host "  Error creando DPX: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Iniciar el temporizador
$startTime = Get-Date

Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Script iniciado - procesando $fileCount archivos EXR" -ForegroundColor Yellow

# Procesar archivos EXR
foreach ($file in $files) {
    Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Iniciando procesamiento de archivo $currentFile" -ForegroundColor Cyan

    $currentFile++
    $fileName = $file.BaseName

    # Convertir nombre: quitar _exr si existe y agregar .dpx
    if ($fileName -match '_(\d+)$') {
        # Si termina con _número, quitar el guión bajo y usar el número
        $fileName = $fileName -replace '_(\d+)$', '.$1'
    }

    $outputPath = Join-Path $destPath "$fileName.dpx"

    Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Nombre convertido: $fileName.dpx" -ForegroundColor Cyan
    Write-Host "Convirtiendo archivo $currentFile de $fileCount..." -NoNewline -ForegroundColor DarkYellow

    $originalSize = (Get-Item $file.FullName).Length
    $totalOriginalSize += $originalSize

    # LÓGICA DE REINTENTO CRÍTICA - NUNCA DEJAR UN ARCHIVO SIN CONVERTIR
    $maxRetries = 3
    $retryCount = 0
    $conversionSuccess = $false

    while ($retryCount -lt $maxRetries -and -not $conversionSuccess) {
        $retryCount++

        if ($retryCount -gt 1) {
            Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [RETRY] Reintentando archivo $($file.Name) (intento $retryCount de $maxRetries)" -ForegroundColor Yellow
        }

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

                if ($retryCount -lt $maxRetries) {
                    Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [WARNING] Intento $retryCount falló para $($file.Name), esperando 2 segundos antes de reintentar..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
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
        Write-Host "==================================================================================" -ForegroundColor Red
        Write-Host "                    ERROR CRITICO - CONVERSION FALLIDA" -ForegroundColor Red
        Write-Host "==================================================================================" -ForegroundColor Red
        Write-Host "Archivo: $($file.Name)" -ForegroundColor Red
        Write-Host "Intentos realizados: $maxRetries" -ForegroundColor Red
        Write-Host "Estado: TODOS LOS INTENTOS FALLARON" -ForegroundColor Red
        Write-Host "Accion: DETENIENDO PROCESO COMPLETO" -ForegroundColor Red
        Write-Host "==================================================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "El archivo '$($file.Name)' no pudo ser convertido despues de $maxRetries intentos." -ForegroundColor Red
        Write-Host "Revise el archivo o los permisos y ejecute nuevamente el script." -ForegroundColor Red
        Write-Host ""
        Write-Host "PROCESO DETENIDO POR ERROR CRITICO" -ForegroundColor Red
        exit 1
    }

    Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Finalizado procesamiento de archivo $currentFile" -ForegroundColor Green
}

# Calcular el tiempo total
$endTime = Get-Date
$totalTime = $endTime - $startTime
$formattedTime = "{0:D2}h {1:D2}m {2:D2}s" -f $totalTime.Hours, $totalTime.Minutes, $totalTime.Seconds

Write-Host "$(Get-Date -Format 'HH:mm:ss.fff'): [DEBUG] Script completado exitosamente" -ForegroundColor Yellow

# Mensaje final - Completado
$totalOriginalSizeFormatted = Format-FileSize $totalOriginalSize
$totalConvertedSizeFormatted = Format-FileSize $totalConvertedSize
Write-Host ""
Write-Host "Conversión completada con limpieza de recursos" -ForegroundColor DarkGreen
Write-Host "$totalOriginalSizeFormatted -> $totalConvertedSizeFormatted" -ForegroundColor DarkGreen
Write-Host "Tiempo Total: $formattedTime" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Los archivos convertidos están en:" -ForegroundColor DarkYellow
Write-Host "$destPath" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "Presione ESC para salir" -ForegroundColor DarkYellow
while ($true) { if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 27) { exit } }