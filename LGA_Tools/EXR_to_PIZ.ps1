# ______________________________________________________________________________________________________________
#
#   EXR_to_PIZ | Lega | v1.00
#
#   Convierte archivos EXR de cualquier compresion a compresion PIZ.
#   Utiliza la herramienta oiiotool para realizar la conversion.
#   Uso: 
#       La carpeta de origen con los archivos EXR se arrastra al archivo .bat, que luego llama a este script.
#       La salida se guarda en una nueva carpeta con la compresión PIZ aplicada.
#       Si la carpeta o archivos originales contienen en su nombre "dwaa", se cambiará el nombre por "piz".
#       Si no contienen "dwaa", se agregará "piz" al final del nombre de la carpeta (no de los archivos).
#
# ______________________________________________________________________________________________________________

# Obtener la ruta del script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$oiiotoolPath = Join-Path $scriptDir "..\OIIO\oiiotool.exe"

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
    Write-Host "Error: Hay que arrastrar una carpeta con EXRs al archivo EXR_to_PIZ.bat"
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

# Cambiar el nombre si contiene "dwaa"
if ($sourceName -like "*dwaa*") {
    $destName = $sourceName -replace "dwaa", "piz"
} else {
    $destName = "$sourceName-piz"
}

$destPath = Join-Path $sourceDir $destName

# Crear el directorio destino si no existe
if (-Not (Test-Path $destPath)) {
    New-Item -Path $destPath -ItemType Directory | Out-Null
}

# Contar archivos EXR
$files = Get-ChildItem -Path $sourcePath -Filter "*.exr"
$fileCount = $files.Count

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

# Iniciar el temporizador
$startTime = Get-Date

# Procesar archivos EXR
foreach ($file in $files) {
    $currentFile++
    $fileName = $file.BaseName

    # Aplicar renombrado de canales
    $fileName = $fileName -replace "FinalImageMovieRenderQueue_", ""
    $fileName = $fileName -replace "ActorHitProxyMask", "Cryptomatte"
    if ($fileName -eq "FinalImagePPM_MRQ_05_SceneDepth") {
        $fileName = "MRQ_SceneDepth"
    }

    $newFileName = if ($fileName -like "*dwaa*") { $fileName -replace "dwaa", "piz" } else { $fileName }
    $outputPath = "$destPath\$newFileName$($file.Extension)"
    
    Write-Host "Convirtiendo archivo $currentFile de $fileCount..." -NoNewline -ForegroundColor DarkYellow
    
    $originalSize = (Get-Item $file.FullName).Length
    $totalOriginalSize += $originalSize
    
    # Usar Start-Process para manejar los espacios en las rutas
    $arguments = """$($file.FullName)"" --compression piz -o ""$outputPath"""
    Start-Process -FilePath $oiiotoolPath -ArgumentList $arguments -NoNewWindow -Wait
    
    $convertedSize = (Get-Item $outputPath).Length
    $totalConvertedSize += $convertedSize
    
    $originalSizeFormatted = Format-FileSize $originalSize
    $convertedSizeFormatted = Format-FileSize $convertedSize
    Write-Host "  $originalSizeFormatted -> $convertedSizeFormatted" -ForegroundColor DarkYellow
}

# Calcular el tiempo total
$endTime = Get-Date
$totalTime = $endTime - $startTime
$formattedTime = "{0:D2}h {1:D2}m {2:D2}s" -f $totalTime.Hours, $totalTime.Minutes, $totalTime.Seconds

# Mensaje final - Completado
$totalOriginalSizeFormatted = Format-FileSize $totalOriginalSize
$totalConvertedSizeFormatted = Format-FileSize $totalConvertedSize
Write-Host ""
Write-Host "Conversion completada" -ForegroundColor DarkGreen
Write-Host "$totalOriginalSizeFormatted -> $totalConvertedSizeFormatted" -ForegroundColor DarkGreen
Write-Host "Tiempo Total: $formattedTime" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Los archivos convertidos estan en:" -ForegroundColor DarkYellow
Write-Host "$destPath" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "Presione ESC para salir" -ForegroundColor DarkYellow
while ($true) { if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 27) { exit } }
