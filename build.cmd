@echo off
setlocal enabledelayedexpansion
set NL=^


REM
cd %~dp0
cd Display
echo Parsing file ...
findstr /V "Remove before squishing" Display.lua > Display_build.lua
echo Squishing ...
lua51 squish --minify-level=full --uglify --uglify-level=full
echo Cleaning up...
del /F /Q out.lua
del /F /Q Display_build.lua
del /F /Q Display_sq.lua >nul 2>&1
ren out.lua.uglified Display_sq.lua
move /y Display_sq.lua "E:\Program Files (x86)\Steam\steamapps\common\assettocorsa\content\cars\bm_porsche_991_gt3r_2020_display\extension\Display" >nul 2>&1
REM cd "E:\Program Files (x86)\Steam\steamapps\common\assettocorsa\content\cars\bm_porsche_991_gt3r_2020_display\extension"
REM Force Update the script

REM ren ext_config.ini ext_config.tmp
REM sed '$d' ext_config.tmp > ext_config.ini
REM del /F /Q ext_config.tmp
REM echo !NL!^" >> ext_config.ini