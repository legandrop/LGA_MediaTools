# ______________________________________________________________________________________________________________
#
#   MOV_to_PNG_997 | Lega | v1.20
#
#   Convierte un archivo .MOV a una secuencia de archivos PNG comenzando desde el frame 0997.
#   Funcionalidades principales:
#     - Acepta archivos .MOV arrastrados al .bat.
#     - Crea una subcarpeta con el nombre del archivo MOV (sin extensión).
#     - Si la carpeta ya existe y contiene archivos, agrega un número al final.
#     - Genera una secuencia PNG numerada comenzando desde 0997 (4 dígitos).
#     - Preserva la calidad de video original en formato PNG.
#     - NUEVA: Elimina el canal alpha después de la conversión para reducir el tamaño.
#   Uso:
#     Arrastra un archivo .MOV sobre el archivo .bat, que luego llama a este script.
#     Los archivos PNG se guardan en una subcarpeta con el nombre del MOV.
#
#   Requisitos:
#     - FFmpeg debe estar instalado y configurado.
#     - OIIO debe estar instalado para la eliminación del canal alpha.
#
# ______________________________________________________________________________________________________________

# Configuración de rutas para las herramientas necesarias
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ffmpegPath = Join-Path (Split-Path -Parent $scriptDir) "FFmpeg\ffmpeg.exe"
$ffprobePath = Join-Path (Split-Path -Parent $scriptDir) "FFmpeg\ffprobe.exe"
$oiiotoolPath = Join-Path (Split-Path -Parent $scriptDir) "OIIO\oiiotool.exe"

# Función para pausar la ejecución y salir
function Pause-AndExit {
    Write-Host "Presione ESC para salir..."
    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($key.VirtualKeyCode -eq 27) {
            exit
        }
    }
}

# Función para imprimir mensajes en color en la consola
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

# Función para convertir bytes a una representación legible
function Format-FileSize {
    param ([long]$size)
    if ($size -gt 1TB) { return "{0:N2} TB" -f ($size / 1TB) }
    if ($size -gt 1GB) { return "{0:N2} GB" -f ($size / 1GB) }
    if ($size -gt 1MB) { return "{0:N2} MB" -f ($size / 1MB) }
    if ($size -gt 1KB) { return "{0:N2} KB" -f ($size / 1KB) }
    return "$size B"
}

# Verificar que desde el .bat se envió un MOV
if ($args.Count -eq 0) {
    Write-Host "Error: No se proporcionó ningún archivo .MOV como argumento."
    Pause-AndExit
}

$inputMovFile = $args[0]

if (-not (Test-Path $inputMovFile)) {
    Write-Host "Error: El archivo especificado no existe: $inputMovFile"
    Pause-AndExit
}

