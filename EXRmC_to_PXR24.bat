@echo off
REM __________________________________________________________________________________________________________________________
REM
REM   Convierte archivos EXR multicanal a archivos EXR individuales por canal, con compresión Pxr24.
REM   Utiliza la herramienta oiiotool para realizar la conversión y exrheader para leer los canales.
REM
REM   Corrige los nombres de los canales eliminando "FinalImageMovieRenderQueue_" 
REM   y reemplazando ActorHitProxyMask por CryptoMatte.
REM
REM   Uso:
REM       Arrastra la carpeta de origen con los archivos EXR sobre este archivo .bat.
REM       Este archivo llamará al script PowerShell para procesar la conversión.
REM       La salida se guarda en nuevas subcarpetas con los archivos divididos por canal y con la compresión Pxr24 aplicada.
REM
REM   Lega - 2024
REM __________________________________________________________________________________________________________________________



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
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/EXRmC_to_PXR24.ps1" "%~1"


