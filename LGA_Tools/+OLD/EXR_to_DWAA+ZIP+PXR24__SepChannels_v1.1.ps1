# __________________________________________________________________________________________________________________________
#
#   Convierte archivos EXR multicanal a archivos EXR individuales por canal, con compresión Pxr24.
#   Utiliza la herramienta oiiotool para realizar la conversión y exrheader para leer los canales.
#
#   Corrige los nombres de los canales eliminando "FinalImageMovieRenderQueue_" 
#   y reemplazando ActorHitProxyMask por CryptoMatte.
#
#   Uso:
#       La carpeta de origen con los archivos EXR se arrastra al archivo .bat, que luego llama a este script.
#       La salida se guarda en nuevas subcarpetas con los archivos divididos por canal y con la compresión Pxr24 aplicada.
#
#   Lega - 2024
# __________________________________________________________________________________________________________________________


# Obtener la ruta del script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$oiiotoolPath = Join-Path $scriptDir "..\Oiio\oiiotool.exe"
$exrheaderPath = Join-Path $scriptDir "..\OpenEXR\exrheader.exe"

# Verificar si oiiotool.exe y exrheader.exe existen en esa ruta
if (-Not (Test-Path $oiiotoolPath) -or -Not (Test-Path $exrheaderPath)) {
    Write-Host "Error: No se encuentra oiiotool.exe o exrheader.exe en la misma carpeta que este script."
    Write-Host "Chequear que existan en: $scriptDir"
    Write-Host "Presione ESC para salir"
    while ($true) { if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 27) { exit } }
}

