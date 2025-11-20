# ______________________________________________________________________________________________________________
#
#   Renombra archivos EXR aplicando la convención LC (Lega Conversion) y duplica la carpeta con la nueva estructura.
#   Convierte automáticamente "comp" a "cmp" (insensible a mayúsculas/minúsculas) pero mantiene otros sufijos como "Matte01" tal cual.
#   Aplica las reglas específicas de transformación LC para proyectos VFX.
#
#   Uso:
#       1. Arrastra una carpeta con archivos EXR sobre el archivo .bat asociado (EXR_Rename_LC.bat).
#       2. El script procesará la carpeta y archivos aplicando la conversión LC.
#       3. Se creará una nueva carpeta con el nombre transformado y los archivos EXR renombrados.
#
#   Ejemplo de transformación:
#       LC_1010_010_Beauty_Senora_comp_v04 -> LC_101_WAN_010_010_cmp_v04
#       LC_1010_010_Beauty_Senora_Matte01_v04 -> LC_101_WAN_010_010_Matte01_v04
#
#   Lega - v1.0
# ______________________________________________________________________________________________________________


Write-Host "=== INICIANDO SCRIPT ===" -ForegroundColor Cyan

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "Script directory: $scriptDir" -ForegroundColor Yellow

# Get source path
$sourcePath = $args[0]
Write-Host "Ruta de origen recibida: '$sourcePath'" -ForegroundColor Yellow

