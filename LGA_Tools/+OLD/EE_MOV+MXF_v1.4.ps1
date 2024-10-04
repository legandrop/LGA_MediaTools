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
$ffprobePath = Join-Path (Split-Path -Parent $scriptDir) "FFmpeg\ffprobe.exe"
$oiiotoolPath = Join-Path (Split-Path -Parent $scriptDir) "Oiio\oiiotool.exe"
$ocioConfigPath = Join-Path (Split-Path -Parent $scriptDir) "OpenColorIO\aces_1.2\config.ocio"
$deliveriesMatPath = "T:\VFX-EE\ASSETS\Materiales_Deliveries"


# Configurar la variable de entorno OCIO
$env:OCIO = $ocioConfigPath


# Función para pausar y salir solo con ESC
function Pause-AndExit {
    Write-Host "Presione ESC para salir..."
    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($key.VirtualKeyCode -eq 27) {
            exit
        }
    }
}


# Función para imprimir en color
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



# Función para imprimir en color
function Write-ColorOutput {
    param (
        [string]$message,
        [string]$color
    )
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $color
    Write-Host $message
    $host.UI.RawUI.ForegroundColor = $originalColor
}


# Función para encontrar el EditRef más reciente:
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



# Función para comprobar que el naming del MOV es el correcto
function Check-FileNameStructure {
    param (
        [string]$fileName
    )

    $isValid = $true
    
    Write-Host "Verificando estructura del nombre del archivo:"
    
    # Verificar que comienza con 'EE-'
    if ($fileName -match '^EE-') {
        Write-ColorOutput "  Comienza con 'EE-': Correcto" "Green"
    } else {
        Write-ColorOutput "  Comienza con 'EE-': Incorrecto" "Red"
        $isValid = $false
    }

    # Verificar el número de episodio (3 dígitos)
    if ($fileName -match '^EE-(\d{3})') {
        Write-ColorOutput "  Número de episodio (3 dígitos): Correcto ($($matches[1]))" "Green"
    } else {
        Write-ColorOutput "  Número de episodio (3 dígitos): Incorrecto" "Red"
        $isValid = $false
    }

    # Verificar el formato general
    $pattern = '^EE-(\d{3})_(\d+)_(\d+)_([^_]+)_([^_]+)_comp_v(\d+)$'
    if ($fileName -match $pattern) {
        $episode = $matches[1]
        $scene = $matches[2]
        $shot = $matches[3]
        $description1 = $matches[4]
        $description2 = $matches[5]
        $version = $matches[6]

        Write-ColorOutput "  Formato general: Correcto" "Green"
        Write-ColorOutput "    Escena: $scene" "Green"
        Write-ColorOutput "    Plano: $shot" "Green"
        Write-ColorOutput "    Descripción 1: $description1" "Green"
        Write-ColorOutput "    Descripción 2: $description2" "Green"
        Write-ColorOutput "    Versión: v$version" "Green"
    } else {
        Write-ColorOutput "  Formato general: Incorrecto" "Red"
        $isValid = $false
    }

    if ($isValid) {
        Write-ColorOutput "Estructura del nombre del archivo correcta." "Green"
    } else {
        Write-ColorOutput "Error: La estructura del nombre del archivo no es correcta." "Red"
        Write-Host "El nombre debe seguir este formato:"
        Write-Host "EE-XXX_YYY_ZZZZ_Descripcion1_Descripcion2_comp_vNN"
        Write-Host "Donde:"
        Write-Host "  XXX: Número de episodio (3 dígitos)"
        Write-Host "  YYY: Número de escena"
        Write-Host "  ZZZZ: Número de plano"
        Write-Host "  Descripcion1 y Descripcion2: Textos descriptivos"
        Write-Host "  NN: Número de versión"
    }

    return $isValid
}

# Uso de la función
$fileName = [System.IO.Path]::GetFileNameWithoutExtension($inputMovFile)
Write-Host "Verificando la estructura del nombre del archivo: $fileName"
$nameCheckResult = Check-FileNameStructure $fileName
if (-not $nameCheckResult) {
    Write-ColorOutput "La verificación del nombre del archivo falló. Saliendo del script." "Red"
    Pause-AndExit
} else {
    Write-ColorOutput "La verificación del nombre del archivo fue exitosa." "Green"
    Write-Host ""
}




# Función para obtener el número de frames de un archivo de video usando FFprobe
function Get-VideoFrameCount {
    param (
        [string]$videoPath
    )
    

    # Comando para obtener el número de frames usando FFprobe
    $ffprobeOutput = & $ffprobePath -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=noprint_wrappers=1:nokey=1 "$videoPath"
    
    if ($LASTEXITCODE -eq 0 -and $ffprobeOutput -match '^\d+$') {
        return [int]$ffprobeOutput
    } else {
        Write-Host "Error al obtener el número de frames del video. Salida de FFprobe: $ffprobeOutput"
        return 0
    }
}