if (-not $inputMovFile.EndsWith('.mov', [StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "Error: El archivo especificado no es un archivo .MOV: $inputMovFile"
    Pause-AndExit
}

# Verificación de la existencia de herramientas necesarias
if (-Not (Test-Path $ffmpegPath)) {
    Write-Host "Error: No se encuentra ffmpeg.exe en la carpeta /FFmpeg/"
    Write-Host "Chequear que ffmpeg.exe exista en: $ffmpegPath"
    Pause-AndExit
}

if (-Not (Test-Path $ffprobePath)) {
    Write-Host "Error: No se encuentra ffprobe.exe en la carpeta /FFmpeg/"
    Write-Host "Chequear que ffprobe.exe exista en: $ffprobePath"
    Pause-AndExit
}

if (-Not (Test-Path $oiiotoolPath)) {
    Write-Host "Error: No se encuentra oiiotool.exe en la carpeta /OIIO/bin/"
    Write-Host "Chequear que oiiotool.exe exista en: $oiiotoolPath"
    Pause-AndExit
}

# Obtener información del archivo MOV
$movFileInfo = Get-Item $inputMovFile
$movBaseName = [System.IO.Path]::GetFileNameWithoutExtension($movFileInfo.Name)
$movDirectory = $movFileInfo.Directory.FullName

Write-ColorOutput "Procesando archivo: $($movFileInfo.Name)" "Cyan"
Write-ColorOutput "Tamaño del archivo: $(Format-FileSize $movFileInfo.Length)" "Cyan"

# Crear el nombre de la carpeta destino
$outputFolderName = $movBaseName
$outputFolderPath = Join-Path $movDirectory $outputFolderName

# Verificar si la carpeta ya existe y contiene archivos
$counter = 1
$originalOutputFolderPath = $outputFolderPath

while (Test-Path $outputFolderPath) {
    $filesInFolder = Get-ChildItem -Path $outputFolderPath -File
    if ($filesInFolder.Count -gt 0) {
        $outputFolderName = "$movBaseName" + "_$counter"
        $outputFolderPath = Join-Path $movDirectory $outputFolderName
        $counter++
    } else {
        # La carpeta existe pero está vacía, podemos usarla
        break
    }
}

# Crear el directorio destino si no existe
if (-Not (Test-Path $outputFolderPath)) {
    New-Item -Path $outputFolderPath -ItemType Directory | Out-Null
    Write-ColorOutput "Carpeta creada: $outputFolderPath" "Green"
} else {
    Write-ColorOutput "Usando carpeta existente: $outputFolderPath" "Yellow"
}

# Obtener información del video usando ffprobe
Write-ColorOutput "Obteniendo información del video..." "Yellow"
$ffprobeArgs = @(
    "-v", "quiet",
    "-print_format", "json",
    "-show_streams",
    "-select_streams", "v:0",
    $inputMovFile
)

$ffprobeResult = & $ffprobePath $ffprobeArgs | ConvertFrom-Json
$videoStream = $ffprobeResult.streams[0]

if (-not $videoStream) {
    Write-Host "Error: No se pudo obtener información del stream de video."
    Pause-AndExit
}

# Obtener el número total de frames
$totalFrames = $videoStream.nb_frames
if (-not $totalFrames) {
    # Si nb_frames no está disponible, calcularlo usando duración y frame rate
    $duration = [double]$videoStream.duration
    $frameRate = Invoke-Expression $videoStream.r_frame_rate
    $totalFrames = [math]::Floor($duration * $frameRate)
}

Write-ColorOutput "Información del video:" "Cyan"
Write-ColorOutput "  Resolución: $($videoStream.width)x$($videoStream.height)" "Cyan"
Write-ColorOutput "  Frame rate: $($videoStream.r_frame_rate) fps" "Cyan"
Write-ColorOutput "  Total de frames: $totalFrames" "Cyan"
Write-ColorOutput "  Duración: $($videoStream.duration) segundos" "Cyan"

# Configurar el patrón de salida PNG
$outputPattern = Join-Path $outputFolderPath ($movBaseName + "_%04d.png")

# Iniciar el temporizador
$startTime = Get-Date

Write-ColorOutput "Iniciando conversión a PNG..." "Yellow"
Write-ColorOutput "Los archivos comenzarán con el número 0997" "Yellow"
Write-ColorOutput "Aplicando corrección de gamma (1.015) para preservar luminancia..." "Yellow"
Write-ColorOutput "Configurando máxima calidad PNG sin compresión..." "Yellow"

# Ejecutar FFmpeg para convertir MOV a PNG con corrección de gamma y máxima calidad
$ffmpegArgs = @(
    "-i"
    $inputMovFile
    "-start_number"
    "997"
    "-pix_fmt"
    "rgba64be"
    "-compression_level"
    "8"
    "-pred"
    "mixed"
    "-color_primaries"
    "bt709"
    "-color_trc"
    "bt709"
    "-colorspace"
    "bt709"
    $outputPattern
)

Write-ColorOutput "Ejecutando conversión..." "Yellow"
$ffmpegProcess = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru

if ($ffmpegProcess.ExitCode -ne 0) {
    Write-Host "Error: FFmpeg falló durante la conversión."
    Pause-AndExit
}

# Calcular el tiempo total
$endTime = Get-Date
$totalTime = $endTime - $startTime
$formattedTime = "{0:D2}h {1:D2}m {2:D2}s" -f $totalTime.Hours, $totalTime.Minutes, $totalTime.Seconds

# Verificar los archivos creados
$createdFiles = Get-ChildItem -Path $outputFolderPath -Filter "*.png" | Sort-Object Name
$createdCount = $createdFiles.Count

if ($createdCount -eq 0) {
    Write-Host "Error: No se crearon archivos PNG."
    Pause-AndExit
}

# Calcular el tamaño total de los archivos PNG originales
$totalPngSize = ($createdFiles | Measure-Object -Property Length -Sum).Sum

Write-ColorOutput "" "Green"
Write-ColorOutput "Conversión completada exitosamente!" "Green"
Write-ColorOutput "Archivos PNG creados: $createdCount" "Green"
Write-ColorOutput "Tamaño total con alpha: $(Format-FileSize $totalPngSize)" "Green"
Write-ColorOutput "Tiempo de conversión: $formattedTime" "Green"

# NUEVA FASE: Eliminar canal alpha para reducir tamaño
Write-ColorOutput "" "Yellow"
Write-ColorOutput "Iniciando eliminación del canal alpha..." "Yellow"
Write-ColorOutput "Esto reducirá significativamente el tamaño de los archivos..." "Yellow"

$alphaRemovalStartTime = Get-Date
$processedCount = 0
$failedCount = 0

foreach ($pngFile in $createdFiles) {
    $processedCount++
    $currentFile = $pngFile.FullName
    $tempFile = $currentFile -replace "\.png$", "_temp.png"
    
    # Mostrar progreso cada 10 archivos
    if ($processedCount % 10 -eq 0 -or $processedCount -eq 1) {
        Write-ColorOutput "Procesando archivo $processedCount de $createdCount..." "Cyan"
    }
    
    try {
        # Usar OIIO para eliminar el canal alpha (convertir RGBA a RGB)
        $oiioArgs = @(
            $currentFile
            "--ch", "R,G,B"
            "-o", $tempFile
        )
        
        $oiioProcess = Start-Process -FilePath $oiiotoolPath -ArgumentList $oiioArgs -NoNewWindow -Wait -PassThru
        
        if ($oiioProcess.ExitCode -eq 0 -and (Test-Path $tempFile)) {
            # Reemplazar el archivo original con el nuevo sin alpha
            Remove-Item $currentFile -Force
            Rename-Item $tempFile $currentFile
        } else {
            Write-ColorOutput "Advertencia: Falló la eliminación de alpha en $($pngFile.Name)" "Red"
            $failedCount++
            # Limpiar archivo temporal si existe
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force
            }
        }
    }
    catch {
        Write-ColorOutput "Error procesando $($pngFile.Name): $($_.Exception.Message)" "Red"
        $failedCount++
        # Limpiar archivo temporal si existe
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
    }
}

$alphaRemovalEndTime = Get-Date
$alphaRemovalTime = $alphaRemovalEndTime - $alphaRemovalStartTime
$formattedAlphaTime = "{0:D2}h {1:D2}m {2:D2}s" -f $alphaRemovalTime.Hours, $alphaRemovalTime.Minutes, $alphaRemovalTime.Seconds

# Recalcular el tamaño después de eliminar alpha
$finalFiles = Get-ChildItem -Path $outputFolderPath -Filter "*.png" | Sort-Object Name
$finalPngSize = ($finalFiles | Measure-Object -Property Length -Sum).Sum
$sizeReduction = $totalPngSize - $finalPngSize
$reductionPercentage = [math]::Round(($sizeReduction / $totalPngSize) * 100, 1)

$totalProcessingTime = $endTime - $startTime + $alphaRemovalTime
$formattedTotalTime = "{0:D2}h {1:D2}m {2:D2}s" -f $totalProcessingTime.Hours, $totalProcessingTime.Minutes, $totalProcessingTime.Seconds

Write-ColorOutput "" "Green"
Write-ColorOutput "¡Eliminación de canal alpha completada!" "Green"
Write-ColorOutput "Archivos procesados exitosamente: $($createdCount - $failedCount)" "Green"
if ($failedCount -gt 0) {
    Write-ColorOutput "Archivos que fallaron: $failedCount" "Red"
}
Write-ColorOutput "Tiempo de eliminación de alpha: $formattedAlphaTime" "Green"
Write-ColorOutput "" "Green"
Write-ColorOutput "RESULTADOS FINALES:" "Magenta"
Write-ColorOutput "Tamaño original (con alpha): $(Format-FileSize $totalPngSize)" "Cyan"
Write-ColorOutput "Tamaño final (sin alpha): $(Format-FileSize $finalPngSize)" "Green"
Write-ColorOutput "Reducción de tamaño: $(Format-FileSize $sizeReduction) ($reductionPercentage%)" "Green"
Write-ColorOutput "Tiempo total de procesamiento: $formattedTotalTime" "Green"
Write-ColorOutput "" "Green"
Write-ColorOutput "Primer archivo: $($finalFiles[0].Name)" "Cyan"
Write-ColorOutput "Último archivo: $($finalFiles[-1].Name)" "Cyan"
Write-ColorOutput "" "Green"
Write-ColorOutput "Los archivos PNG están en:" "Yellow"
Write-ColorOutput "$outputFolderPath" "Yellow"

Pause-AndExit 