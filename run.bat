@echo off
setlocal
cd /d "%~dp0"

set "GODOT=D:\GODOT GAME\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"

if not exist "%GODOT%" (
    echo Godot not found at:
    echo   %GODOT%
    echo Edit the GODOT line at the top of this file.
    pause
    exit /b 1
)

echo Rebuilding art...
python tools\rebuild.py --all
if errorlevel 1 (
    echo.
    echo Art rebuild failed - not launching. Fix the error above.
    pause
    exit /b 1
)

set "SCENE=res://scenes/title.tscn"
if /i "%~1"=="world" set "SCENE=res://scenes/world.tscn"
if /i "%~1"=="shore" set "SCENE=res://scenes/test_shore.tscn"
if /i "%~1"=="ground" set "SCENE=res://scenes/test_ground.tscn"
if /i "%~1"=="editor" goto :editor

echo.
echo Launching %SCENE%
"%GODOT%" --path cat-game --resolution 540x960 "%SCENE%"
goto :eof

:editor
echo.
echo Opening the Godot editor
"%GODOT%" -e --path cat-game