# Función para obtener el número de frames de una secuencia de imágenes
function Get-ImageSequenceFrameCount {
    param (
        [string]$folderPath
    )
    $exrFiles = Get-ChildItem -Path $folderPath -Filter "*.exr"
    return $exrFiles.Count
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




# Obtener el nombre del archivo sin extensión y la carpeta de destino
$outputDir = Split-Path $inputMovFile
$originalFileName = [System.IO.Path]::GetFileNameWithoutExtension($inputMovFile)

# Renombrar el archivo según las nuevas reglas
$newFileName = Rename-OutputFile -originalName $originalFileName

# Crear el nombre del archivo de salida con el nuevo nombre
$outputFile = Join-Path $outputDir "$newFileName.mov"

Write-Host "Nombre original: $originalFileName"
Write-Host "Nuevo nombre: $newFileName"
Write-Host ""


# Obtener la fecha actual en formato DD/MM/AAAA
$currentDate = Get-Date -Format "dd/MM/yyyy"

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
Write-Host ""

# Obtener la ruta del directorio _input
$currentPath = Split-Path -Parent $inputMovFile
$targetPath = Split-Path -Parent (Split-Path -Parent $currentPath)
$inputPath = Join-Path $targetPath "_input"

Write-Host "Buscando carpetas FgPlate y archivo EditRef en: $inputPath"
$latestFgPlateFolder = Find-LatestFgPlate -path $inputPath
$latestEditRefFile = Find-LatestEditRef -path $inputPath

if ($latestFgPlateFolder -and $latestEditRefFile) {
    # Obtener el número de frames del archivo MOV
    $movFrameCount = Get-VideoFrameCount -videoPath $inputMovFile
    Write-Host "Número de frames en el archivo MOV: $movFrameCount"

    # Obtener el número de frames de la secuencia EXR
    $exrFrameCount = Get-ImageSequenceFrameCount -folderPath $latestFgPlateFolder
    Write-Host "Número de frames en la secuencia EXR: $exrFrameCount"

    # Obtener el número de frames del EditRef
    $editRefFrameCount = Get-VideoFrameCount -videoPath $latestEditRefFile
    Write-Host "Número de frames en el archivo EditRef: $editRefFrameCount"

    # Comparar los números de frames
    if ($movFrameCount -eq $exrFrameCount) {
        Write-ColorOutput "Los números de frames coinciden." "Green"
        Write-Host ""
    } else {
        Write-ColorOutput "ERROR: Los números de frames no coinciden." "Red"
        Pause-AndExit
    }

    # Buscar el primer frame EXR en la carpeta FgPlate
    $firstExrFrame = Get-ChildItem -Path $latestFgPlateFolder -Filter "*.exr" | Select-Object -First 1

    # Variables para el thumb
    $thumbRightMargin = 27
    $thumbTopMargin = 48

    # Variables para los textos de la izquierda
    $fontPath = 'C\:\\Windows\\Fonts\\OpenSans-Regular.ttf'
    $fontSizeLeft = 24
    $showNameLeftMargin = 201
    $showNameTopMargin = 34
    $outputFileTopMargin = 104  
    $dateTopMargin = 173
    $shotTypeTopMargin = 243
    $shotTypeText = "COMP"
    
    # Variables para los textos de la derecha
    $fontSizeRight = 20
    $rightTextRightMargin = 30
    $vendorTopMargin = 494
    $vendorText = "WANKA CINE"  
    $rightFileNameTopMargin = 525
    $episodeTopMargin = 558 
    $sceneTopMargin = 622
    $frameCountTopMargin = 752
    $mediaColorTopMargin = 786 

    # Extraer Episode y Scene del nombre del archivo
    $fileNameParts = $newFileName -split '_'
    $episode = $fileNameParts[1]
    $scene = $fileNameParts[2]
 
    # Escapar los caracteres especiales en el texto del conteo de frames
    $frameCountText = "EditRef\: $editRefFrameCount        EXR\: $exrFrameCount"      

    # Definir MediaColor
    $mediaColorText = "Rec709"


    if ($firstExrFrame) {
        $thumbPath = Join-Path $deliveriesMatPath "thumb_temp.jpg"

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

                # Insertar el thumbnail en Placa_template_HD.jpg y agregar texto usando FFmpeg
                $placaTemplatePath = Join-Path $deliveriesMatPath "Placa_template_HD.jpg"
                $placaTemplateOutputPath = Join-Path $deliveriesMatPath "Placa_template_HD_temp.png"


                $ffmpegPlacaArgs = @(
                    "-y",
                    "-i", $placaTemplatePath,
                    "-i", $thumbPath,
                    "-filter_complex",
                    "[1:v]scale=iw*0.1785:-1[thumb];[0:v][thumb]overlay=main_w-overlay_w-$($thumbRightMargin):$($thumbTopMargin),drawtext=fontfile='$fontPath':fontsize=$($fontSizeLeft):fontcolor=white:x=$($showNameLeftMargin):y=$($showNameTopMargin):text='EE',drawtext=fontfile='$fontPath':fontsize=$($fontSizeLeft):fontcolor=white:x=$($showNameLeftMargin):y=$($outputFileTopMargin):text='$newFileName',drawtext=fontfile='$fontPath':fontsize=$($fontSizeLeft):fontcolor=white:x=$($showNameLeftMargin):y=$($dateTopMargin):text='$($currentDate -replace '/', '\\/')',drawtext=fontfile='$fontPath':fontsize=$($fontSizeLeft):fontcolor=white:x=$($showNameLeftMargin):y=$($shotTypeTopMargin):text='$shotTypeText',drawtext=fontfile='$fontPath':fontsize=$($fontSizeRight):fontcolor=white:x=w-tw-$($rightTextRightMargin):y=$($vendorTopMargin):text='$vendorText',drawtext=fontfile='$fontPath':fontsize=$($fontSizeRight):fontcolor=white:x=w-tw-$($rightTextRightMargin):y=$($rightFileNameTopMargin):text='$newFileName',drawtext=fontfile='$fontPath':fontsize=$($fontSizeRight):fontcolor=white:x=w-tw-$($rightTextRightMargin):y=$($episodeTopMargin):text='$episode',drawtext=fontfile='$fontPath':fontsize=$($fontSizeRight):fontcolor=white:x=w-tw-$($rightTextRightMargin):y=$($sceneTopMargin):text='$scene',drawtext=fontfile='$fontPath':fontsize=$($fontSizeRight):fontcolor=white:x=w-tw-$($rightTextRightMargin):y=$($frameCountTopMargin):text='$frameCountText',drawtext=fontfile='$fontPath':fontsize=$($fontSizeRight):fontcolor=white:x=w-tw-$($rightTextRightMargin):y=$($mediaColorTopMargin):text='$mediaColorText'"
                    "-frames:v", "1",
                    "-q:v", "2",
                    $placaTemplateOutputPath
                )


                Write-Host "Insertando thumbnail y texto en Placa_template_HD.jpg usando FFmpeg..."
                & $ffmpegPath @ffmpegPlacaArgs




                if (Test-Path $placaTemplateOutputPath) {
                    Write-ColorOutput "Placa con thumbnail y texto creada exitosamente: $placaTemplateOutputPath" "Green"
                    Write-Host ""
                } else {
                    Write-Host "Error: No se pudo crear la placa con thumbnail y texto."
                    Pause-AndExit
                }
            } else {
                Write-Host "Error: No se pudo guardar el thumbnail."
                Pause-AndExit
            }
        } catch {
            Write-Host "Error al ejecutar oiiotool: $_"
            Pause-AndExit
        }
    } else {
        Write-Host "No se encontraron archivos EXR en la carpeta FgPlate."
        Pause-AndExit
    }

    # ... (resto del código sin cambios) ...
} else {
    if (-not $latestFgPlateFolder) {
        Write-Host "No se pudo encontrar una carpeta FgPlate válida."
    }
    if (-not $latestEditRefFile) {
        Write-Host "No se pudo encontrar un archivo EditRef válido."
    }
    Pause-AndExit
}

