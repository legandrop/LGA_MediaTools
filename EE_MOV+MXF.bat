@echo off

REM ______________________________________________________________________________________________________________
REM
REM   Procesa un archivo .MOV para crear versiones MOV y MXF con overlays y textos específicos.
REM   Funcionalidades principales:
REM     - Verifica la estructura del nombre del archivo de entrada.
REM     - Busca la carpeta FgPlate y el archivo EditRef más recientes.
REM     - Compara el número de frames entre el MOV de entrada, la secuencia FgPlate y el EditRef.
REM     - Crea un thumbnail a partir del primer frame de la secuencia FgPlate.
REM     - Genera una placa con el thumbnail y textos informativos.
REM     - Produce un archivo MOV con barras negras semitransparentes 2.35:1, placa inicial y textos.
REM     - Crea una versión MXF sin las barras 2.35:1.
REM     - Renombra los archivos de salida según reglas específicas.
REM   Uso:
REM     Arrastra un archivo .MOV sobre el archivo .bat, que luego llama a este script.
REM     Los archivos procesados se guardan en la misma carpeta con nuevos nombres según las reglas.
REM
REM   Requisitos:
REM     - FFmpeg, Oiio y OpenColorIO deben estar instalados y configurados.
REM     - Estructura de carpetas específica con _input, FgPlate, y EditRef.
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
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/EE_MOV+MXF.ps1" "%~1"


REM pause