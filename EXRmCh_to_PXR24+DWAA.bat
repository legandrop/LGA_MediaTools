@echo off
REM __________________________________________________________________________________________________________________________
REM
REM   EXRmC_to_PXR24+DWAA | Lega | v1.30
REM
REM   Convierte archivos EXR multicanal a archivos EXR individuales por canal.
REM   Utiliza la herramienta oiiotool para realizar la conversión y exrheader para leer los canales.
REM
REM   Corrige los nombres de los canales eliminando "FinalImageMovieRenderQueue_" 
REM   y reemplazando ActorHitProxyMask por CryptoMatte.
REM
REM   El canal RGBA se convierte a DWAA, mientras que los demás canales se convierten a Pxr24.
REM
REM   Uso:
REM       Arrastra la carpeta de origen con los archivos EXR sobre este archivo .bat.
REM       Este archivo llamará al script PowerShell para procesar la conversión.
REM       La salida se guarda en nuevas subcarpetas con los archivos divididos por canal y con la compresión correspondiente aplicada.
REM
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
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/EXRmC_to_PXR24+DWAA.ps1" "%~1"


