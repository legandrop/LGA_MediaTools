# ______________________________________________________________________________________________________________
#
#   Convierte secuencias EXR en ACES 2065-1 a archivos MOV en Rec.709 usando ProRes LT.
#   Utiliza FFmpeg con filtros de OpenColorIO para la conversión de color y compresión ProRes LT.
#   Uso: 
#       La carpeta de origen con la secuencia EXR se arrastra al archivo .bat, que luego llama a este script.
#       El archivo MOV se guarda en el directorio padre de la carpeta arrastrada.
#
#   Lega - 2024 - v1.0
# ______________________________________________________________________________________________________________

# Obtener la ruta del script y configurar rutas de herramientas
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ffmpegPath = Join-Path (Split-Path -Parent $scriptDir) "FFmpeg\ffmpeg.exe"
$ffprobePath = Join-Path (Split-Path -Parent $scriptDir) "FFmpeg\ffprobe.exe"
$oiiotoolPath = Join-Path (Split-Path -Parent $scriptDir) "OIIO\oiiotool.exe"
$ocioConfigPath = Join-Path (Split-Path -Parent $scriptDir) "OCIO\aces_1.2\config.ocio"

# Configuración de la variable de entorno OCIO para el manejo de color
$env:OCIO = $ocioConfigPath

# Función para pausar la ejecución y salir
function Pause-AndExit {
    Write-Host "Presione ESC para salir..." -ForegroundColor Yellow
    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($key.VirtualKeyCode -eq 27) {
            exit
        }
    }
}

# Función para imprimir mensajes en color
function Write-ColorOutput {
    param (
        [string]$message,
        [string]$color
    )
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $color
    Write-Output $message
    $host.UI.RawUI.ForegroundColor = $originalColor
}

# Función para formatear tamaños de archivo
function Format-FileSize {
    param ([long]$size)
    if ($size -gt 1TB) { return "{0:N2} TB" -f ($size / 1TB) }
    if ($size -gt 1GB) { return "{0:N2} GB" -f ($size / 1GB) }
    if ($size -gt 1MB) { return "{0:N2} MB" -f ($size / 1MB) }
    if ($size -gt 1KB) { return "{0:N2} KB" -f ($size / 1KB) }
    return "$size B"
}

# Verificar argumentos
if ($args.Count -eq 0) {
    Write-ColorOutput "Error: No se proporcionó ninguna carpeta como argumento." "Red"
    Pause-AndExit
}

$sourcePath = $args[0]

if (-not (Test-Path $sourcePath)) {
    Write-ColorOutput "Error: La carpeta especificada no existe: $sourcePath" "Red"
    Pause-AndExit
}

if (-not (Test-Path -Path $sourcePath -PathType Container)) {
    Write-ColorOutput "Error: El elemento arrastrado no es una carpeta." "Red"
    Pause-AndExit
}

# Verificación de la existencia de herramientas necesarias
if (-Not (Test-Path $ffmpegPath)) {
    Write-ColorOutput "Error: No se encuentra ffmpeg.exe en la carpeta /FFmpeg/" "Red"
    Write-ColorOutput "Chequear que ffmpeg.exe exista en: $ffmpegPath" "Red"
    Pause-AndExit
}

if (-Not (Test-Path $ffprobePath)) {
    Write-ColorOutput "Error: No se encuentra ffprobe.exe en la carpeta /FFmpeg/" "Red"
    Write-ColorOutput "Chequear que ffprobe.exe exista en: $ffprobePath" "Red"
    Pause-AndExit
}

if (-Not (Test-Path $oiiotoolPath)) {
    Write-ColorOutput "Error: No se encuentra oiiotool.exe en la carpeta /OIIO/" "Red"
    Write-ColorOutput "Chequear que oiiotool.exe exista en: $oiiotoolPath" "Red"
    Pause-AndExit
}

if (-Not (Test-Path $ocioConfigPath)) {
    Write-ColorOutput "Error: No se encuentra el archivo de configuración OCIO en: $ocioConfigPath" "Red"
    Pause-AndExit
}

# Obtener información de la carpeta
$sourceName = Split-Path $sourcePath -Leaf
$parentDir = Split-Path $sourcePath -Parent
$outputMovPath = Join-Path $parentDir "$sourceName.MOV"

Write-ColorOutput "=== EXR to MOV LT Converter ===" "Cyan"
Write-ColorOutput "Carpeta origen: $sourcePath" "Green"
Write-ColorOutput "Archivo destino: $outputMovPath" "Green"

# Buscar archivos EXR en la carpeta
$exrFiles = Get-ChildItem -Path $sourcePath -Filter "*.exr" | Sort-Object Name
$fileCount = $exrFiles.Count

if ($fileCount -eq 0) {
    Write-ColorOutput "Error: No se encontraron archivos EXR en la carpeta especificada." "Red"
    Pause-AndExit
}

Write-ColorOutput "Archivos EXR encontrados: $fileCount" "Yellow"

