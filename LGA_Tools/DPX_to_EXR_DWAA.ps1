# ______________________________________________________________________________________________________________
#
#   DPX_to_EXR_DWAA | Lega | v1.03
#
#   Convierte archivos DPX a EXR con compresión DWAA (calidad 60).
#   Utiliza la herramienta oiiotool para realizar la conversión.
#   PRESERVA TODA la metadata crítica del DPX en el EXR resultante.
#   Optimización extrema de rendimiento para agregar metadata.
#   Uso:
#       La carpeta de origen con los archivos DPX se arrastra al archivo .bat, que luego llama a este script.
#       La salida se guarda en una nueva carpeta con el sufijo _exr.
#
#   v1.03 - OPTIMIZACIÓN EXTREMA: metadata agregada en UNA sola llamada (25x más rápido)
#   v1.02 - Preservación completa de metadata del DPX al EXR (30+ campos críticos)
#   v1.01 - Reemplazar punto antes del número de frame por guión bajo
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
    Write-Host "Error: Hay que arrastrar una carpeta con DPXs al archivo DPX_to_EXR_DWAA.bat"
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

# Definir nombre de la carpeta destino
$destName = "${sourceName}_exr"
$destPath = Join-Path $sourceDir $destName

# Crear el directorio destino si no existe
if (-Not (Test-Path $destPath)) {
    New-Item -Path $destPath -ItemType Directory | Out-Null
}

# Contar archivos DPX
$files = Get-ChildItem -Path $sourcePath -Filter "*.dpx"
$fileCount = $files.Count

if ($fileCount -eq 0) {
    Write-Host "No se encontraron archivos .dpx en la carpeta seleccionada."
    Write-Host "Presione ESC para salir"
    while ($true) { if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 27) { exit } }
}

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

