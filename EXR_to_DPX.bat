@echo off

REM ______________________________________________________________________________________________________________
REM
REM   EXR_to_DPX | Lega | v1.00
REM
REM   Convierte archivos EXR a DPX 16bit.
REM   Utiliza un script de PowerShell que a su vez llama a la herramienta oiiotool para realizar la conversión.
REM   Uso:
REM       Arrastra una carpeta con archivos EXR sobre este archivo .bat.
REM       Este archivo .bat ejecutará un script de PowerShell que se encargará de realizar la conversión.
REM       Los archivos convertidos se guardarán en una nueva carpeta con el sufijo _dpx.
REM
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
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/EXR_to_DPX.ps1" "%~1"

