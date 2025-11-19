@echo off
setlocal ENABLEDELAYEDEXPANSION

REM Build ReadRasterAll.java using local jars in C:\Users\kerry\Desktop\geotools
set SRC=c:\readraster\java\src\main\java\ReadRasterAll.java
set OUTDIR=c:\readraster\java\target\classes
set JAROUT=c:\readraster\java\target\readraster-all-local.jar
set JARDIR=C:\Users\kerry\Desktop\geotools
set JDK=C:\Stata18\utilities\java\windows-x64\zulu-jdk17.0.14
set JAVAC="%JDK%\bin\javac.exe"
set JAR="%JDK%\bin\jar.exe"

if not exist "%JARDIR%" (
  echo ERROR: Dependencies directory not found: %JARDIR%
  exit /b 2
)

if not exist %JAVAC% (
  echo ERROR: JDK not found at %JDK%
  exit /b 3
)

mkdir "c:\readraster\java\target" >nul 2>&1
if exist "%OUTDIR%" (
  rmdir /s /q "%OUTDIR%"
)
mkdir "%OUTDIR%" >nul 2>&1
if exist "%JAROUT%" (
  del /f /q "%JAROUT%"
)

set CP=%JARDIR%\*

echo Using JDK: %JDK%
%JAVAC% -version

echo Compiling ReadRasterAll.java ...
%JAVAC% -encoding UTF-8 -cp "%CP%" -d "%OUTDIR%" "%SRC%"
if errorlevel 1 (
  echo ERROR: Compilation failed
  exit /b 4
)

echo Creating jar ...
%JAR% --create --file "%JAROUT%" -C "%OUTDIR%" .
if errorlevel 1 (
  echo ERROR: Jar creation failed
  exit /b 5
)

echo SUCCESS: Built %JAROUT%
exit /b 0