Write-Host ""
Write-Host ""

# Obtener el framerate del video de entrada
$framerateOutput = & $ffprobePath -v error -select_streams v:0 -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate $inputMovFile
$framerate = ($framerateOutput -split '/')[0]
Write-Host "Framerate del video de entrada: $framerate"


# Obtener información sobre las pistas de audio
$hasAudio = & $ffprobePath -v error -select_streams a -count_packets -show_entries stream=codec_type -of csv=p=0 $inputMovFile
$audioMapping = if ($hasAudio) { @("-map", "1:a?") } else { @() }


# Usar el $movFrameCount que ya obtuvimos anteriormente
$newDuration = $movFrameCount + 1  # Añadimos 1 frame para la placa
Write-Host "Duración original del video: $movFrameCount frames"
Write-Host "Nueva duración del video con placa: $newDuration frames"

$fontPath = 'C\:\\Windows\\Fonts\\OpenSans-Regular.ttf'

# Comando FFmpeg con barras negras y textos actualizados
$ffmpegArgs = @(
    "-y",
    "-loop", "1", "-t", "0.04167", "-framerate", $framerate, "-i", $placaTemplateOutputPath,
    "-i", $inputMovFile,
    "-filter_complex",
    "[1:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2[scaled];
    [0:v][scaled]concat=n=2:v=1:a=0[v];
    [v]drawbox=y=0:width=iw:height=ceil((ih-(iw/2.35))/2):color=black@0.5:t=fill:enable='not(eq(n,0))',
    drawbox=y=ih-ceil((ih-(iw/2.35))/2):width=iw:height=ceil((ih-(iw/2.35))/2):color=black@0.5:t=fill:enable='not(eq(n,0))',
    drawtext=fontfile='$fontPath':fontsize=22:fontcolor=white:x=20:y=9:text='$newFileName':enable='not(eq(n,0))',
    drawtext=fontfile='$fontPath':fontsize=22:fontcolor=white:x=w-tw-20:y=9:text='$currentDate    WANKA':enable='not(eq(n,0))',
    drawtext=fontfile='$fontPath':fontsize=22:fontcolor=white:x=w-tw-20:y=h-th-10:text='%{eif\:n+999\:d}':start_number=1:enable='not(eq(n,0))'[v_out]",
    "-map", "[v_out]"
)
$ffmpegArgs += $audioMapping
$ffmpegArgs += @(
    "-c:v", "prores_ks",
    "-profile:v", "1",
    "-vendor", "apl0",
    "-b:v", "322640k",
    "-pix_fmt", "yuv422p10le",
    "-r", $framerate,
    "-frames:v", $newDuration,
    "-c:a", "copy",
    $outputFile
)