# Obtener el primer archivo para determinar el patrón de nomenclatura
$firstFile = $exrFiles[0]
$fileName = $firstFile.BaseName

# Extraer el frame number del primer archivo
if ($fileName -match '(\d+)$') {
    $firstFrameNumber = [int]$Matches[1]
    $frameDigits = $Matches[1].Length
    $basePattern = $fileName -replace '\d+$', ''
    
    Write-ColorOutput "Patrón detectado: $basePattern" "Yellow"
    Write-ColorOutput "Primer frame: $firstFrameNumber" "Yellow"
    Write-ColorOutput "Dígitos de frame: $frameDigits" "Yellow"
} else {
    Write-ColorOutput "Error: No se pudo detectar el patrón de numeración de frames en: $fileName" "Red"
    Pause-AndExit
}

# Verificar que ya no existe el archivo de salida
if (Test-Path $outputMovPath) {
    Write-ColorOutput "Advertencia: El archivo de salida ya existe y será sobrescrito: $outputMovPath" "Yellow"
}

# Crear el patrón de entrada para FFmpeg
$inputPattern = Join-Path $sourcePath "$basePattern%0$($frameDigits)d.exr"

Write-ColorOutput "Iniciando conversión..." "Yellow"
Write-ColorOutput "Patrón de entrada: $inputPattern" "Cyan"

# Iniciar el temporizador
$startTime = Get-Date

Write-ColorOutput "Convirtiendo espacio de color EXR de ACES 2065-1 a Rec.709..." "Yellow"

# Paso 1: Convertir cada frame EXR usando oiiotool para conversión de color
$tempDir = Join-Path $parentDir "temp_converted_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -Path $tempDir -ItemType Directory | Out-Null

Write-ColorOutput "Creando archivos temporales en: $tempDir" "DarkYellow"

$currentFile = 0
foreach ($file in $exrFiles) {
    $currentFile++
    $fileName = $file.BaseName
    $tempOutputPath = Join-Path $tempDir "$fileName.exr"
    
    Write-Host "Procesando archivo $currentFile de $fileCount`: $($file.Name)" -ForegroundColor DarkYellow
    
    # Usar oiiotool para convertir el espacio de color
    $oiioArgs = @(
        $file.FullName,
        "--colorconvert", "`"ACES - ACES2065-1`"", "`"Output - Rec.709`"",
        "-o", $tempOutputPath
    )
    
    $oiioProcess = Start-Process -FilePath $oiiotoolPath -ArgumentList $oiioArgs -NoNewWindow -Wait -PassThru
    
    if ($oiioProcess.ExitCode -ne 0) {
        Write-ColorOutput "Error convirtiendo $($file.Name) con oiiotool" "Red"
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Pause-AndExit
    }
}

Write-ColorOutput "Creando archivo MOV con FFmpeg..." "Yellow"

# Paso 2: Usar FFmpeg para crear el MOV desde los archivos temporales convertidos
$tempPattern = Join-Path $tempDir "$basePattern%0$($frameDigits)d.exr"

$ffmpegArgs = @(
    "-start_number", $firstFrameNumber.ToString(),
    "-i", $tempPattern,
    "-c:v", "prores_ks",
    "-profile:v", "1",
    "-pix_fmt", "yuv422p10le",
    "-y", 
    $outputMovPath
)

try {
    # Ejecutar FFmpeg
    $process = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
    
    if ($process.ExitCode -eq 0) {
        # Limpiar archivos temporales
        Write-ColorOutput "Limpiando archivos temporales..." "DarkYellow"
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        # Calcular el tiempo total
        $endTime = Get-Date
        $totalTime = $endTime - $startTime
        $formattedTime = "{0:D2}h {1:D2}m {2:D2}s" -f $totalTime.Hours, $totalTime.Minutes, $totalTime.Seconds
        
        # Obtener tamaño del archivo de salida
        if (Test-Path $outputMovPath) {
            $outputSize = (Get-Item $outputMovPath).Length
            $outputSizeFormatted = Format-FileSize $outputSize
            
            Write-ColorOutput "" "Green"
            Write-ColorOutput "=== Conversion completada exitosamente ===" "Green"
            Write-ColorOutput "Archivo generado: $outputMovPath" "Green"
            Write-ColorOutput "Tamaño: $outputSizeFormatted" "Green"
            Write-ColorOutput "Tiempo total: $formattedTime" "Green"
            Write-ColorOutput "Frames procesados: $fileCount" "Green"
            Write-ColorOutput "Conversion de color: ACES 2065-1 -> Rec.709 (via OCIO)" "Green"
            Write-ColorOutput "Proceso: oiiotool + FFmpeg" "Green"
        } else {
            Write-ColorOutput "Error: El archivo de salida no se generó correctamente." "Red"
        }
    } else {
        Write-ColorOutput "Error: FFmpeg falló con código de salida: $($process.ExitCode)" "Red"
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-ColorOutput "Error durante la ejecución de FFmpeg: $($_.Exception.Message)" "Red"
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-ColorOutput "" "Yellow"
Pause-AndExit 