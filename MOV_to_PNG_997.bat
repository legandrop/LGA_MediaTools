@echo off

REM ______________________________________________________________________________________________________________
REM
REM   MOV_to_PNG_997 | Lega | v1.20
REM
REM   Convierte un archivo .MOV a una secuencia de archivos PNG comenzando desde el frame 0997.
REM   Funcionalidades principales:
REM     - Acepta archivos .MOV arrastrados al .bat.
REM     - Crea una subcarpeta con el nombre del archivo MOV (sin extensión).
REM     - Si la carpeta ya existe y contiene archivos, agrega un número al final.
REM     - Genera una secuencia PNG numerada comenzando desde 0997 (4 dígitos).
REM     - Preserva la calidad de video original en formato PNG.
REM   Uso:
REM     Arrastra un archivo .MOV sobre este archivo .bat.
REM     Los archivos PNG se guardan en una subcarpeta con el nombre del MOV.
REM
REM   Requisitos:
REM     - FFmpeg debe estar instalado y configurado.
REM
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
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/MOV_to_PNG_997.ps1" "%~1"

REM pause 