# Obtener el directorio de origen
$sourcePath = $args[0]
if (-Not $sourcePath) {
    Write-Host "Error: Hay que arrastrar una carpeta con EXRs al archivo EXR_to_Channels_Pxr24.bat"
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

# Contar archivos EXR
$files = Get-ChildItem -Path $sourcePath -Filter "*.exr"
$fileCount = $files.Count

# Función para convertir bytes a una representación legible
function Format-FileSize {
    param ([long]$size)
    if ($size -gt 1TB) { return "{0:N2} TB" -f ($size / 1TB) }
    if ($size -gt 1GB) { return "{0:N2} GB" -f ($size / 1GB) }
    if ($size -gt 1MB) { return "{0:N2} MB" -f ($size / 1MB) }
    if ($size -gt 1KB) { return "{0:N2} KB" -f ($size / 1KB) }
    return "$size B"
}

# Función para obtener los nombres de los canales, tratando RGBA como un solo canal
function Get-ChannelNames {
    param ($inputExr)
    $channels = & $exrheaderPath $inputExr | 
        Select-String -Pattern "^\s+(\w+)" |
        ForEach-Object { $_.Matches.Groups[1].Value }
    
    $rgbaChannel = @()
    $otherChannels = @()
    
    foreach ($channel in $channels) {
        if ($channel -match '^[RGBA]$') {
            $rgbaChannel += $channel
        } else {
            $otherChannels += $channel.Split('.')[0]
        }
    }
    
    if ($rgbaChannel.Count -gt 0) {
        $otherChannels = @("RGBA") + ($otherChannels | Select-Object -Unique)
    } else {
        $otherChannels = $otherChannels | Select-Object -Unique
    }
    
    return $otherChannels
}

# Función para agrupar canales con numeración consecutiva
function Group-Channels {
    param($channels)
    $groups = @{}
    foreach ($channel in $channels) {
        if ($channel -eq "RGBA") {
            $groups[$channel] = @($channel)
        } else {
            $baseName = $channel -replace '\d+$'
            if (-not $groups.ContainsKey($baseName)) {
                $groups[$baseName] = @()
            }
            $groups[$baseName] += $channel
        }
    }
    return $groups
}

# Solo correr una vez el exrheader en el primer archivo EXR
$firstFile = $files[0].FullName
$channels = Get-ChannelNames -inputExr $firstFile

# Extraer solo el nombre del archivo EXR (sin la ruta completa)
$exrFileName = Split-Path $firstFile -Leaf

# Imprimir los canales encontrados con el nombre del archivo y en color Dark Yellow
Write-Host "Canales encontrados en $exrFileName :" -ForegroundColor DarkYellow

foreach ($channel in $channels) {
    Write-Host "  $channel" -ForegroundColor DarkYellow
}
Write-Host ""
Write-Host ""

# Agrupar los canales
$groupedChannels = Group-Channels $channels

# Iniciar el temporizador
$startTime = Get-Date

# Procesar archivos EXR
$currentFile = 0
foreach ($file in $files) {
    $currentFile++
    $fileName = $file.BaseName

    # Crear carpeta por cada canal, con el nombre original ajustado
    foreach ($group in $groupedChannels.GetEnumerator()) {
        $baseName = $group.Key
        if ($baseName -eq "RGBA") {
            $channelList = "R,G,B,A"
        } else {
                $channelList = ($group.Value | ForEach-Object { "$_.R,$_.G,$_.B,$_.A" }) -join ","
        }

        # Eliminar "FinalImageMovieRenderQueue_" si está presente en el nombre del canal
        if ($baseName -like "*FinalImageMovieRenderQueue_*") {
            $baseName = $baseName -replace "FinalImageMovieRenderQueue_", ""
        }

        # Reemplazar "ActorHitProxyMask" por "Cryptomatte" si está presente en el nombre del canal
        if ($baseName -like "*ActorHitProxyMask*") {
            $baseName = $baseName -replace "ActorHitProxyMask", "Cryptomatte"
        }

        # Crear el nombre base para la carpeta, reemplazando "piz" por "pxr24" y agregando el canal al final
        if ($sourceName -like "*piz*") {
            $sourceNameModified = $sourceName -replace 'piz', 'pxr24'
        } else {
            $sourceNameModified = "$sourceName-pxr24"
        }

        # Separar el nombre de la carpeta antes y después de "BGclean" (u otros identificadores)
        $nameParts = $sourceNameModified -split "_BGclean"
        $newName = "$($nameParts[0])_BGclean$($nameParts[1])-$baseName"

        # Crear la ruta del directorio de salida
        $outputDirChannels = Join-Path $sourceDir $newName

        # Crear directorio para ese canal si no existe
        if (-Not (Test-Path $outputDirChannels)) {
            New-Item -Path $outputDirChannels -ItemType Directory | Out-Null
            $createdFolders += $outputDirChannels
        }

        # Asegurarse de que el archivo de salida esté correctamente escapado
        $lastSeparatorIndex = $fileName.LastIndexOfAny(@('_', '.'))

        if ($lastSeparatorIndex -ge 0) {
            $possibleFrame = $fileName.Substring($lastSeparatorIndex + 1)
            if ($possibleFrame -match '^\d+$') {
                $baseFileName = $fileName.Substring(0, $lastSeparatorIndex)
                $frameNumber = $fileName.Substring($lastSeparatorIndex)
                $outputFile = Join-Path $outputDirChannels "$baseFileName-$baseName$frameNumber.exr"
            } else {
                $outputFile = Join-Path $outputDirChannels "$fileName-$baseName.exr"
            }
        } else {
            $outputFile = Join-Path $outputDirChannels "$fileName-$baseName.exr"
        }

        Write-Host "Exportando archivo $currentFile de $fileCount - Canal $baseName" -ForegroundColor DarkYellow

        # Verificar que la longitud de la ruta no exceda el límite de Windows
        if ($outputFile.Length -gt 260) {
            Write-Host "Error: La longitud de la ruta es demasiado larga." -ForegroundColor Red
            continue
        }

        # Usar oiiotool para extraer los canales y crear un archivo nuevo
        $arguments = """$($file.FullName)"" --ch $channelList --compression pxr24 -o ""$outputFile"""
        Start-Process -FilePath $oiiotoolPath -ArgumentList $arguments -NoNewWindow -Wait
    }
}

# Calcular el tiempo total
$endTime = Get-Date
$totalTime = $endTime - $startTime
$formattedTime = "{0:D2}h {1:D2}m {2:D2}s" -f $totalTime.Hours, $totalTime.Minutes, $totalTime.Seconds

# Calcular el tamaño total de los archivos EXR originales
$totalOriginalSize = (Get-ChildItem -Path $sourcePath -Filter "*.exr" | Measure-Object -Property Length -Sum).Sum
#Write-Host "Tamaño total original: $totalOriginalSize bytes" -ForegroundColor Cyan

# Calcular el tamaño total de los archivos EXR convertidos
$totalConvertedSize = 0
$uniqueFolders = $groupedChannels.Keys | ForEach-Object {
    $baseName = $_

    # Eliminar "FinalImageMovieRenderQueue_" si está presente en el nombre del canal
    if ($baseName -like "*FinalImageMovieRenderQueue_*") {
        $baseName = $baseName -replace "FinalImageMovieRenderQueue_", ""
    }

    # Reemplazar "ActorHitProxyMask" por "Cryptomatte" si está presente en el nombre del canal
    if ($baseName -like "*ActorHitProxyMask*") {
        $baseName = $baseName -replace "ActorHitProxyMask", "Cryptomatte"
    }

    # Crear el nombre base para la carpeta
    if ($sourceName -like "*piz*") {
        $sourceNameModified = $sourceName -replace 'piz', 'pxr24'
    } else {
        $sourceNameModified = "$sourceName-pxr24"
    }

    # Separar el nombre de la carpeta antes y después de "BGclean" (u otros identificadores)
    $nameParts = $sourceNameModified -split "_BGclean"
    $newName = "$($nameParts[0])_BGclean$($nameParts[1])-$baseName"

    # Crear la ruta del directorio de salida
    Join-Path $sourceDir $newName
}

#Write-Host "Carpetas procesadas:" -ForegroundColor Cyan
foreach ($folder in $uniqueFolders | Select-Object -Unique) {
    if (Test-Path $folder) {
        #Write-Host "  Procesando carpeta: $folder" -ForegroundColor Cyan
        $folderFiles = Get-ChildItem -Path $folder -Filter "*.exr"
        $folderSize = ($folderFiles | Measure-Object -Property Length -Sum).Sum
        #Write-Host "    Número de archivos EXR: $($folderFiles.Count)" -ForegroundColor Cyan
        #Write-Host "    Tamaño de la carpeta: $folderSize bytes" -ForegroundColor Cyan
        $totalConvertedSize += $folderSize
    } else {
        Write-Host "  Carpeta no encontrada: $folder" -ForegroundColor Red
    }
}

# Formatear los tamaños para hacerlos legibles
$totalOriginalSizeFormatted = Format-FileSize $totalOriginalSize
$totalConvertedSizeFormatted = Format-FileSize $totalConvertedSize

# Imprimir los resultados
Write-Host ""
Write-Host "Conversion completada" -ForegroundColor DarkGreen
Write-Host "$totalOriginalSizeFormatted -> $totalConvertedSizeFormatted" -ForegroundColor DarkGreen
Write-Host "Tiempo Total: $formattedTime" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Los EXR convertidos estan en subcarpetas por canal dentro de:" -ForegroundColor DarkYellow
Write-Host "$sourceDir" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "Presione ESC para salir" -ForegroundColor DarkYellow
while ($true) { if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 27) { exit } }
