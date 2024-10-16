# ______________________________________________________________________________________________________________
#
#   Verifica la integridad de archivos EXR en una carpeta y sus subcarpetas.
#   Funcionalidades principales:
#     - Recibe la ruta de una carpeta como argumento.
#     - Opción para verificar solo carpetas que contengan "input" en su nombre.
#     - Escanea recursivamente todas las subcarpetas.
#     - Utiliza exrcheck para verificar la integridad de cada archivo EXR encontrado.
#     - Genera un reporte RTF de archivos corruptos con sus rutas completas.
#     - Permite cancelar la operación presionando Ctrl+C en cualquier momento.
#   Uso:
#     Este script es llamado por EXR_Checker.bat al arrastrar una carpeta sobre él.
#   Requisitos:
#     - exrcheck debe estar en la carpeta OpenEXR relativa a la ubicación del script.
#   Lega - 2024 - v1.3
# ______________________________________________________________________________________________________________

# Configurar la codificación de salida a UTF-8 para la consola
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Función para escapar caracteres especiales en RTF
function Escape-RtfString {
    param (
        [string]$text
    )
    $text = $text -replace '\\', '\\\\'
    $text = $text -replace '{', '\{'
    $text = $text -replace '}', '\}'
    return $text
}

# Función para verificar si un archivo está bloqueado
function Test-FileLock {
    param (
        [string]$filePath
    )
    $locked = $false
    try {
        $fileStream = [System.IO.File]::Open($filePath, 'Open', 'ReadWrite', 'None')
        if ($fileStream) {
            $fileStream.Close()
        }
    }
    catch {
        $locked = $true
    }
    return $locked
}

# Obtener la ruta del script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exrcheckPath = Join-Path (Split-Path -Parent $scriptDir) "OpenEXR\exrcheck.exe"

# Verificar que exrcheck está instalado
if (-not (Test-Path $exrcheckPath)) {
    Write-Host "Error: No se pudo encontrar exrcheck en $exrcheckPath" -ForegroundColor Red
    Write-Host "Por favor, asegúrese de que exrcheck.exe está en la carpeta OpenEXR." -ForegroundColor Red
    exit 1
}

# Verificar que se proporcionó un argumento (ruta de la carpeta)
if ($args.Count -eq 0) {
    Write-Host "Error: No se proporcionó ninguna carpeta como argumento." -ForegroundColor Red
    exit 1
}

$folderPath = $args[0]

# Verificar que la carpeta existe
if (-not (Test-Path $folderPath -PathType Container)) {
    Write-Host "Error: La carpeta especificada no existe: $folderPath" -ForegroundColor Red
    exit 1
}

# Preguntar si se quiere verificar solo las carpetas de input
$checkOnlyInput = Read-Host "¿Desea verificar solo archivos EXR en carpetas que contengan 'input'? (s/n)"
$checkOnlyInput = $checkOnlyInput.ToLower() -eq 's'

# Mensaje de inicio sobre cómo cancelar la operación
Write-Host "Puedes presionar Ctrl+C en cualquier momento para cancelar la operación." -ForegroundColor Yellow

# Definir la ruta del reporte RTF
$reportPath = Join-Path $folderPath "EXR_Checker_Report.rtf"

# Verificar si el archivo RTF está siendo usado por otro proceso
if (Test-Path $reportPath) {
    if (Test-FileLock -filePath $reportPath) {
        Write-Host "Error: El archivo RTF ya está siendo usado por otro proceso. Por favor, ciérrelo e intente de nuevo." -ForegroundColor Red
        exit 1
    }
}

# Función para escribir resúmenes por carpeta en el RTF
function Write-RTFSummary {
    param (
        [string]$folderPath,
        [array]$corruptFiles
    )
    $escapedFolderPath = Escape-RtfString $folderPath
    $rtfLine = "\par{\cf0 $escapedFolderPath "
    
    if ($corruptFiles.Count -eq 0) {
        $message = "Todos los archivos en esta carpeta son válidos.}"
        $rtfLine += "{\cf4 $message}\par\par"
    }
    else {
        $message = "Archivos corruptos encontrados en esta carpeta:}"
        $rtfLine += "{\cf6 $message}\par"
        foreach ($file in $corruptFiles) {
            $escapedFile = Escape-RtfString (Split-Path $file -Leaf)
            $rtfLine += "{\cf6  - $escapedFile}\par"
        }
        $rtfLine += "\par"
    }

    try {
        $global:rtfWriter.WriteLine($rtfLine)
        $global:rtfWriter.Flush()
    }
    catch {
        Write-Host "Error al escribir en el archivo RTF: $_" -ForegroundColor Red
    }
}