# Ejecutar FFmpeg
Write-Host "Ejecutando FFmpeg..."
Write-Host "Comando: $ffmpegPath $($ffmpegArgs -join ' ')"
Write-Host "Procesando... Por favor, espere."

try {
    & $ffmpegPath @ffmpegArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-ColorOutput "Proceso completado. El archivo MOV se guardó como $outputFile." "Green"
    } else {
        Write-Host "Error: FFmpeg terminó con código de salida $LASTEXITCODE al crear el archivo MOV"
        Pause-AndExit
    }
} catch {
    Write-Host "Error al ejecutar FFmpeg para crear el archivo MOV: $_"
    Pause-AndExit
}


$mxfOutputFile = [System.IO.Path]::ChangeExtension($outputFile, "mxf")

# Comando FFmpeg para convertir a MXF sin las barras 2.35:1
$ffmpegMxfArgs = @(
    "-y",
    "-loop", "1", "-t", "0.04167", "-framerate", $framerate, "-i", $placaTemplateOutputPath,
    "-i", $inputMovFile,
    "-filter_complex",
    "[1:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2[scaled];
    [0:v][scaled]concat=n=2:v=1:a=0[v];
    [v]drawtext=fontfile='$fontPath':fontsize=22:fontcolor=white:x=20:y=9:text='$newFileName':enable='not(eq(n,0))',
    drawtext=fontfile='$fontPath':fontsize=22:fontcolor=white:x=w-tw-20:y=9:text='$currentDate    WANKA':enable='not(eq(n,0))',
    drawtext=fontfile='$fontPath':fontsize=22:fontcolor=white:x=w-tw-20:y=h-th-10:text='%{eif\:n+999\:d}':start_number=1:enable='not(eq(n,0))'[v_out]",
    "-map", "[v_out]"
)
$ffmpegMxfArgs += $audioMapping
$ffmpegMxfArgs += @(
    "-c:v", "dnxhd",
    "-b:v", "120M",
    "-pix_fmt", "yuv422p",
    "-r", $framerate,
    "-frames:v", $newDuration,
    "-c:a", "pcm_s16le",
    "-ar", "48000",
    "-f", "mxf_opatom",
    $mxfOutputFile
)

# Ejecutar FFmpeg para crear el archivo MXF
Write-Host "Convirtiendo a MXF sin las barras 2.35:1..."
Write-Host "Comando: $ffmpegPath $($ffmpegMxfArgs -join ' ')"
Write-Host "Procesando... Por favor, espere."

try {
    & $ffmpegPath @ffmpegMxfArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-ColorOutput "Proceso completado. El archivo MXF se guardó como $mxfOutputFile." "Green"
    } else {
        Write-Host "Error: FFmpeg terminó con código de salida $LASTEXITCODE al crear el archivo MXF"
        Pause-AndExit
    }
} catch {
    Write-Host "Error al ejecutar FFmpeg para crear el archivo MXF: $_"
    Pause-AndExit
}

Pause-AndExit
