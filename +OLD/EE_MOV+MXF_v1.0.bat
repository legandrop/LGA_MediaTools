@echo off

REM ______________________________________________________________________________________________________________
REM
REM   Procesa archivos .MOV añadiendo barras negras y texto de frame.
REM   Uso:
REM       Arrastra un archivo .MOV sobre este archivo .bat.
REM       Este archivo .bat ejecutará un script de PowerShell que se encargará de realizar el procesamiento.
REM
REM   Lega - 2024
REM ______________________________________________________________________________________________________________

chcp 65001 >nul
setlocal

REM Verificar si se pasó un argumento (archivo arrastrado)
if "%~1"=="" (
    echo Por favor, arrastre un archivo .MOV al archivo .bat.
    pause
    exit /b
)

REM Obtener la ruta completa donde está ubicado el archivo .bat
set scriptDir=%~dp0

REM Ejecutar el script de PowerShell pasando la ruta del archivo MOV
powershell -ExecutionPolicy Bypass -File "%scriptDir%/Tools/EE_MOV+MXF.ps1" "%~1"


REM pause