# Función para escribir carpetas saltadas en el RTF
function Write-RTFSkippedFolder {
    param (
        [string]$folderPath,
        [string]$reason
    )
    $escapedFolderPath = Escape-RtfString $folderPath
    $rtfLine = "{\cf0 $escapedFolderPath "
    $rtfLine += "{\cf3 Carpeta saltada: $reason}}\par"

    try {
        $global:rtfWriter.WriteLine($rtfLine)
        $global:rtfWriter.Flush()
    }
    catch {
        Write-Host "Error al escribir en el archivo RTF: $_" -ForegroundColor Red
    }
}

# Función para imprimir en color en la consola
function Write-ColorOutput {
    param (
        [string]$message,
        [string]$color = "White",
        [switch]$newLine = $false
    )
    if ($color -ne "White") {
        if ([Enum]::IsDefined([System.ConsoleColor], $color)) {
            Write-Host $message -ForegroundColor $color -NoNewline
        }
        else {
            Write-Host $message -NoNewline
        }
    }
    else {
        Write-Host $message -NoNewline
    }
    if ($newLine) {
        Write-Host
    }
}

# Función para procesar carpetas recursivamente
function Process-Folder {
    param (
        [string]$folderPath
    )

    $corruptFiles = @()
    $processedFiles = 0

    $exrFiles = Get-ChildItem -Path $folderPath -Filter "*.exr" -ErrorAction SilentlyContinue

    # Verificar si la ruta completa contiene "input" si se ha solicitado
    if ($checkOnlyInput) {
        if ($folderPath -notlike "*input*") {
            # Consola: imprimir carpeta y mensaje en la misma línea
            Write-ColorOutput "$folderPath " "White" -NoNewline
            Write-ColorOutput "Carpeta saltada (no contiene 'input')" "Cyan" -newLine
            # RTF: escribir carpeta saltada
            Write-RTFSkippedFolder -folderPath $folderPath -reason "No contiene 'input'"
            # Continuar procesando subcarpetas
            Get-ChildItem -Path $folderPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $subFolderResults = Process-Folder -folderPath $_.FullName
                $corruptFiles += $subFolderResults.CorruptFiles
                $processedFiles += $subFolderResults.ProcessedFiles
            }
            return @{
                CorruptFiles   = $corruptFiles
                ProcessedFiles = $processedFiles
            }
        }
    }

    if ($exrFiles.Count -eq 0) {
        # Consola: imprimir carpeta y mensaje en la misma línea
        Write-ColorOutput "$folderPath " "White" -NoNewline
        Write-ColorOutput "Carpeta sin archivos EXR" "Cyan" -newLine
        # RTF: escribir carpeta sin archivos EXR
        Write-RTFSkippedFolder -folderPath $folderPath -reason "No contiene archivos EXR"
    }
    else {
        # Eliminar el salto de línea extra antes de procesar los archivos EXR
        # $global:rtfWriter.WriteLine("\par")
        
        foreach ($file in $exrFiles) {
            Write-Host "Verificando: $($file.FullName)" -NoNewline
            try {
                $exrcheckOutput = & $exrcheckPath $file.FullName 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-ColorOutput "  Archivo corrupto o con problemas" "Red" -newLine
                    $corruptFiles += $file.FullName
                }
                else {
                    Write-ColorOutput "  Archivo válido" "Green" -newLine
                }
                $processedFiles++
            }
            catch {
                Write-ColorOutput "  Error al procesar el archivo" "Red" -newLine
                $corruptFiles += $file.FullName
                $processedFiles++
            }
        }

        # Escribir resumen en RTF
        Write-RTFSummary -folderPath $folderPath -corruptFiles $corruptFiles
        
        # Eliminar el salto de línea extra después de procesar los archivos EXR
        # $global:rtfWriter.WriteLine("\par")
    }

    # Procesar subcarpetas
    Get-ChildItem -Path $folderPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $subFolderResults = Process-Folder -folderPath $_.FullName
        $corruptFiles += $subFolderResults.CorruptFiles
        $processedFiles += $subFolderResults.ProcessedFiles
    }

    return @{
        CorruptFiles   = $corruptFiles
        ProcessedFiles = $processedFiles
    }
}

