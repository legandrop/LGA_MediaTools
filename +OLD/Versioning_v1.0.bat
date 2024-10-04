REM 

@echo off
setlocal ENABLEDELAYEDEXPANSION

REM __________________________________________________________________________
REM
REM   Versioning.bat v1.0 - 2024 - Lega Pugliese
REM   Script para versionar archivos .py antes de realizar cambios.
REM   Copia el archivo a la carpeta +OLD y asigna un nuevo número de versión.
REM __________________________________________________________________________


REM Obtener la ruta completa del archivo arrastrado
set "file=%~1"

REM Obtener el directorio del archivo
set "dir=%~dp1"

REM Obtener el nombre del archivo sin extensión
set "filename=%~n1"

REM Obtener la extensión del archivo
set "ext=%~x1"

REM Establecer la ruta al directorio +OLD
set "olddir=%dir%+OLD"

REM Verificar si el directorio +OLD existe, si no, crearlo
if not exist "%olddir%" (
    mkdir "%olddir%"
)

REM Copiar el archivo al directorio +OLD
copy "%file%" "%olddir%" >nul

REM Cambiar al directorio +OLD
pushd "%olddir%"

REM Inicializar el número de versión máximo
set "maxver=0"

REM Buscar archivos que coincidan con el patrón filename_v*.ext
for %%F in ("%filename%_v*%ext%") do (
    REM Extraer el número de versión del nombre del archivo
    set "verstr=%%~nF"
    set "verstr=!verstr:%filename%_v=!"
    REM Eliminar cualquier parte adicional después del número de versión
    for /f "tokens=1 delims=_" %%G in ("!verstr!") do (
        set "ver=%%G"
        REM Eliminar el punto para trabajar con enteros
        set "vernum=!ver:.=!"
        REM Verificar si vernum es mayor que maxver
        if !vernum! GTR !maxver! (
            set "maxver=!vernum!"
        )
    )
)

REM Calcular el nuevo número de versión
set /a newvernum=maxver+1

REM Convertir newvernum de nuevo a formato decimal
set /a newverint=newvernum / 10
set /a newverdec=newvernum %% 10
set "newver=%newverint%.%newverdec%"

REM Renombrar el archivo copiado con el nuevo número de versión
ren "%filename%%ext%" "%filename%_v%newver%%ext%"

REM Volver al directorio original
popd
endlocal
