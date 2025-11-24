@echo off

REM ______________________________________________________________________________________________________________
REM
REM   DPX_to_EXR_DWAA | Lega | v1.01
REM
REM   Convierte archivos DPX a EXR con compresión DWAA (calidad 60).
REM   Utiliza un script de PowerShell que a su vez llama a la herramienta oiiotool para realizar la conversión.
REM   Uso:
REM       Arrastra una carpeta con archivos DPX sobre este archivo .bat.
REM       Este archivo .bat ejecutará un script de PowerShell que se encargará de realizar la conversión.
REM       Los archivos convertidos se guardarán en una nueva carpeta con el sufijo _exr.
REM
REM   v1.01 - Reemplazar punto antes del número de frame por guión bajo
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
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/DPX_to_EXR_DWAA.ps1" "%~1"

