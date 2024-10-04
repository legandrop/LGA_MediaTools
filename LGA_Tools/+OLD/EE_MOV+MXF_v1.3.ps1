# ______________________________________________________________________________________________________________
#
#   Añade barras negras semitransparentes 2.35:1 y textos específicos a un archivo .MOV usando FFmpeg.
#   Luego renombra el archivo según las reglas especificadas.
#   Uso:
#       Arrastra un archivo .MOV sobre el archivo .bat, que luego llama a este script.
#       El archivo procesado se guarda en la misma carpeta con un nuevo nombre según las reglas.
#
#   Lega - 2024
# ______________________________________________________________________________________________________________


# Obtener la ruta del script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ffmpegPath = Join-Path (Split-Path -Parent $scriptDir) "FFmpeg\ffmpeg.exe"
$oiiotoolPath = Join-Path (Split-Path -Parent $scriptDir) "Oiio\oiiotool.exe"
$ocioConfigPath = Join-Path (Split-Path -Parent $scriptDir) "OpenColorIO\aces_1.2\config.ocio"

# Configurar la variable de entorno OCIO
$env:OCIO = $ocioConfigPath

# Función para pausar y salir
function Pause-AndExit {
    Write-Host "Presione cualquier tecla para salir..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Verificar si ffmpeg.exe y oiiotool.exe existen
if (-Not (Test-Path $ffmpegPath)) {
    Write-Host "Error: No se encuentra ffmpeg.exe en la carpeta /FFmpeg/"
    Write-Host "Chequear que ffmpeg.exe exista en: $ffmpegPath"
    Pause-AndExit
}
if (-Not (Test-Path $oiiotoolPath)) {
    Write-Host "Error: No se encuentra oiiotool.exe en la carpeta /Oiio/"
    Write-Host "Chequear que oiiotool.exe exista en: $oiiotoolPath"
    Pause-AndExit
}
if (-Not (Test-Path $ocioConfigPath)) {
    Write-Host "Error: No se encuentra el archivo de configuración OCIO en: $ocioConfigPath"
    Pause-AndExit
}


# Función para encontrar la carpeta FgPlate con la versión más alta
function Find-LatestFgPlate {
    param (
        [string]$path
    )
    
    $fgPlateFolders = Get-ChildItem -Path $path -Directory | Where-Object { $_.Name -match 'FgPlate' }
    Write-Host "Carpetas FgPlate encontradas:"
    $fgPlateFolders | ForEach-Object { Write-Host $_.Name }
    
    $latestVersion = $fgPlateFolders | 
        ForEach-Object { 
            if ($_.Name -match 'v(\d+)') {
                [PSCustomObject]@{
                    Folder = $_
                    Version = [int]$Matches[1]
                }
            }
        } |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1

    if ($latestVersion) {
        Write-Host "Carpeta FgPlate con la versión más alta:"
        Write-Host $latestVersion.Folder.Name
        return $latestVersion.Folder.FullName
    } else {
        Write-Host "No se encontraron carpetas FgPlate con número de versión."
        return $null
    }
}

# Obtener la ruta del archivo MOV de origen
$inputMovFile = $args[0]
if (-Not $inputMovFile) {
    Write-Host "Error: Debe arrastrar un archivo .MOV al archivo EE_MOV+MXF.bat"
    exit
}

# Obtener la ruta del directorio _input
$currentPath = Split-Path -Parent $inputMovFile
$targetPath = Split-Path -Parent (Split-Path -Parent $currentPath)
$inputPath = Join-Path $targetPath "_input"

Write-Host "Buscando carpetas FgPlate en: $inputPath"
$latestFgPlateFolder = Find-LatestFgPlate -path $inputPath

if ($latestFgPlateFolder) {
    # Buscar el primer frame EXR en la carpeta FgPlate
    $firstExrFrame = Get-ChildItem -Path $latestFgPlateFolder -Filter "*.exr" | Select-Object -First 1

    if ($firstExrFrame) {
        $thumbPath = "T:\VFX-EE\ASSETS\Materiales_Deliveries\thumb_temp.jpg"

        # Convertir EXR a JPG usando oiiotool con conversión de color
        $oiiotoolArgs = @(
            $firstExrFrame.FullName,
            "--colorconvert", "ACES - ACES2065-1", "Output - Rec.709",
            "--compression", "95",
            "-o", $thumbPath
        )

        Write-Host "Convirtiendo EXR a JPG con conversión de color ACES a Rec.709..."
        Write-Host "Comando: $oiiotoolPath $($oiiotoolArgs -join ' ')"

        try {
            & $oiiotoolPath @oiiotoolArgs
            if (Test-Path $thumbPath) {
                Write-Host "Thumbnail guardado exitosamente en: $thumbPath"
            } else {
                Write-Host "Error: No se pudo guardar el thumbnail."
            }
        } catch {
            Write-Host "Error al ejecutar oiiotool: $_"
        }
    } else {
        Write-Host "No se encontraron archivos EXR en la carpeta FgPlate."
    }
} else {
    Write-Host "No se pudo encontrar una carpeta FgPlate válida."
}


Write-Host ""
Write-Host ""








# Función para renombrar el archivo
function Rename-OutputFile {
    param (
        [string]$originalName
    )
    
    # Reemplazar 'EE-' por 'EE_'
    $newName = $originalName -replace 'EE-', 'EE_'
    
    # Eliminar las dos palabras después del tercer bloque de números
    $newName = $newName -replace '^([^\d]*\d+_\d+_\d+)(?:_[^_]+){2}_(.*)$', '$1_$2'
    
    # Cambiar '_comp' a '_COMP'
    $newName = $newName -replace '_comp', '_COMP'
    
    # Añadir '_WKA' antes del número de versión
    $newName = $newName -replace '(v\d+)$', 'WKA_$1'
    
    # Convertir el nombre completo a mayúsculas
    $newName = $newName.ToUpper()
    
    return $newName
}



# Obtener la ruta del archivo MOV de origen
$inputMovFile = $args[0]
if (-Not $inputMovFile) {
    Write-Host "Error: Debe arrastrar un archivo .MOV al archivo EE_MOV+MXF.bat"
    Write-Host "Presione cualquier tecla para salir..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Verificar si el archivo .MOV existe
if (-Not (Test-Path $inputMovFile)) {
    Write-Host "Error: El archivo $inputMovFile no existe."
    Write-Host "Presione cualquier tecla para salir..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Obtener el nombre del archivo sin extensión y la carpeta de destino
$outputDir = Split-Path $inputMovFile
$originalFileName = [System.IO.Path]::GetFileNameWithoutExtension($inputMovFile)

# Renombrar el archivo según las nuevas reglas
$newFileName = Rename-OutputFile -originalName $originalFileName

# Crear el nombre del archivo de salida con el nuevo nombre
$outputFile = Join-Path $outputDir "$newFileName.mov"

Write-Host "Nombre original: $originalFileName"
Write-Host "Nuevo nombre: $newFileName"

# Obtener la fecha actual en formato DD/MM/AAAA
$currentDate = Get-Date -Format "dd/MM/yyyy"

# Comando FFmpeg con barras negras y textos actualizados
$ffmpegArgs = @(
    "-y",  # Esta opción hace que FFmpeg sobrescriba sin preguntar
    "-i", $inputMovFile,
    "-vf", "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,drawbox=y=0:width=iw:height=ceil((ih-(iw/2.35))/2):color=black@0.5:t=fill,drawbox=y=ih-ceil((ih-(iw/2.35))/2):width=iw:height=ceil((ih-(iw/2.35))/2):color=black@0.5:t=fill,drawtext=fontfile='C\:\\Windows\\Fonts\\OpenSans-Regular.ttf':fontsize=22:fontcolor=white:x=20:y=9:text='$newFileName',drawtext=fontfile='C\:\\Windows\\Fonts\\Arial.ttf':fontsize=22:fontcolor=white:x=w-tw-20:y=9:text='$currentDate    WANKA',drawtext=fontfile='C\:\\Windows\\Fonts\\Arial.ttf':fontsize=22:fontcolor=white:x=w-tw-20:y=h-th-10:text='%{frame_num}'",
    "-c:v", "prores_ks",
    "-profile:v", "1",
    "-vendor", "apl0",
    "-b:v", "322640k",
    "-pix_fmt", "yuv422p10le",
    "-c:a", "copy",
    $outputFile
)

# Ejecutar FFmpeg
Write-Host "Ejecutando FFmpeg..."
Write-Host "Comando: $ffmpegPath $ffmpegArgs"
Write-Host "Procesando... Por favor, espere."

try {
    & $ffmpegPath $ffmpegArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Proceso completado. El archivo se guardó como $outputFile."
    } else {
        Write-Host "Error: FFmpeg terminó con código de salida $LASTEXITCODE"
    }
} catch {
    Write-Host "Error al ejecutar FFmpeg: $_"
}



Write-Host "Presione ESC para salir..."
while ($true) {
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Verifica si la tecla presionada es 'Escape'
    if ($key.VirtualKeyCode -eq 27) {
        break
    }
}