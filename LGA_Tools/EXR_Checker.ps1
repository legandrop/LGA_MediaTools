# ______________________________________________________________________________________________________________
#
#   Verifica la integridad de archivos EXR en una carpeta y sus subcarpetas.
#   Funcionalidades principales:
#     - Recibe la ruta de una carpeta como argumento.
#     - Opción para verificar solo carpetas que contengan "input" en su nombre.
#     - Escanea recursivamente todas las subcarpetas.
#     - Utiliza exrcheck para verificar la integridad de cada archivo EXR encontrado.
#     - Genera un reporte de archivos corruptos con sus rutas completas.
#   Uso:
#     Este script es llamado por EXR_Checker.bat al arrastrar una carpeta sobre él.
#   Requisitos:
#     - exrcheck debe estar en la carpeta OpenEXR relativa a la ubicación del script.
#   Lega - 2024 - v1.1
# ______________________________________________________________________________________________________________

# Configurar la codificación de salida a UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Función para imprimir en color
function Write-ColorOutput {
    param (
        [string]$message,
        [string]$color = "White",
        [string]$path = "",
        [string]$status = "",
        [switch]$newLine = $false
    )
    $validColors = [Enum]::GetNames([System.ConsoleColor])
    if ($path -ne "") {
        Write-Host "$path " -NoNewline  # Agregamos un espacio después de la ruta
    }
    if ($validColors -contains $color) {
        if ($status -ne "") {
            Write-Host "$status" -ForegroundColor $color -NoNewline
        } else {
            Write-Host $message -ForegroundColor $color -NoNewline
        }
    }
    else {
        if ($status -ne "") {
            Write-Host "$status" -NoNewline
        } else {
            Write-Host $message -NoNewline
        }
    }
    if ($newLine) {
        Write-Host  # Agregar un salto de línea solo si se especifica
    }
}

# Obtener la ruta del script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exrcheckPath = Join-Path (Split-Path -Parent $scriptDir) "OpenEXR\exrcheck.exe"

# Verificar que exrcheck está instalado
if (-not (Test-Path $exrcheckPath)) {
    Write-ColorOutput "Error: No se pudo encontrar exrcheck en $exrcheckPath" "Red"
    Write-ColorOutput "Por favor, asegúrese de que exrcheck.exe está en la carpeta OpenEXR." "Red"
    exit
}

# Verificar que se proporcionó un argumento (ruta de la carpeta)
if ($args.Count -eq 0) {
    Write-ColorOutput "Error: No se proporcionó ninguna carpeta como argumento." "Red"
    exit
}

$folderPath = $args[0]

# Verificar que la carpeta existe
if (-not (Test-Path $folderPath -PathType Container)) {
    Write-ColorOutput "Error: La carpeta especificada no existe: $folderPath" "Red"
    exit
}

# Preguntar si se quiere verificar solo las carpetas de input
$checkOnlyInput = Read-Host "¿Desea verificar solo archivos EXR en carpetas que contengan 'input'? (y/n)"
$checkOnlyInput = $checkOnlyInput.ToLower() -eq 'y'

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
            Write-ColorOutput "Carpeta saltada (no contiene 'input'):" "Cyan" $folderPath -newLine
            # Continuar procesando subcarpetas, ya que algunas subcarpetas podrían contener "input"
            Get-ChildItem -Path $folderPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $subFolderResults = Process-Folder -folderPath $_.FullName
                $corruptFiles += $subFolderResults.CorruptFiles
                $processedFiles += $subFolderResults.ProcessedFiles
            }
            return @{
                CorruptFiles = $corruptFiles
                ProcessedFiles = $processedFiles
            }
        }
    }

    if ($exrFiles.Count -eq 0) {
        Write-ColorOutput "Carpeta sin archivos EXR:" "Cyan" $folderPath -newLine
    }
    else {
        foreach ($file in $exrFiles) {
            Write-Host "Verificando: " -NoNewline
            try {
                $exrcheckOutput = & $exrcheckPath $file.FullName 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-ColorOutput "" "Red" $file.FullName "Archivo corrupto o con problemas" -newLine
                    Write-ColorOutput "  Detalles: $exrcheckOutput" "Red" -newLine
                    $corruptFiles += $file.FullName
                }
                else {
                    Write-ColorOutput "" "Green" $file.FullName "Archivo válido" -newLine
                }
                $processedFiles++
            }
            catch {
                Write-ColorOutput "" "Red" $file.FullName "Error al procesar el archivo" -newLine
                Write-ColorOutput "  $($_.Exception.Message)" "Red" -newLine
                $corruptFiles += $file.FullName
                $processedFiles++
            }
        }
    }

    # Procesar subcarpetas
    Get-ChildItem -Path $folderPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $subFolderResults = Process-Folder -folderPath $_.FullName
        $corruptFiles += $subFolderResults.CorruptFiles
        $processedFiles += $subFolderResults.ProcessedFiles
    }

    return @{
        CorruptFiles = $corruptFiles
        ProcessedFiles = $processedFiles
    }
}

Write-Host "Verificando archivos EXR en $folderPath y sus subcarpetas"
Write-Host ""

$results = Process-Folder -folderPath $folderPath

Write-Host ""

if ($results.ProcessedFiles -eq 0) {
    Write-ColorOutput "No se encontraron archivos EXR para procesar." "Yellow"
}
elseif ($results.CorruptFiles.Count -eq 0) {
    Write-ColorOutput "Todos los archivos EXR están intactos." "Green"
}
else {
    Write-ColorOutput "Se encontraron $($results.CorruptFiles.Count) archivos corruptos o con problemas:" "Red"
    foreach ($corruptFile in $results.CorruptFiles) {
        Write-ColorOutput "  $corruptFile" "Red"
    }
}

Write-Host ""
Write-Host "Verificación completada. Total de archivos procesados: $($results.ProcessedFiles)"

# Generar reporte en un archivo de texto
$reportPath = Join-Path $folderPath "EXR_Checker_Report.txt"
$reportContent = @"
Reporte de verificación de archivos EXR
Fecha: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Carpeta escaneada: $folderPath
Verificando solo carpetas de input: $($checkOnlyInput)

Total de archivos EXR procesados: $($results.ProcessedFiles)
Archivos corruptos o con problemas: $($results.CorruptFiles.Count)

Lista de archivos corruptos o con problemas:
"@

if ($results.CorruptFiles.Count -eq 0) {
    $reportContent += "`nNo se encontraron archivos corruptos o con problemas."
}
else {
    foreach ($corruptFile in $results.CorruptFiles) {
        $reportContent += "`n$corruptFile"
    }
}

$reportContent | Out-File -FilePath $reportPath -Encoding UTF8

Write-ColorOutput "Se ha generado un reporte detallado en:" "Cyan" $reportPath -newLine
