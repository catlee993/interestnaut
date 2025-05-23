@echo off
REM flutter_windows.bat - Helper script to run Flutter commands on Windows

REM Add Flutter to PATH for this session
SET PATH=%PATH%;C:\src\flutter\bin

REM Set the Flutter app directory
SET FLUTTER_APP_DIR=%~dp0..\internal\ui\flutter

REM If no arguments, show usage
IF "%~1"=="" (
    echo Flutter Windows Helper
    echo.
    echo Usage:
    echo   flutter_windows.bat [command]
    echo.
    echo Examples:
    echo   flutter_windows.bat run        - Run the Flutter app on Windows
    echo   flutter_windows.bat bundle     - Bundle FFI and run the Flutter app
    echo   flutter_windows.bat doctor     - Run Flutter doctor
    echo   flutter_windows.bat build      - Build the Flutter app for Windows
    echo.
    exit /b
)

REM Check for "bundle" command
IF "%1"=="bundle" (
    echo Running bundle_ffi.ps1...
    powershell -ExecutionPolicy Bypass -File "%~dp0bundle_ffi.ps1"
    
    REM Run flutter if a second argument is provided
    IF NOT "%~2"=="" (
        echo Changing to Flutter app directory: %FLUTTER_APP_DIR%
        cd /d "%FLUTTER_APP_DIR%"
        echo Running: flutter %2 %3 %4 %5 %6 %7 %8 %9
        flutter %2 %3 %4 %5 %6 %7 %8 %9
    ) ELSE (
        REM Default to "run -d windows" if no second argument
        echo Changing to Flutter app directory: %FLUTTER_APP_DIR%
        cd /d "%FLUTTER_APP_DIR%"
        echo Running: flutter run -d windows
        flutter run -d windows
    )
    exit /b
)

REM For all other commands, pass directly to Flutter
echo Changing to Flutter app directory: %FLUTTER_APP_DIR%
cd /d "%FLUTTER_APP_DIR%"
echo Running: flutter %*
flutter %*
