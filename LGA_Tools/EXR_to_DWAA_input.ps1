# ______________________________________________________________________________________________________________
#
#   Convierte archivos EXR de cualquier compresión a compresión DWAA y organiza la salida en la estructura del proyecto VFX.
#   Utiliza la herramienta oiiotool para la conversión y gestiona el renombrado de archivos.
#
#   Uso:
#       1. Arrastra una carpeta con archivos EXR sobre el archivo .bat asociado (EXR_to_DWAA_input.bat).
#       2. El script solicitará al usuario el 'Nombre del plate'.
#       3. A partir del nombre del plate, se calculará automáticamente el 'ProjectName' y el 'ShotName'.
#       4. Se buscará la carpeta del shot correspondiente en la ruta 'T:\\VFX-[ProjectName]', buscando un nivel de profundidad.
#       5. Los archivos EXR convertidos se guardarán en la siguiente ubicación:
#          [Carpeta_del_Shot_Encontrada]\_input\[Nombre_del_Plate]\n#       6. Los archivos de salida serán renombrados a '[Nombre_del_Plate]_[Número_de_Frame_4_dígitos].exr'.
#
#   Lega - v1.1
# ______________________________________________________________________________________________________________


Write-Host "=== INICIANDO SCRIPT ===" -ForegroundColor Cyan

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "Script directory: $scriptDir" -ForegroundColor Yellow

$oiiotoolPath = Join-Path $scriptDir "..\OIIO\oiiotool.exe"
Write-Host "Buscando oiiotool en: $oiiotoolPath" -ForegroundColor Yellow