if (-Not $sourcePath) {
    Write-Host "Error: Hay que arrastrar una carpeta con EXRs al archivo EXR_Rename_LC.bat"
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

# Convert to absolute path if it's relative
if (-Not ([System.IO.Path]::IsPathRooted($sourcePath))) {
    $sourcePath = Join-Path (Get-Location) $sourcePath
}

if (-Not (Test-Path -Path $sourcePath -PathType Container)) {
    Write-Host "Error: El elemento arrastrado al .bat no es una carpeta."
    Write-Host "Ruta recibida: $sourcePath"
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

Write-Host "Carpeta de origen valida: $sourcePath" -ForegroundColor Green

# Get the folder name to transform
$originalFolderName = Split-Path $sourcePath -Leaf
Write-Host "Nombre de carpeta original: $originalFolderName" -ForegroundColor Yellow

# Function to transform folder name according to LC rules
function ConvertTo-LCFolderName {
    param ([string]$folderName)

    $segments = $folderName.Split('_')
    Write-Host "Segmentos del nombre original: $($segments -join ', ')" -ForegroundColor Gray

    if ($segments.Count -lt 5) {
        Write-Host "Error: El nombre de la carpeta debe tener al menos 5 segmentos separados por guiones bajos."
        Write-Host "Ejemplo: LC_1010_010_Beauty_Senora_comp_v04"
        Write-Host "Segmentos encontrados: $($segments.Count)"
        Write-Host "Presione cualquier tecla para salir"
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit
    }

    # LC transformation logic based on user's specification
    # LC_1010_010_Beauty_Senora_comp_v04 -> LC_101_WAN_010_010_cmp_v04

    $projectName = $segments[0]  # LC

    # Transform episode-scene: 1010 -> 101
    # 1 (first digit = episode number) + 01 + _WAN
    $episodeScene = $segments[1]  # 1010
    $episodeNumber = $episodeScene.Substring(0, 1) + "01_WAN"  # 101_WAN

    $sceneNumber = $segments[2]   # 010
    $descriptor = $segments[3]     # Beauty
    $action = $segments[4]         # Senora
    $suffix = $segments[5]         # comp, Matte01, etc.
    $version = $segments[6]        # v04

    # Transform suffix: if it's "comp" (case insensitive), use "cmp", otherwise keep original
    $normalizedSuffix = $suffix.ToLower()
    if ($normalizedSuffix -eq "comp") {
        $transformedSuffix = "cmp"
    } else {
        $transformedSuffix = $suffix
    }

    # Build new name: LC_101_WAN_010_010_cmp_v04 or LC_101_WAN_010_010_Matte01_v04
    $newName = "$projectName`_$episodeNumber`_$sceneNumber`_$sceneNumber`_$transformedSuffix`_$version"

    Write-Host "Transformacion:" -ForegroundColor Gray
    Write-Host "  Proyecto: $projectName -> $projectName" -ForegroundColor Gray
    Write-Host "  Episodio-Escena: $episodeScene -> $episodeNumber" -ForegroundColor Gray
    Write-Host "  Escena: $sceneNumber -> $sceneNumber (duplicado)" -ForegroundColor Gray
    Write-Host "  Descriptor-Accion-Sufijo: $descriptor`_$action`_$suffix -> $transformedSuffix`_$version" -ForegroundColor Gray

    return $newName
}

# Transform folder name using LC rules
$newFolderName = ConvertTo-LCFolderName $originalFolderName
Write-Host "Nombre de carpeta transformado: $newFolderName" -ForegroundColor Green

# Create destination path (sibling to source)
$parentPath = Split-Path $sourcePath -Parent
Write-Host "Ruta padre: $parentPath" -ForegroundColor Gray
$destPath = Join-Path $parentPath $newFolderName

Write-Host ""
Write-Host "Ruta destino: $destPath" -ForegroundColor Yellow

# Create destination directory if it doesn't exist
if (-Not (Test-Path $destPath)) {
    Write-Host "Creando carpeta destino..." -ForegroundColor Yellow
    New-Item -Path $destPath -ItemType Directory -Force | Out-Null
    Write-Host "Creada carpeta destino: $destPath" -ForegroundColor Green
} else {
    Write-Host "Carpeta destino ya existe" -ForegroundColor Green
}

Write-Host ""
Write-Host "Carpeta destino: $destPath" -ForegroundColor Cyan
Write-Host ""

# Count EXR files
Write-Host "Buscando archivos EXR en: $sourcePath" -ForegroundColor Yellow
$files = Get-ChildItem -Path $sourcePath -Filter "*.exr"
$fileCount = $files.Count

Write-Host "Archivos encontrados:" -ForegroundColor Yellow
foreach ($file in $files) {
    Write-Host "  - $($file.Name)" -ForegroundColor Gray
}

if ($fileCount -eq 0) {
    Write-Host "Error: No se encontraron archivos EXR en la carpeta seleccionada."
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

Write-Host "Archivos EXR encontrados: $fileCount" -ForegroundColor Yellow
Write-Host ""

# Initialize counters
$currentFile = 0

# Start timer
$startTime = Get-Date

Write-Host "Iniciando copia y renombrado..." -ForegroundColor Cyan
Write-Host ""

# Function to extract and format frame number
function Get-FrameNumber {
    param ([string]$fileName)

    # Remove .exr extension
    $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($fileName)

    # Find the last occurrence of . or _ followed by digits
    if ($nameWithoutExt -match '.*[._](\d+)$') {
        $frameNumber = $matches[1]
        # Convert to 4-digit format (pad with zeros or truncate from left)
        if ($frameNumber.Length -gt 4) {
            # Take the last 4 digits
            return $frameNumber.Substring($frameNumber.Length - 4)
        } else {
            # Pad with zeros to make it 4 digits
            return $frameNumber.PadLeft(4, '0')
        }
    }

    # If no frame number found, return default
    return "0001"
}

# Process EXR files
foreach ($file in $files) {
    $currentFile++

    Write-Host "Procesando archivo: $($file.Name)" -ForegroundColor Yellow

    # Extract frame number and create new filename
    $frameNumber = Get-FrameNumber $file.Name
    # Format: LC_101_WAN_010_010_cmp_v04.0001001.exr or LC_101_WAN_010_010_Matte01_v04.0001001.exr
    $newFileName = "${newFolderName}.000${frameNumber}"

    Write-Host "  Frame extraido: $frameNumber" -ForegroundColor Gray
    Write-Host "  Nuevo nombre: $newFileName.exr" -ForegroundColor Gray

    $outputPath = "$destPath\$newFileName.exr"

    Write-Host "  Archivo destino: $outputPath" -ForegroundColor Gray
    Write-Host "Copiando archivo $currentFile de $fileCount..." -NoNewline -ForegroundColor DarkYellow

    # Copy file to destination with new name
    try {
        Copy-Item -Path $file.FullName -Destination $outputPath -Force
        Write-Host "  OK" -ForegroundColor Green
    } catch {
        Write-Host "  Error al copiar" -ForegroundColor Red
        continue
    }
}

# Calculate total time
$endTime = Get-Date
$totalTime = $endTime - $startTime
$formattedTime = "{0:D2}h {1:D2}m {2:D2}s" -f $totalTime.Hours, $totalTime.Minutes, $totalTime.Seconds

# Final message - Completed
Write-Host ""
Write-Host "=== RENOMBRADO COMPLETADO ===" -ForegroundColor DarkGreen
Write-Host "Carpeta original: $originalFolderName" -ForegroundColor DarkGreen
Write-Host "Carpeta nueva: $newFolderName" -ForegroundColor DarkGreen
Write-Host "Archivos procesados: $fileCount" -ForegroundColor DarkGreen
Write-Host "Tiempo Total: $formattedTime" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Los archivos convertidos estan en:" -ForegroundColor DarkYellow
Write-Host "$destPath" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "Presione cualquier tecla para salir" -ForegroundColor DarkYellow
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