# Inicio del proceso con manejo de interrupciones
try {
    # Inicializar el StreamWriter para el reporte RTF con codificación Windows-1252
    $rtfWriter = New-Object System.IO.StreamWriter($reportPath, $false, [System.Text.Encoding]::GetEncoding(1252))

    # Escribir los encabezados de RTF con fuente Arial, tamaño 6, y colores más oscuros
    $rtfWriter.WriteLine("{\rtf1\ansi\ansicpg1252\deff0")
    $rtfWriter.WriteLine("{\fonttbl {\f0 Arial;}}")
    $rtfWriter.WriteLine("{\colortbl ;\red255\green0\blue0;\red0\green128\blue0;\red0\green0\blue255;\red0\green100\blue0;\red255\green255\blue0;\red128\green0\blue0;\red0\green0\blue0;}")
    $rtfWriter.WriteLine("\f0\fs12\b Reporte de Verificación de Integridad de Archivos EXR\b0\par")

    $fecha = Escape-RtfString (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $rtfWriter.WriteLine("Fecha: $fecha\par")

    $carpetaEscaneada = Escape-RtfString $folderPath
    $rtfWriter.WriteLine("Carpeta escaneada: $carpetaEscaneada\par")

    # Reemplazar el operador ternario por una estructura if-else
    if ($checkOnlyInput) {
        $verificacion = "Sí"
    }
    else {
        $verificacion = "No"
    }
    $rtfWriter.WriteLine("Verificando solo carpetas de input: $verificacion\par\par")
    $rtfWriter.Flush()

    # Guardar el StreamWriter en una variable global para uso en funciones
    $global:rtfWriter = $rtfWriter

    Write-Host "Verificando archivos EXR en $folderPath y sus subcarpetas"
    Write-Host "El reporte RTF se generará en: $reportPath"
    Write-Host ""

    # Escribir información inicial en el reporte RTF (opcional)
    # Write-RTFSkippedFolder -folderPath "Inicio del reporte"

    # Iniciar el proceso de verificación
    $results = Process-Folder -folderPath $folderPath

    Write-Host ""

    if ($results.ProcessedFiles -eq 0) {
        Write-ColorOutput "No se encontraron archivos EXR para procesar." "Yellow" -newLine
    }
    elseif ($results.CorruptFiles.Count -eq 0) {
        Write-ColorOutput "Todos los archivos EXR están intactos." "Green" -newLine
    }
    else {
        Write-ColorOutput "Se encontraron $($results.CorruptFiles.Count) archivos corruptos o con problemas:" "Red" -newLine
        foreach ($corruptFile in $results.CorruptFiles) {
            Write-ColorOutput "  $corruptFile" "Red" -newLine
        }
    }

    Write-Host ""
    Write-Host "Verificación completada. Total de archivos procesados: $($results.ProcessedFiles)"

    # Finalizar y cerrar el reporte RTF
    Write-ColorOutput "Se ha generado un reporte detallado en: $reportPath" "Blue" -newLine

}
catch {
    Write-Host "Error durante el proceso: $_" -ForegroundColor Red
}
finally {
    # Cerrar el documento RTF correctamente
    if ($global:rtfWriter) {
        try {
            $global:rtfWriter.WriteLine("}")
            $global:rtfWriter.Flush()
            $global:rtfWriter.Close()
        }
        catch {
            Write-Host "Error al cerrar el archivo RTF: $_" -ForegroundColor Red
        }
    }
}

# Verificar si el archivo se creó
if (Test-Path $reportPath) {
    Write-Host "El archivo RTF se creó correctamente." -ForegroundColor Green
    Write-Host "Tamaño del archivo: $((Get-Item $reportPath).Length) bytes" -ForegroundColor Green
}
else {
    Write-Host "Error: No se pudo encontrar el archivo RTF después de crearlo." -ForegroundColor Red
}

# Mostrar los archivos en la carpeta de destino
Write-Host "Contenido de la carpeta de destino:"
Get-ChildItem -Path $folderPath | ForEach-Object { 
    $item = $_
    if ($item.Name -eq "EXR_Checker_Report.rtf") {
        Write-Host "$($item.Name) (Tamaño: $($item.Length) bytes)" -ForegroundColor Green
    }
    else {
        Write-Host $item.Name
    }
}

# Intentar abrir el archivo RTF
try {
    Start-Process $reportPath
    Write-Host "Intentando abrir el archivo RTF..."
}
catch {
    Write-Host "No se pudo abrir el archivo RTF automáticamente. Por favor, ábralo manualmente." -ForegroundColor Yellow
}
