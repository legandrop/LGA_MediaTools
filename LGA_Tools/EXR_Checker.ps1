# ______________________________________________________________________________________________________________
#
#   Verifica la integridad de archivos EXR en una carpeta y sus subcarpetas.
#   Funcionalidades principales:
#     - Recibe la ruta de una carpeta como argumento.
#     - Escanea recursivamente todas las subcarpetas.
#     - Utiliza exrcheck para verificar la integridad de cada archivo EXR encontrado.
#     - Genera un reporte de archivos corruptos con sus rutas completas.
#   Uso:
#     Este script es llamado por EXR_Checker.bat al arrastrar una carpeta sobre él.
#   Requisitos:
#     - exrcheck debe estar en la carpeta OpenEXR relativa a la ubicación del script.
#   Lega - 2024
# ______________________________________________________________________________________________________________

# Configurar la codificación de salida a UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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

# Obtener todos los archivos EXR en la carpeta y subcarpetas
$exrFiles = Get-ChildItem -Path $folderPath -Filter "*.exr" -Recurse

if ($exrFiles.Count -eq 0) {
    Write-ColorOutput "No se encontraron archivos EXR en la carpeta especificada ni en sus subcarpetas." "Yellow"
    exit
}

Write-Host "Verificando $($exrFiles.Count) archivos EXR en $folderPath y sus subcarpetas"
Write-Host ""

$corruptFiles = @()

foreach ($file in $exrFiles) {
    Write-Host "Verificando: $($file.FullName)"
    try {
        $exrcheckOutput = & $exrcheckPath $file.FullName 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "  Archivo corrupto o con problemas: $($file.FullName)" "Red"
            Write-ColorOutput "  Detalles: $exrcheckOutput" "Red"
            $corruptFiles += $file.FullName
        }
        else {
            Write-ColorOutput "  Archivo válido" "Green"
        }
    }
    catch {
        Write-ColorOutput "  Error al procesar el archivo: $($file.FullName)" "Red"
        Write-ColorOutput "  $($_.Exception.Message)" "Red"
        $corruptFiles += $file.FullName
    }
}

Write-Host ""

if ($corruptFiles.Count -eq 0) {
    Write-ColorOutput "Todos los archivos EXR están intactos." "Green"
}
else {
    Write-ColorOutput "Se encontraron $($corruptFiles.Count) archivos corruptos o con problemas:" "Red"
    foreach ($corruptFile in $corruptFiles) {
        Write-ColorOutput "  $corruptFile" "Red"
    }
}

Write-Host ""
Write-Host "Verificación completada."

# Generar reporte en un archivo de texto
$reportPath = Join-Path $folderPath "EXR_Checker_Report.txt"
$reportContent = @"
Reporte de verificación de archivos EXR
Fecha: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Carpeta escaneada: $folderPath

Total de archivos EXR encontrados: $($exrFiles.Count)
Archivos corruptos o con problemas: $($corruptFiles.Count)

Lista de archivos corruptos o con problemas:
"@

if ($corruptFiles.Count -eq 0) {
    $reportContent += "`nNo se encontraron archivos corruptos o con problemas."
}
else {
    foreach ($corruptFile in $corruptFiles) {
        $reportContent += "`n$corruptFile"
    }
}

$reportContent | Out-File -FilePath $reportPath -Encoding UTF8

Write-ColorOutput "Se ha generado un reporte detallado en: $reportPath" "Cyan"