# Check if oiiotool exists
if (-Not (Test-Path $oiiotoolPath)) {
    Write-Host "Error: No se encuentra oiiotool.exe en la ruta esperada."
    Write-Host "Ruta buscada: $oiiotoolPath"
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

Write-Host "oiiotool encontrado correctamente" -ForegroundColor Green

# Get source path
$sourcePath = $args[0]
Write-Host "Ruta de origen recibida: '$sourcePath'" -ForegroundColor Yellow

if (-Not $sourcePath) {
    Write-Host "Error: Hay que arrastrar una carpeta con EXRs al archivo EXR_to_DWAA_input.bat"
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

if (-Not (Test-Path -Path $sourcePath -PathType Container)) {
    Write-Host "Error: El elemento arrastrado al .bat no es una carpeta."
    Write-Host "Ruta recibida: $sourcePath"
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

Write-Host "Carpeta de origen valida: $sourcePath" -ForegroundColor Green

# Ask user for plate name
Write-Host ""
Write-Host "=== CONVERTIR EXR A DWAA ===" -ForegroundColor Cyan
Write-Host ""
$plateName = Read-Host "Nombre del plate"

if ([string]::IsNullOrWhiteSpace($plateName)) {
    Write-Host "Error: Debe ingresar un nombre de plate valido."
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

# Calculate ProjectName and ShotName
$plateSegments = $plateName.Split('_')
Write-Host "Segmentos del plate: $($plateSegments -join ', ')" -ForegroundColor Yellow

if ($plateSegments.Count -lt 5) {
    Write-Host "Error: El nombre del plate debe tener al menos 5 segmentos separados por guiones bajos."
    Write-Host "Ejemplo: ETDM_1000_0010_DeAging_Atropella_aPlate_v01"
    Write-Host "Segmentos encontrados: $($plateSegments.Count)"
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

$projectName = $plateSegments[0]
$shotName = ($plateSegments[0..4] -join '_')

Write-Host ""
Write-Host "Project Name: $projectName" -ForegroundColor Green
Write-Host "Shot Name: $shotName" -ForegroundColor Green
Write-Host ""

# Search for shot folder in VFX structure
$vfxProjectPath = "T:\VFX-$projectName"
Write-Host "Buscando proyecto en: $vfxProjectPath" -ForegroundColor Yellow

if (-Not (Test-Path $vfxProjectPath)) {
    Write-Host "Error: No se encuentra la carpeta del proyecto en: $vfxProjectPath"
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

Write-Host "Carpeta del proyecto encontrada" -ForegroundColor Green
Write-Host "Buscando carpeta del shot: $shotName" -ForegroundColor Yellow
Write-Host "En: $vfxProjectPath" -ForegroundColor Yellow

# Search recursively for shot folder (one level deep)
$shotFolderPath = $null
$subFolders = Get-ChildItem -Path $vfxProjectPath -Directory

Write-Host "Subcarpetas encontradas:" -ForegroundColor Yellow
foreach ($subFolder in $subFolders) {
    Write-Host "  - $($subFolder.Name)" -ForegroundColor Gray
    $potentialShotPath = Join-Path $subFolder.FullName $shotName
    Write-Host "    Buscando en: $potentialShotPath" -ForegroundColor Gray
    
    if (Test-Path $potentialShotPath -PathType Container) {
        $shotFolderPath = $potentialShotPath
        Write-Host "    ENCONTRADO!" -ForegroundColor Green
        break
    }
}

if (-Not $shotFolderPath) {
    Write-Host "Error: No se encontro la carpeta del shot '$shotName' en '$vfxProjectPath'"
    Write-Host "Presione cualquier tecla para salir"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

Write-Host "Carpeta del shot encontrada: $shotFolderPath" -ForegroundColor Green

# Create destination path: ShotFolder\_input\PlateName
$inputFolderPath = Join-Path $shotFolderPath "_input"
$destPath = Join-Path $inputFolderPath $plateName

Write-Host "Ruta _input: $inputFolderPath" -ForegroundColor Yellow
Write-Host "Ruta destino final: $destPath" -ForegroundColor Yellow

# Create directories if they don't exist
if (-Not (Test-Path $inputFolderPath)) {
    Write-Host "Creando carpeta _input..." -ForegroundColor Yellow
    New-Item -Path $inputFolderPath -ItemType Directory -Force | Out-Null
    Write-Host "Creada carpeta _input: $inputFolderPath" -ForegroundColor Green
} else {
    Write-Host "Carpeta _input ya existe" -ForegroundColor Green
}

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

# Initialize counters and size variables
$currentFile = 0
$totalOriginalSize = 0
$totalConvertedSize = 0

# Function to format file size
function Format-FileSize {
    param ([long]$size)
    if ($size -gt 1TB) { return "{0:N2} TB" -f ($size / 1TB) }
    if ($size -gt 1GB) { return "{0:N2} GB" -f ($size / 1GB) }
    if ($size -gt 1MB) { return "{0:N2} MB" -f ($size / 1MB) }
    if ($size -gt 1KB) { return "{0:N2} KB" -f ($size / 1KB) }
    return "$size B"
}

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

# Start timer
$startTime = Get-Date

Write-Host "Iniciando conversion..." -ForegroundColor Cyan
Write-Host ""

# DWA compression level (OpenEXR DWA usa 'level', no 'quality').
$dwaaLevel = 60
Write-Host "Usando compresion: dwaa (level=$dwaaLevel)" -ForegroundColor Yellow

# Process EXR files
foreach ($file in $files) {
    $currentFile++

    Write-Host "Procesando archivo: $($file.Name)" -ForegroundColor Yellow

    # Extract frame number and create new filename
    $frameNumber = Get-FrameNumber $file.Name
    $newFileName = "${plateName}_${frameNumber}"
    
    Write-Host "  Frame extraido: $frameNumber" -ForegroundColor Gray
    Write-Host "  Nuevo nombre: $newFileName.exr" -ForegroundColor Gray
    
    $outputPath = "$destPath\$newFileName.exr"
    
    Write-Host "  Archivo destino: $outputPath" -ForegroundColor Gray
    Write-Host "Convirtiendo archivo $currentFile de $fileCount..." -NoNewline -ForegroundColor DarkYellow
    
    $originalSize = (Get-Item $file.FullName).Length
    $totalOriginalSize += $originalSize
    
    # Use Start-Process to handle spaces in paths
    # Nota: Para DWA en EXR, el parametro correcto es 'level' (no 'quality').
    # Ademas, establecemos explicitamente el atributo EXR 'dwaCompressionLevel' para compatibilidad.
    $arguments = """$($file.FullName)"" --compression dwaa --attrib:type=float exr:dwaCompressionLevel $dwaaLevel -o ""$outputPath"""
    Write-Host "  Ejecutando: $oiiotoolPath $arguments" -ForegroundColor Gray
    
    $process = Start-Process -FilePath $oiiotoolPath -ArgumentList $arguments -NoNewWindow -Wait -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-Host "  Error en la conversion del archivo: $($file.Name)" -ForegroundColor Red
        continue
    }
    
    if (Test-Path $outputPath) {
        $convertedSize = (Get-Item $outputPath).Length
        $totalConvertedSize += $convertedSize
        
        $originalSizeFormatted = Format-FileSize $originalSize
        $convertedSizeFormatted = Format-FileSize $convertedSize
        Write-Host "  $originalSizeFormatted -> $convertedSizeFormatted" -ForegroundColor DarkYellow
    } else {
        Write-Host "  Error: Archivo de salida no se creo correctamente" -ForegroundColor Red
    }
}

# Calculate total time
$endTime = Get-Date
$totalTime = $endTime - $startTime
$formattedTime = "{0:D2}h {1:D2}m {2:D2}s" -f $totalTime.Hours, $totalTime.Minutes, $totalTime.Seconds

# Final message - Completed
$totalOriginalSizeFormatted = Format-FileSize $totalOriginalSize
$totalConvertedSizeFormatted = Format-FileSize $totalConvertedSize
Write-Host ""
Write-Host "=== CONVERSION COMPLETADA ===" -ForegroundColor DarkGreen
Write-Host "Project: $projectName" -ForegroundColor DarkGreen
Write-Host "Shot: $shotName" -ForegroundColor DarkGreen
Write-Host "Plate: $plateName" -ForegroundColor DarkGreen
Write-Host "$totalOriginalSizeFormatted -> $totalConvertedSizeFormatted" -ForegroundColor DarkGreen
Write-Host "Tiempo Total: $formattedTime" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Los archivos convertidos estan en:" -ForegroundColor DarkYellow
Write-Host "$destPath" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "Presione cualquier tecla para salir" -ForegroundColor DarkYellow
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
