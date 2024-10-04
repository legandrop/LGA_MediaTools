@echo off
REM Definir las rutas necesarias
set "ffmpegPath=C:\Portable\LGA_MediaTools\FFmpeg\ffmpeg.exe"
set "inputSequencePath=T:\VFX-EE\104\EE-104_019_3970_Gomeria_Escapan\Comp\4_publish\EE-104_019_3970_Gomeria_Escapan_comp_v53r\EE-104_019_3970_Gomeria_Escapan_comp_v53r_%%04d.exr"
set "outputMovFile=T:\VFX-EE\104\EE-104_019_3970_Gomeria_Escapan\Comp\4_publish\EE-104_019_3970_Gomeria_Escapan_comp_v53r-LT.MOV"
set "framerate=24"  REM Aquí puedes cambiar el framerate manualmente
set "startNumber=1001"  REM Aquí puedes cambiar el frame de inicio

REM Mostrar las rutas utilizadas para depuración
echo --- Debug: Verificando rutas ---
echo FFmpeg Path: "%ffmpegPath%"
echo Input Sequence Path: "%inputSequencePath%"
echo Output MOV File: "%outputMovFile%"
echo Framerate: %framerate%
echo Start Number: %startNumber%
echo ---------------------------------

REM Verificar si ffmpeg.exe existe
if not exist "%ffmpegPath%" (
    echo Error: No se encuentra ffmpeg.exe en %ffmpegPath%
    pause
    exit /b
)

REM Convertir la secuencia EXR a MOV con ProRes LT usando ffmpeg
echo --- Debug: Ejecutando FFmpeg para la conversión ---
echo Comando FFmpeg: "%ffmpegPath%" -y -start_number %startNumber% -framerate %framerate% -i "%inputSequencePath%" -c:v prores_ks -profile:v 1 -vendor apl0 -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" -pix_fmt yuv422p10le -r %framerate% "%outputMovFile%"
"%ffmpegPath%" -y -start_number %startNumber% -framerate %framerate% -i "%inputSequencePath%" -c:v prores_ks -profile:v 1 -vendor apl0 -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" -pix_fmt yuv422p10le -r %framerate% "%outputMovFile%"

REM Verificar si el archivo MOV se creó correctamente
echo --- Debug: Verificando si el archivo MOV fue creado ---
if exist "%outputMovFile%" (
    echo Conversion completada: "%outputMovFile%"
) else (
    echo Error: No se pudo crear el archivo MOV.
)

pause
