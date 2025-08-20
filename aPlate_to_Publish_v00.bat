@echo off

REM ______________________________________________________________________________________________________________
REM
REM   Genera placeholders EXR negros para compositing basándose en el frame range de una secuencia existente.
REM   Este script Batch actúa como un lanzador para un script de PowerShell más complejo.
REM
REM   Uso:
REM       1. Arrastra una carpeta con secuencia EXR sobre este archivo .bat.
REM       2. La carpeta debe estar ubicada en: shotname/input/nombre_de_sequencia
REM       3. El script extraerá automáticamente:
REM          - El shotname desde la ruta de la carpeta
REM          - El frame range analizando los archivos EXR en la carpeta
REM       4. Se creará la estructura: shotname/Comp/4_publish/shotname_comp_v00
REM       5. Se generarán placeholders EXR negros para cada frame del range detectado
REM       6. Los archivos generados seguirán el formato: 'shotname_comp_v00_[frame].exr'.
REM
REM   Lega - v1.0
REM ______________________________________________________________________________________________________________


chcp 65001 >nul
setlocal

REM Verificar si se pasó un argumento (carpeta arrastrada)
if "%~1"=="" (
    echo Por favor, arrastre una carpeta al archivo .bat.
    pause
    exit /b
)

REM Obtener la ruta completa donde está ubicado el archivo .bat
set scriptDir=%~dp0

REM Ejecutar el script de PowerShell pasando la ruta de la carpeta
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/aPlate_to_Publish_v00.ps1" "%~1"

