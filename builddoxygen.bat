@echo off
setlocal

set "ROOT_DIR=%~dp0.."
for %%I in ("%ROOT_DIR%") do set "ROOT_DIR=%%~fI"
set "DOXYFILE=%ROOT_DIR%\docs\Doxyfile"

:: Enforce execution from repo root to keep Doxyfile INPUT paths correct
if /I not "%CD%"=="%ROOT_DIR%" (
  echo Error: builddoxygen.bat must be run from the repository root: %ROOT_DIR%
  exit /b 1
)

if not exist "%DOXYFILE%" (
  echo Doxyfile not found at: %DOXYFILE%
  exit /b 1
)

if not exist "docs\doxygen" mkdir "docs\doxygen"

doxygen "%DOXYFILE%"


endlocal
