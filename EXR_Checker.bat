 @echo off


REM ______________________________________________________________________________________________________________
REM
REM   Verifica la integridad de archivos EXR en una carpeta arrastrada y sus subcarpetas.
REM   Funcionalidades principales:
REM     - Recibe una carpeta arrastrada como argumento.
REM     - Llama a un script de PowerShell para procesar los archivos EXR.
REM     - El script de PowerShell usa exrcheck para verificar la integridad de cada archivo EXR.
REM     - Genera un reporte RTF de archivos corruptos, si los hay.
REM
REM   Uso:
REM     Arrastra una carpeta que contenga archivos EXR sobre este archivo .bat.
REM
REM   Requisitos:
REM     - exrcheck debe estar en la carpeta OpenEXR relativa a la ubicación del script.
REM
REM   Lega - 2024 - v1.3
REM ______________________________________________________________________________________________________________


setlocal

REM Verificar si se pasó un argumento (carpeta arrastrada)
if "%~1"=="" (
    echo Por favor, arrastre una carpeta con archivos EXR al archivo .bat.
    pause
    exit /b
)

REM Obtener la ruta completa donde está ubicado el archivo .bat
set scriptDir=%~dp0

REM Ejecutar el script de PowerShell pasando la ruta de la carpeta
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/EXR_Checker.ps1" "%~1"

pause
