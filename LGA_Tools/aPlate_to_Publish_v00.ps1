# ______________________________________________________________________________________________________________
#
#   Genera placeholders EXR negros - VERSION SIMPLE
#   Solo extrae el shotname de la ruta
#
#   Lega - v2.1
# ______________________________________________________________________________________________________________

Write-Host "=== GENERADOR DE PLACEHOLDERS EXR ===" -ForegroundColor Cyan

# Get source path
$sourcePath = $args[0]
Write-Host "Ruta recibida: '$sourcePath'" -ForegroundColor Yellow

if (-Not $sourcePath) {
    Write-Host "Error: Hay que arrastrar una carpeta"
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

if (-Not (Test-Path -Path $sourcePath -PathType Container)) {
    Write-Host "Error: No es una carpeta"
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

Write-Host "Carpeta válida: $sourcePath" -ForegroundColor Green

# Extract shotname - VERSION SIMPLE
Write-Host ""
Write-Host "=== PASO 1: EXTRAYENDO SHOTNAME ===" -ForegroundColor Cyan

# Get just the folder name parts
$sourceName = Split-Path $sourcePath -Leaf
$parentPath = Split-Path $sourcePath -Parent
$parentName = Split-Path $parentPath -Leaf

Write-Host "Carpeta arrastrada: $sourceName" -ForegroundColor Yellow
Write-Host "Carpeta padre: $parentName" -ForegroundColor Yellow

# If parent is _input, then the shotname is the grandparent
if ($parentName -eq '_input') {
    $grandParentPath = Split-Path $parentPath -Parent
    $shotName = Split-Path $grandParentPath -Leaf
    Write-Host "SHOTNAME ENCONTRADO: $shotName" -ForegroundColor Green
} else {
    Write-Host "ERROR: La carpeta padre no es '_input'" -ForegroundColor Red
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

Write-Host ""
Write-Host "=== PASO 2: EXTRAYENDO FRAME RANGE ===" -ForegroundColor Cyan

# Find EXR files
Write-Host "Buscando archivos EXR en: $sourcePath" -ForegroundColor Yellow
$exrFiles = Get-ChildItem -Path $sourcePath -Filter "*.exr"
$fileCount = $exrFiles.Count

if ($fileCount -eq 0) {
    Write-Host "ERROR: No se encontraron archivos EXR" -ForegroundColor Red
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

Write-Host "Archivos EXR encontrados: $fileCount" -ForegroundColor Green

# Extract frame numbers
$frameNumbers = @()
foreach ($file in $exrFiles) {
    $fileName = $file.Name
    Write-Host "  - $fileName" -ForegroundColor Gray
    
    # Extract number from end of filename
    if ($fileName -match '(\d+)\.exr$') {
        $frameNum = [int]$matches[1]
        $frameNumbers += $frameNum
        Write-Host "    Frame: $frameNum" -ForegroundColor Gray
    }
}

if ($frameNumbers.Count -eq 0) {
    Write-Host "ERROR: No se pudieron extraer frame numbers" -ForegroundColor Red
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

# Calculate frame range
$frameNumbers = $frameNumbers | Sort-Object
$minFrame = $frameNumbers[0]
$maxFrame = $frameNumbers[-1]
$frameRange = "$minFrame-$maxFrame"

Write-Host "FRAME RANGE ENCONTRADO: $frameRange" -ForegroundColor Green

Write-Host ""
Write-Host "=== PASO 3: CREANDO ESTRUCTURA DE CARPETAS ===" -ForegroundColor Cyan

# Determine shot folder path
$shotFolderPath = (Get-Item $sourcePath).Parent.Parent.FullName
Write-Host "Carpeta del shot: $shotFolderPath" -ForegroundColor Yellow

# Create comp structure
$compPath = Join-Path $shotFolderPath "Comp"
$publishPath = Join-Path $compPath "4_publish"
$finalDestPath = Join-Path $publishPath "${shotName}_comp_v00"

Write-Host "Creando estructura:" -ForegroundColor Yellow
Write-Host "  Comp: $compPath" -ForegroundColor Gray
Write-Host "  4_publish: $publishPath" -ForegroundColor Gray
Write-Host "  Final: $finalDestPath" -ForegroundColor Gray

# Create directories
if (-Not (Test-Path $compPath)) {
    Write-Host "Creando carpeta Comp..." -ForegroundColor Yellow
    New-Item -Path $compPath -ItemType Directory -Force | Out-Null
    Write-Host "✓ Carpeta Comp creada" -ForegroundColor Green
} else {
    Write-Host "✓ Carpeta Comp ya existe" -ForegroundColor Green
}

if (-Not (Test-Path $publishPath)) {
    Write-Host "Creando carpeta 4_publish..." -ForegroundColor Yellow
    New-Item -Path $publishPath -ItemType Directory -Force | Out-Null
    Write-Host "✓ Carpeta 4_publish creada" -ForegroundColor Green
} else {
    Write-Host "✓ Carpeta 4_publish ya existe" -ForegroundColor Green
}

if (-Not (Test-Path $finalDestPath)) {
    Write-Host "Creando carpeta destino..." -ForegroundColor Yellow
    New-Item -Path $finalDestPath -ItemType Directory -Force | Out-Null
    Write-Host "✓ Carpeta destino creada" -ForegroundColor Green
} else {
    Write-Host "✓ Carpeta destino ya existe" -ForegroundColor Green
}

Write-Host "ESTRUCTURA CREADA: $finalDestPath" -ForegroundColor Green

Write-Host ""
Write-Host "RESULTADO:" -ForegroundColor DarkGreen
Write-Host "Shot Name: $shotName" -ForegroundColor DarkGreen
Write-Host "Frame Range: $frameRange" -ForegroundColor DarkGreen
Write-Host "Carpeta creada: $finalDestPath" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Presione cualquier tecla para salir" -ForegroundColor DarkYellow
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')