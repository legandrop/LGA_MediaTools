@echo off

REM ______________________________________________________________________________________________________________
REM
REM   Convierte archivos EXR de cualquier compresión a compresión ZIP.
REM   Utiliza un script de PowerShell que a su vez llama a la herramienta oiiotool para realizar la conversión.
REM   Uso:
REM       Arrastra una carpeta con archivos EXR sobre este archivo .bat.
REM       Este archivo .bat ejecutará un script de PowerShell que se encargará de realizar la conversión.
REM       Los archivos convertidos se guardarán en una nueva carpeta con la compresión ZIP aplicada.
REM       Si la carpeta o archivos originales contienen en su nombre "dwaa", se cambiará el nombre por "zip".
REM       Si no contienen "dwaa", se agregará "zip" al final del nombre de la carpeta (no de los archivos).
REM
REM   Lega - 2025 - v1.0
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
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/EXR_to_ZIP.ps1" "%~1"

