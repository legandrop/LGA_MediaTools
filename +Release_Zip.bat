@echo off
rem Change directory to the desired folder
cd /d "C:\Portable\LGA_MediaTools"

rem Check if the .zip file exists and delete it if it does
if exist LGA_MediaTools.zip (
    del LGA_MediaTools.zip
)

rem Create the zip file with exclusions from the specified folder
"C:\Program Files\7-Zip\7z.exe" a -tzip LGA_MediaTools.zip * -xr@.exclude.lst

rem Pause the script to see any error messages
pause
