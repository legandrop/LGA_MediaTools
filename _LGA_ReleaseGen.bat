@echo off
setlocal enabledelayedexpansion

rem Cambiar directorio a la ubicación del script
cd /d "%~dp0"

rem Definir nombre base del ZIP
set "ZIPBASE=LGA_MediaTools"
set "VERSION_PATTERN=%ZIPBASE%_v*.zip"

rem Inicializar variables de versión
set "max_ver=0"
set "version_exists=false"

rem Buscar versión máxima existente
for %%F in (%VERSION_PATTERN%) do (
    set "version_exists=true"
    set "filename=%%~nF"
    set "ver_str=!filename:%ZIPBASE%_v=!"
    
    for /f "tokens=1 delims=_" %%G in ("!ver_str!") do (
        set "current_ver=%%G"
        set "int_ver=!current_ver:.=!"
        
        if !int_ver! GTR !max_ver! (
            set "max_ver=!int_ver!"
        )
    )
)

rem Calcular nueva versión
if "!version_exists!"=="false" (
    set "new_version=1.0"
) else (
    set /a new_ver_num=max_ver + 1
    set /a major=new_ver_num / 10
    set /a minor=new_ver_num %% 10
    set "new_version=!major!.!minor!"
)

rem Crear nombre del archivo final
set "FINAL_ZIP=%ZIPBASE%_v!new_version!.zip"

rem Eliminar ZIP anterior si existe
if exist "!FINAL_ZIP!" (
    del "!FINAL_ZIP!"
)

rem Empaquetar con 7-Zip
echo Creando paquete !FINAL_ZIP!...
"C:\Program Files\7-Zip\7z.exe" a -tzip "!FINAL_ZIP!" * -xr@.exclude.lst

rem Resultado final
echo.
echo ========================================
echo Paquete generado: !FINAL_ZIP!
echo ========================================
echo.

pause
endlocal
