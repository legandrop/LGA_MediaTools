# ______________________________________________________________________________________________________________
#
#   EXR_to_DPX | Lega | v1.1
#
#   Convierte archivos EXR (generados por DPX_to_EXR_DWAA.ps1) de vuelta a DPX.
#   RECUPERA TODA la metadata original del DPX desde el EXR.
#   Reconstruye un DPX profesional con metadata completa.
#   Utiliza la herramienta oiiotool para realizar la conversión.
#   Uso:
#       La carpeta de origen con los archivos EXR se arrastra al archivo .bat, que luego llama a este script.
#       La salida se guarda en una nueva carpeta con el sufijo _dpx.
#
#   v1.1 - Reconstrucción binaria del header DPX + metadata embebida (lga:DPXHeaderZ)
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

    try {
        $metadataLines = & $iinfoBinary -v $exrPath 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Advertencia: No se pudo leer metadata del EXR" -ForegroundColor Yellow
            return $false
        }
        $metadataText = $metadataLines -join "`n"

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
        $tempDPX = "$dpxPath.tmp.dpx"
        if (Test-Path $tempDPX) { Remove-Item $tempDPX -Force }
        $arguments = "`"$exrPath`" -d uint16 -o `"$tempDPX`""
        $process = Start-Process -FilePath $oiiotoolPath -ArgumentList $arguments -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0 -or -not (Test-Path $tempDPX)) {
            Write-Host "  Error generando DPX temporal (código $($process.ExitCode))" -ForegroundColor Red
            return $false
        }

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
        Set-FixedAsciiString -buffer $headerBytes -offset 160 -length 100 -text "LGA EXR_to_DPX v1.0"

        $fileStream = [System.IO.File]::Open($dpxPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $fileStream.Write($headerBytes, 0, $headerBytes.Length)
            $fileStream.Write($pixelData, 0, $pixelData.Length)
        }
        finally {
            $fileStream.Dispose()
        }

        return $true
    }
    catch {
        Write-Host "  Error creando DPX: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}


# Iniciar el temporizador
$startTime = Get-Date

# Procesar archivos EXR
foreach ($file in $files) {
    $currentFile++
    $fileName = $file.BaseName

    # Convertir nombre: quitar _exr si existe y agregar .dpx
    if ($fileName -match '_(\d+)$') {
        # Si termina con _número, quitar el guión bajo y usar el número
        $fileName = $fileName -replace '_(\d+)$', '.$1'
    }

    $outputPath = Join-Path $destPath "$fileName.dpx"

    Write-Host "Convirtiendo archivo $currentFile de $fileCount..." -NoNewline -ForegroundColor DarkYellow

    $originalSize = (Get-Item $file.FullName).Length
    $totalOriginalSize += $originalSize

    # Crear DPX con metadata completa en una sola operación
    if (Create-DPXWithMetadata -exrPath $file.FullName -dpxPath $outputPath) {
        if (Test-Path $outputPath) {
            $convertedSize = (Get-Item $outputPath).Length
            $totalConvertedSize += $convertedSize

            $originalSizeFormatted = Format-FileSize $originalSize
            $convertedSizeFormatted = Format-FileSize $convertedSize
            Write-Host "  $originalSizeFormatted -> $convertedSizeFormatted" -ForegroundColor DarkYellow
            Write-Host "  Metadata aplicada correctamente" -ForegroundColor Green
        } else {
            Write-Host "  Error: No se pudo crear el archivo DPX" -ForegroundColor Red
        }
    } else {
        Write-Host "  Error al convertir." -ForegroundColor Red
    }
}

# Calcular el tiempo total
$endTime = Get-Date
$totalTime = $endTime - $startTime
$formattedTime = "{0:D2}h {1:D2}m {2:D2}s" -f $totalTime.Hours, $totalTime.Minutes, $totalTime.Seconds

# Mensaje final - Completado
$totalOriginalSizeFormatted = Format-FileSize $totalOriginalSize
$totalConvertedSizeFormatted = Format-FileSize $totalConvertedSize
Write-Host ""
Write-Host "Conversión completada" -ForegroundColor DarkGreen
Write-Host "$totalOriginalSizeFormatted -> $totalConvertedSizeFormatted" -ForegroundColor DarkGreen
Write-Host "Tiempo Total: $formattedTime" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Los archivos convertidos están en:" -ForegroundColor DarkYellow
Write-Host "$destPath" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "Presione ESC para salir" -ForegroundColor DarkYellow
while ($true) { if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 27) { exit } }