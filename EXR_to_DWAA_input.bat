@echo off

REM ______________________________________________________________________________________________________________
REM
REM   Convierte archivos EXR de cualquier compresión a compresión DWAA y organiza la salida en la estructura del proyecto VFX.
REM   Este script Batch actúa como un lanzador para un script de PowerShell más complejo.
REM
REM   Uso:
REM       1. Arrastra una carpeta con archivos EXR sobre este archivo .bat.
REM       2. El script de PowerShell asociado solicitará al usuario el 'Nombre del plate'.
REM       3. A partir del nombre del plate, se calculará automáticamente el 'ProjectName' y el 'ShotName'.
REM       4. Se buscará la carpeta del shot correspondiente en la ruta 'T:\\VFX-[ProjectName]', buscando un nivel de profundidad.
REM       5. Los archivos EXR convertidos se guardarán en la siguiente ubicación:
REM          [Carpeta_del_Shot_Encontrada]\_input\[Nombre_del_Plate]
REM       6. Los archivos de salida serán renombrados a '[Nombre_del_Plate]_[Número_de_Frame_4_dígitos].exr'.
REM
REM   Lega - v1.0
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
powershell -ExecutionPolicy Bypass -File "%scriptDir%/LGA_Tools/EXR_to_DWAA_input.ps1" "%~1"

