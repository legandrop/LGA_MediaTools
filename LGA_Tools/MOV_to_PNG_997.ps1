# ______________________________________________________________________________________________________________
#
#   Convierte un archivo .MOV a una secuencia de archivos PNG comenzando desde el frame 0997.
#   Funcionalidades principales:
#     - Acepta archivos .MOV arrastrados al .bat.
#     - Crea una subcarpeta con el nombre del archivo MOV (sin extensión).
#     - Si la carpeta ya existe y contiene archivos, agrega un número al final.
#     - Genera una secuencia PNG numerada comenzando desde 0997 (4 dígitos).
#     - Preserva la calidad de video original en formato PNG.
#   Uso:
#     Arrastra un archivo .MOV sobre el archivo .bat, que luego llama a este script.
#     Los archivos PNG se guardan en una subcarpeta con el nombre del MOV.
#
#   Requisitos:
#     - FFmpeg debe estar instalado y configurado.
#
#   Lega - v1.0
# ______________________________________________________________________________________________________________

# Configuración de rutas para las herramientas necesarias
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ffmpegPath = Join-Path (Split-Path -Parent $scriptDir) "FFmpeg\ffmpeg.exe"
$ffprobePath = Join-Path (Split-Path -Parent $scriptDir) "FFmpeg\ffprobe.exe"

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

# Ejecutar FFmpeg para convertir MOV a PNG
$ffmpegArgs = @(
    "-i"
    $inputMovFile
    "-start_number"
    "997"
    "-q:v"
    "1"
    "-pix_fmt"
    "rgb24"
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

# Calcular el tamaño total de los archivos PNG
$totalPngSize = ($createdFiles | Measure-Object -Property Length -Sum).Sum

Write-ColorOutput "" "Green"
Write-ColorOutput "Conversión completada exitosamente!" "Green"
Write-ColorOutput "Archivos PNG creados: $createdCount" "Green"
Write-ColorOutput "Tamaño total: $(Format-FileSize $totalPngSize)" "Green"
Write-ColorOutput "Tiempo total: $formattedTime" "Green"
Write-ColorOutput "" "Green"
Write-ColorOutput "Primer archivo: $($createdFiles[0].Name)" "Cyan"
Write-ColorOutput "Último archivo: $($createdFiles[-1].Name)" "Cyan"
Write-ColorOutput "" "Green"
Write-ColorOutput "Los archivos PNG están en:" "Yellow"
Write-ColorOutput "$outputFolderPath" "Yellow"

Pause-AndExit 