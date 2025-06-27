@echo off

REM ______________________________________________________________________________________________________________
REM
REM   Convierte secuencias EXR en ACES 2065-1 a archivos MOV en Rec.709 usando ProRes LT.
REM   Utiliza un script de PowerShell que a su vez llama a FFmpeg y OpenColorIO para realizar la conversión.
REM   Uso:
REM       Arrastra una carpeta con secuencia EXR sobre este archivo .bat.
REM       Este archivo .bat ejecutará un script de PowerShell que se encargará de realizar la conversión.
REM       El archivo MOV se guardará en el directorio padre de la carpeta arrastrada.
REM
REM   Lega - 2024 - v1.0
REM ______________________________________________________________________________________________________________


chcp 65001 >nul
setlocal

REM Verificar si se pasó un argumento (carpeta arrastrada)
if "%~1"=="" (
    echo Por favor, arrastre una carpeta con secuencia EXR al archivo .bat.
    pause
    exit /b
)

REM Obtener la ruta completa donde está ubicado el archivo .bat
set scriptDir=%~dp0

REM Ejecutar el script de PowerShell pasando la ruta de la carpeta
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/EXR_to_MOV_LT.ps1" "%~1" 