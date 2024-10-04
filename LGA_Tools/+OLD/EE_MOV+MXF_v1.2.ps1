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

# Verificar si ffmpeg.exe existe en esa ruta
if (-Not (Test-Path $ffmpegPath)) {
    Write-Host "Error: No se encuentra ffmpeg.exe en la carpeta /FFmpeg/"
    Write-Host "Chequear que ffmpeg.exe exista en: $ffmpegPath"
    Write-Host "Presione cualquier tecla para salir..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}


# Función para encontrar el archivo EditRef con la versión más alta
function Find-LatestEditRef {
    param (
        [string]$path
    )
    
    $editRefFiles = Get-ChildItem -Path $path -Filter "*EditRef*.mov"
    Write-Host "Archivos EditRef encontrados:"
    $editRefFiles | ForEach-Object { Write-Host $_.Name }
    
    $latestVersion = $editRefFiles | 
        ForEach-Object { 
            if ($_.Name -match 'v(\d+)') {
                [PSCustomObject]@{
                    File = $_
                    Version = [int]$Matches[1]
                }
            }
        } |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1

    if ($latestVersion) {
        Write-Host "Archivo EditRef con la versión más alta:"
        Write-Host $latestVersion.File.Name
        return $latestVersion.File.FullName
    } else {
        Write-Host "No se encontraron archivos EditRef con número de versión."
        return $null
    }
}

# Obtener la ruta del archivo MOV de origen
$inputMovFile = $args[0]
if (-Not $inputMovFile) {
    Write-Host "Error: Debe arrastrar un archivo .MOV al archivo EE_MOV+MXF.bat"
    Write-Host "Presione cualquier tecla para salir..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Obtener la ruta del directorio _input
$currentPath = Split-Path -Parent $inputMovFile
$targetPath = Split-Path -Parent (Split-Path -Parent $currentPath)
$inputPath = Join-Path $targetPath "_input"

Write-Host "Buscando archivos EditRef en: $inputPath"
$latestEditRefFile = Find-LatestEditRef -path $inputPath

if ($latestEditRefFile) {
    # Ruta donde se guardará el thumb
    $thumbPath = "T:\VFX-EE\ASSETS\Materiales_Deliveries\thumb_temp.jpg"

    # Extraer el primer frame y guardarlo como thumb_temp.jpg
    $ffmpegThumbArgs = @(
        "-y",
        "-i",
        $latestEditRefFile,
        "-vframes",
        "1",
        "-q:v",
        "2",
        $thumbPath
    )

    Write-Host "Extrayendo thumbnail del archivo EditRef..."
    Write-Host "Comando: $ffmpegPath $($ffmpegThumbArgs -join ' ')"

    try {
        & $ffmpegPath @ffmpegThumbArgs
        if (Test-Path $thumbPath) {
            Write-Host "Thumbnail guardado exitosamente en: $thumbPath"
        } else {
            Write-Host "Error: No se pudo guardar el thumbnail."
        }
    } catch {
        Write-Host "Error al ejecutar FFmpeg: $_"
    }


} else {
    Write-Host "No se pudo extraer el thumbnail porque no se encontró un archivo EditRef válido."
}







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

Write-Host "Presione cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")