# Genera placeholders EXR negros para compositing

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

Write-Host "Carpeta valida: $sourcePath" -ForegroundColor Green

# PASO 1: Extraer shotname
Write-Host ""
Write-Host "=== PASO 1: EXTRAYENDO SHOTNAME ===" -ForegroundColor Cyan

$sourceName = Split-Path $sourcePath -Leaf
$parentPath = Split-Path $sourcePath -Parent
$parentName = Split-Path $parentPath -Leaf

Write-Host "Carpeta arrastrada: $sourceName" -ForegroundColor Yellow
Write-Host "Carpeta padre: $parentName" -ForegroundColor Yellow

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

# PASO 2: Extraer frame range
Write-Host ""
Write-Host "=== PASO 2: EXTRAYENDO FRAME RANGE ===" -ForegroundColor Cyan

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

$frameNumbers = @()
foreach ($file in $exrFiles) {
    $fileName = $file.Name
    Write-Host "  - $fileName" -ForegroundColor Gray
    
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

$frameNumbers = $frameNumbers | Sort-Object
$minFrame = $frameNumbers[0]
$maxFrame = $frameNumbers[-1]
$frameRange = "$minFrame-$maxFrame"

Write-Host "FRAME RANGE ENCONTRADO: $frameRange" -ForegroundColor Green

# PASO 3: Crear estructura de carpetas
Write-Host ""
Write-Host "=== PASO 3: CREANDO ESTRUCTURA DE CARPETAS ===" -ForegroundColor Cyan

$shotFolderPath = (Get-Item $sourcePath).Parent.Parent.FullName
Write-Host "Carpeta del shot: $shotFolderPath" -ForegroundColor Yellow

$compPath = Join-Path $shotFolderPath "Comp"
$publishPath = Join-Path $compPath "4_publish"
$finalDestPath = Join-Path $publishPath "${shotName}_comp_v00"

Write-Host "Creando estructura:" -ForegroundColor Yellow
Write-Host "  Comp: $compPath" -ForegroundColor Gray
Write-Host "  4_publish: $publishPath" -ForegroundColor Gray
Write-Host "  Final: $finalDestPath" -ForegroundColor Gray

if (-Not (Test-Path $compPath)) {
    Write-Host "Creando carpeta Comp..." -ForegroundColor Yellow
    New-Item -Path $compPath -ItemType Directory -Force | Out-Null
    Write-Host "Carpeta Comp creada" -ForegroundColor Green
} else {
    Write-Host "Carpeta Comp ya existe" -ForegroundColor Green
}

if (-Not (Test-Path $publishPath)) {
    Write-Host "Creando carpeta 4_publish..." -ForegroundColor Yellow
    New-Item -Path $publishPath -ItemType Directory -Force | Out-Null
    Write-Host "Carpeta 4_publish creada" -ForegroundColor Green
} else {
    Write-Host "Carpeta 4_publish ya existe" -ForegroundColor Green
}

if (-Not (Test-Path $finalDestPath)) {
    Write-Host "Creando carpeta destino..." -ForegroundColor Yellow
    New-Item -Path $finalDestPath -ItemType Directory -Force | Out-Null
    Write-Host "Carpeta destino creada" -ForegroundColor Green
} else {
    Write-Host "Carpeta destino ya existe" -ForegroundColor Green
}

Write-Host "ESTRUCTURA CREADA: $finalDestPath" -ForegroundColor Green

# PASO 4: Verificar EXR template
Write-Host ""
Write-Host "=== PASO 4: VERIFICANDO EXR TEMPLATE ===" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$blackExrTemplate = Join-Path $scriptDir "Shotname_comp_v00_num.exr"

Write-Host "Buscando template EXR negro en:" -ForegroundColor Yellow
Write-Host "$blackExrTemplate" -ForegroundColor Yellow

if (-Not (Test-Path $blackExrTemplate)) {
    Write-Host "ERROR: No se encuentra el template EXR negro" -ForegroundColor Red
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

Write-Host "TEMPLATE EXR ENCONTRADO" -ForegroundColor Green
Write-Host "Ruta del template: $blackExrTemplate" -ForegroundColor Green

$templateFile = Get-Item $blackExrTemplate
Write-Host "Informacion del template:" -ForegroundColor Yellow
Write-Host "  Nombre: $($templateFile.Name)" -ForegroundColor Gray
Write-Host "  Tamano: $($templateFile.Length) bytes" -ForegroundColor Gray
Write-Host "  Fecha: $($templateFile.LastWriteTime)" -ForegroundColor Gray

# COPIAR TODOS LOS FRAMES DEL RANGE
Write-Host ""
Write-Host "=== COPIANDO TODOS LOS FRAMES ===" -ForegroundColor Cyan

$totalFrames = ($maxFrame - $minFrame) + 1
Write-Host "Generando $totalFrames archivos desde frame $minFrame hasta $maxFrame..." -ForegroundColor Yellow
Write-Host ""

$currentFrame = 0
$successCount = 0
$errorCount = 0

for ($frame = $minFrame; $frame -le $maxFrame; $frame++) {
    $currentFrame++
    
    $frameFormatted = $frame.ToString("0000")
    $outputFileName = "${shotName}_comp_v00_${frameFormatted}.exr"
    $outputPath = Join-Path $finalDestPath $outputFileName
    
    Write-Host "[$currentFrame/$totalFrames] $outputFileName" -ForegroundColor Gray
    
    try {
        Copy-Item -Path $blackExrTemplate -Destination $outputPath -Force
        
        if (Test-Path $outputPath) {
            Write-Host "  OK" -ForegroundColor DarkGreen
            $successCount++
        } else {
            Write-Host "  ERROR: No se creo" -ForegroundColor Red
            $errorCount++
        }
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host ""
Write-Host "GENERACION COMPLETADA:" -ForegroundColor Green
Write-Host "  Archivos creados: $successCount" -ForegroundColor Green
Write-Host "  Errores: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })

# RESULTADO FINAL
Write-Host ""
Write-Host "=== RESULTADO ===" -ForegroundColor DarkGreen
Write-Host "Shot Name: $shotName" -ForegroundColor DarkGreen
Write-Host "Frame Range: $frameRange" -ForegroundColor DarkGreen
Write-Host "Carpeta creada: $finalDestPath" -ForegroundColor DarkGreen
Write-Host "Template verificado: OK" -ForegroundColor DarkGreen
Write-Host "Frames generados: $successCount/$totalFrames" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Presione cualquier tecla para salir" -ForegroundColor DarkYellow
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')