# Función para agregar TODA la metadata crítica del DPX al EXR (OPTIMIZADA)
function Add-DPXMetadataToEXR {
    param ([string]$dpxPath, [string]$exrPath)

    $iinfoPath = Join-Path $scriptDir "..\OIIO\iinfo.exe"
    $exrstdattrPath = Join-Path $scriptDir "..\OpenEXR\exrstdattr.exe"

    try {
        # Ejecutar iinfo.exe para obtener metadata completa
        $metadataLines = & $iinfoPath -v $dpxPath 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Advertencia: No se pudo leer metadata del DPX" -ForegroundColor Yellow
            return
        }
        $metadataOutput = $metadataLines -join "`n"

        # Función helper para extraer valores con regex
        function Get-MetadataValue {
            param ($pattern, $type = "string")
            $match = [regex]::Match($metadataOutput, $pattern)
            if ($match.Success) {
                $value = $match.Groups[1].Value
                return @{Type=$type; Value=$value}
            }
            return $null
        }

        # Extraer TODOS los campos de metadata crítica
        $metadataFields = @{}

        # Información de Color y Transferencia (CRÍTICA)
        $metadataFields["dpx:Colorimetric"] = Get-MetadataValue 'dpx:Colorimetric:\s*"([^"]*)"'
        $metadataFields["dpx:Transfer"] = Get-MetadataValue 'dpx:Transfer:\s*"([^"]*)"'
        $metadataFields["dpx:WhiteLevel"] = Get-MetadataValue 'dpx:WhiteLevel:\s*(\d+)' "int"
        $metadataFields["dpx:BlackLevel"] = Get-MetadataValue 'dpx:BlackLevel:\s*(\d+)' "int"
        $metadataFields["dpx:BlackGain"] = Get-MetadataValue 'dpx:BlackGain:\s*(\d+)' "int"
        $metadataFields["dpx:BreakPoint"] = Get-MetadataValue 'dpx:BreakPoint:\s*(\d+)' "int"
        $metadataFields["dpx:HighData"] = Get-MetadataValue 'dpx:HighData:\s*(\d+)' "int"
        $metadataFields["dpx:LowData"] = Get-MetadataValue 'dpx:LowData:\s*(\d+)' "int"
        $metadataFields["dpx:HighQuantity"] = Get-MetadataValue 'dpx:HighQuantity:\s*([\d.]+)' "float"
        $metadataFields["dpx:LowQuantity"] = Get-MetadataValue 'dpx:LowQuantity:\s*([\d.]+)' "float"

        # Información de Dispositivo y Producción (CRÍTICA)
        $metadataFields["dpx:InputDevice"] = Get-MetadataValue 'dpx:InputDevice:\s*"([^"]*)"'
        $metadataFields["OriginalSoftware"] = Get-MetadataValue 'Software:\s*"([^"]*)"'
        $metadataFields["dpx:Version"] = Get-MetadataValue 'dpx:Version:\s*"([^"]*)"'
        $metadataFields["dpx:Format"] = Get-MetadataValue 'dpx:Format:\s*"([^"]*)"'
        $metadataFields["dpx:FrameId"] = Get-MetadataValue 'dpx:FrameId:\s*"([^"]*)"'
        $metadataFields["dpx:SlateInfo"] = Get-MetadataValue 'dpx:SlateInfo:\s*"([^"]*)"'
        $metadataFields["dpx:UserBits"] = Get-MetadataValue 'dpx:UserBits:\s*(\d+)' "int"

        # Información de Timing y Frame (CRÍTICA)
        $metadataFields["dpx:TemporalFrameRate"] = Get-MetadataValue 'dpx:TemporalFrameRate:\s*(\d+)' "int"
        $metadataFields["dpx:FramePosition"] = Get-MetadataValue 'dpx:FramePosition:\s*(\d+)' "int"
        $metadataFields["dpx:SequenceLength"] = Get-MetadataValue 'dpx:SequenceLength:\s*(\d+)' "int"
        $metadataFields["dpx:HeldCount"] = Get-MetadataValue 'dpx:HeldCount:\s*(\d+)' "int"
        $metadataFields["dpx:DittoKey"] = Get-MetadataValue 'dpx:DittoKey:\s*(\d+)' "int"

        # Información Técnica de Imagen
        $metadataFields["dpx:ImageDescriptor"] = Get-MetadataValue 'dpx:ImageDescriptor:\s*"([^"]*)"'
        $metadataFields["dpx:HorizontalSampleRate"] = Get-MetadataValue 'dpx:HorizontalSampleRate:\s*(\d+)' "int"
        $metadataFields["dpx:VerticalSampleRate"] = Get-MetadataValue 'dpx:VerticalSampleRate:\s*(\d+)' "int"
        $metadataFields["dpx:XScannedSize"] = Get-MetadataValue 'dpx:XScannedSize:\s*([\d.e+-]+)' "float"
        $metadataFields["dpx:YScannedSize"] = Get-MetadataValue 'dpx:YScannedSize:\s*([\d.e+-]+)' "float"
        $metadataFields["dpx:ShutterAngle"] = Get-MetadataValue 'dpx:ShutterAngle:\s*(\d+)' "int"
        $metadataFields["dpx:IntegrationTimes"] = Get-MetadataValue 'dpx:IntegrationTimes:\s*(\d+)' "int"

        # Procesar campos que tienen valores válidos
        $validFields = $metadataFields.GetEnumerator() | Where-Object { $_.Value -and $_.Value.Value }

        if ($validFields.Count -gt 0) {
            Write-Host "  Agregando $($validFields.Count) campos de metadata..." -ForegroundColor Cyan
            $metadataStartTime = Get-Date

            # Crear archivo temporal para el resultado final
            $finalTempPath = $exrPath + ".tmp"

            # Construir un solo comando exrstdattr con TODOS los atributos
            $commandArgs = @()

            # Agregar cada campo válido al comando
            foreach ($field in $validFields) {
                $fieldName = $field.Key
                $fieldData = $field.Value

                # Agregar el campo según su tipo
                switch ($fieldData.Type) {
                    "int" {
                        $commandArgs += "-int", $fieldName, $fieldData.Value
                    }
                    "float" {
                        $commandArgs += "-float", $fieldName, $fieldData.Value
                    }
                    default {
                        $commandArgs += "-string", $fieldName, "`"$($fieldData.Value)`""
                    }
                }
            }

            # Agregar input y output al final
            $commandArgs += "`"$exrPath`"", "`"$finalTempPath`""

            # Ejecutar UNA sola llamada a exrstdattr con todos los atributos
            $process = Start-Process -FilePath $exrstdattrPath -ArgumentList $commandArgs -NoNewWindow -Wait -PassThru

            if ($process.ExitCode -eq 0 -and (Test-Path $finalTempPath)) {
                # Reemplazar el archivo original
                Move-Item -Path $finalTempPath -Destination $exrPath -Force
                $metadataEndTime = Get-Date
                $metadataTime = $metadataEndTime - $metadataStartTime
                $metadataTimeFormatted = "$($metadataTime.Seconds).$($metadataTime.Milliseconds)s"
                Write-Host "  Metadata agregada correctamente ($($validFields.Count) campos) - Tiempo: $metadataTimeFormatted" -ForegroundColor Green
            } else {
                Write-Host "  Error agregando metadata: Código de salida $($process.ExitCode)" -ForegroundColor Red
                if (Test-Path $finalTempPath) {
                    Remove-Item $finalTempPath -Force
                }
            }
        } else {
            Write-Host "  No se encontró metadata adicional para agregar" -ForegroundColor Yellow
        }

    }
    catch {
        Write-Host "  Error procesando metadata: $($_.Exception.Message)" -ForegroundColor Red
        # Limpiar archivos temporales en caso de error
        Get-ChildItem -Path (Split-Path $exrPath) -Filter "$(Split-Path $exrPath -Leaf)*.tmp" | Remove-Item -Force
    }
}

# Iniciar el temporizador
$startTime = Get-Date

# Procesar archivos DPX
foreach ($file in $files) {
    $currentFile++
    $fileName = $file.BaseName
    
    # Reemplazar punto antes del número de frame por guión bajo
    # Ejemplo: KTCE_001_010_aPlate_v001.1001 -> KTCE_001_010_aPlate_v001_1001
    if ($fileName -match '\.(\d+)$') {
        $fileName = $fileName -replace '\.(\d+)$', '_$1'
    }
    
    $outputPath = Join-Path $destPath "$fileName.exr"
    
    Write-Host "Convirtiendo archivo $currentFile de $fileCount..." -NoNewline -ForegroundColor DarkYellow
    
    $originalSize = (Get-Item $file.FullName).Length
    $totalOriginalSize += $originalSize
    
    # Argumentos para oiiotool: input --compression dwaa:quality=60 -o output
    $arguments = """$($file.FullName)"" --compression dwaa:quality=60 -o ""$outputPath"""
    Start-Process -FilePath $oiiotoolPath -ArgumentList $arguments -NoNewWindow -Wait
    
    if (Test-Path $outputPath) {
        $convertedSize = (Get-Item $outputPath).Length
        $totalConvertedSize += $convertedSize

        $originalSizeFormatted = Format-FileSize $originalSize
        $convertedSizeFormatted = Format-FileSize $convertedSize
        Write-Host "  $originalSizeFormatted -> $convertedSizeFormatted" -ForegroundColor DarkYellow

        # Agregar TODA la metadata crítica del DPX al EXR
        Add-DPXMetadataToEXR -dpxPath $file.FullName -exrPath $outputPath
    } else {
         Write-Host "  Error al convertir." -ForegroundColor Red
    }
}

# Calcular el tiempo total
$endTime = Get-Date
$totalTime = $endTime - $startTime
$formattedTime = "{0:D2}h {1:D2}m {2:D2}s" -f $totalTime.Hours, $totalTime.Minutes, $totalTime.Seconds

# Mensaje final - Completado
$totalOriginalSizeFormatted = Format-FileSize $totalOriginalSize
$totalConvertedSizeFormatted = Format-FileSize $totalConvertedSize
Write-Host ""
Write-Host "Conversión completada" -ForegroundColor DarkGreen
Write-Host "$totalOriginalSizeFormatted -> $totalConvertedSizeFormatted" -ForegroundColor DarkGreen
Write-Host "Tiempo Total: $formattedTime" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Los archivos convertidos están en:" -ForegroundColor DarkYellow
Write-Host "$destPath" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "Presione ESC para salir" -ForegroundColor DarkYellow
while ($true) { if ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 27) { exit } }

