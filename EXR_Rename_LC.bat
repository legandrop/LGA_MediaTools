@echo off

REM ______________________________________________________________________________________________________________
REM
REM   Renombra archivos EXR aplicando la convención LC (Lega Conversion) y duplica la carpeta con la nueva estructura.
REM   Convierte "comp" a "cmp" (insensible a mayúsculas/minúsculas) pero mantiene otros sufijos como "Matte01" tal cual.
REM   Este script Batch actúa como un lanzador para un script de PowerShell más complejo.
REM
REM   Uso:
REM       1. Arrastra una carpeta con archivos EXR sobre este archivo .bat.
REM       2. El script de PowerShell asociado procesará la carpeta y archivos aplicando la conversión LC.
REM       3. Se creará una nueva carpeta con el nombre transformado y los archivos EXR renombrados.
REM
REM   Ejemplo de transformación:
REM       LC_1010_010_Beauty_Senora_comp_v04 -> LC_101_WAN_010_010_cmp_v04
REM       LC_1010_010_Beauty_Senora_Matte01_v04 -> LC_101_WAN_010_010_Matte01_v04
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
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/EXR_Rename_LC.ps1" "%~1"
