@echo off
setlocal ENABLEDELAYEDEXPANSION

REM Build a single fat (shaded) jar that includes all dependencies (except Stata SFI)
set JDK=C:\Stata18\utilities\java\windows-x64\zulu-jdk17.0.14
set JAVAC="%JDK%\bin\javac.exe"
set JAR="%JDK%\bin\jar.exe"

set SRC=c:\readraster\java\src\main\java\ReadRasterAll.java
set CLASSES_OUT=c:\readraster\java\target\classes
set THIN_JAR=c:\readraster\java\target\readraster-all-local.jar
set FAT_JAR=c:\readraster\java\target\readraster-all-fat.jar
set STAGING=c:\readraster\java\target\staging
set JARDIR=C:\Users\kerry\Desktop\geotools

if not exist "%JARDIR%" (
  echo ERROR: Dependencies directory not found: %JARDIR%
  exit /b 2
)
if not exist %JAVAC% (
  echo ERROR: JDK not found at %JDK%
  exit /b 3
)

REM 1) Compile classes and thin jar first
call c:\readraster\java\build-cmd.bat
if errorlevel 1 (
  echo ERROR: Thin build failed; cannot proceed to fat jar.
  exit /b 4
)

REM 2) Prepare staging directory
echo STAGE: prepare staging
if exist "%STAGING%" rmdir /s /q "%STAGING%"
mkdir "%STAGING%"

REM 3) Copy our compiled classes into staging
echo STAGE: copy classes
xcopy /E /I /Y "%CLASSES_OUT%\*" "%STAGING%\" >nul

REM 4) Unpack dependency jars (excluding any SFI/Stata jars)
echo STAGE: merge dependencies from %JARDIR%
echo DBG: extracting dependency jars via PowerShell + jar.exe
powershell -NoProfile -Command "Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'; Set-Location -LiteralPath '%STAGING%'; $jdk='%JDK%'; Get-ChildItem -LiteralPath '%JARDIR%' -Filter '*.jar' | Where-Object { $_.Name -notmatch 'sfi|stata' } | ForEach-Object { & "$jdk\bin\jar.exe" xf $_.FullName }"

REM 4b) Ensure GeoTools SPI registration for EPSG HSQL is present (all required AuthorityFactory services)
echo STAGE: ensure META-INF/services contains EPSG HSQL provider (all authority factory services)
set "SVC_DIR=%STAGING%\META-INF\services"
if not exist "%SVC_DIR%" mkdir "%SVC_DIR%"
set "PROV=org.geotools.referencing.factory.epsg.hsql.ThreadedHsqlEpsgFactory"

call :ensure_spi "org.geotools.api.referencing.AuthorityFactory"
call :ensure_spi "org.geotools.api.referencing.crs.CRSAuthorityFactory"
call :ensure_spi "org.geotools.api.referencing.cs.CSAuthorityFactory"
call :ensure_spi "org.geotools.api.referencing.datum.DatumAuthorityFactory"
call :ensure_spi "org.geotools.api.referencing.operation.CoordinateOperationAuthorityFactory"
call :ensure_spi "org.opengis.referencing.AuthorityFactory"
call :ensure_spi "org.opengis.referencing.crs.CRSAuthorityFactory"
call :ensure_spi "org.opengis.referencing.cs.CSAuthorityFactory"
call :ensure_spi "org.opengis.referencing.datum.DatumAuthorityFactory"
call :ensure_spi "org.opengis.referencing.operation.CoordinateOperationAuthorityFactory"

echo DBG: sample service file contents (CRSAuthorityFactory):
type "%SVC_DIR%\org.geotools.api.referencing.crs.CRSAuthorityFactory"

echo DBG: count files in staging
for /f %%C in ('dir /a-d /s /b "%STAGING%" ^| find /c /v ""') do set STAGE_COUNT=%%C
echo STAGING FILE COUNT: %STAGE_COUNT%

REM 4c) Merge JAI registry files from all dependencies into one
echo STAGE: merge JAI registry files (META-INF/registryFile.jai)
set "REG_DIR=%STAGING%\META-INF"
set "REG_FILE=%REG_DIR%\registryFile.jai"
if not exist "%REG_DIR%" mkdir "%REG_DIR%"
if exist "%REG_FILE%" del /f /q "%REG_FILE%"
setlocal ENABLEDELAYEDEXPANSION
set IDX=0
for %%J in ("%JARDIR%\*.jar") do (
  "%JAR%" tf "%%~fJ" | findstr /i "META-INF/registryFile.jai" >nul 2>&1
  if not errorlevel 1 (
    set /a IDX+=1
    set TMPDIR=%STAGING%\_regtmp_!IDX!
    if exist "!TMPDIR!" rmdir /s /q "!TMPDIR!"
    mkdir "!TMPDIR!"
    pushd "!TMPDIR!"
    "%JAR%" xf "%%~fJ" META-INF/registryFile.jai
    if exist "!TMPDIR!\META-INF\registryFile.jai" (
      echo.>> "%REG_FILE%"
      type "!TMPDIR!\META-INF\registryFile.jai" >> "%REG_FILE%"
    )
    popd
    rmdir /s /q "!TMPDIR!" >nul 2>&1
  )
)
endlocal
if exist "%REG_FILE%" (
  echo DBG: merged registry file size:
  for %%A in ("%REG_FILE%") do echo     %%~zA bytes
)

REM 4d) Merge GeoTools Function SPI so functions like Length are available
echo STAGE: merge Function SPI (META-INF/services/org.geotools.api.filter.expression.Function)
set "SVC_DIR=%STAGING%\META-INF\services"
if not exist "%SVC_DIR%" mkdir "%SVC_DIR%"
set "FUNC_SVC=%SVC_DIR%\org.geotools.api.filter.expression.Function"
if exist "%FUNC_SVC%" del /f /q "%FUNC_SVC%"
setlocal ENABLEDELAYEDEXPANSION
set IDX=0
for %%J in ("%JARDIR%\gt-*.jar") do (
  "%JAR%" tf "%%~fJ" | findstr /i "META-INF/services/org.geotools.api.filter.expression.Function" >nul 2>&1
  if not errorlevel 1 (
    set /a IDX+=1
    set TMPDIR=%STAGING%\_funcspi_!IDX!
    if exist "!TMPDIR!" rmdir /s /q "!TMPDIR!"
    mkdir "!TMPDIR!"
    pushd "!TMPDIR!"
    "%JAR%" xf "%%~fJ" META-INF/services/org.geotools.api.filter.expression.Function
    if exist "!TMPDIR!\META-INF\services\org.geotools.api.filter.expression.Function" (
      echo.>> "%FUNC_SVC%"
      type "!TMPDIR!\META-INF\services\org.geotools.api.filter.expression.Function" >> "%FUNC_SVC%"
    )
    popd
    rmdir /s /q "!TMPDIR!" >nul 2>&1
  )
)
endlocal

REM 4e) Merge GeoTools FunctionFactory SPI (used by FunctionFinder)
echo STAGE: merge FunctionFactory SPI (META-INF/services/org.geotools.filter.FunctionFactory)
set "SVC_DIR=%STAGING%\META-INF\services"
if not exist "%SVC_DIR%" mkdir "%SVC_DIR%"
set "FF_SVC=%SVC_DIR%\org.geotools.filter.FunctionFactory"
if exist "%FF_SVC%" del /f /q "%FF_SVC%"
setlocal ENABLEDELAYEDEXPANSION
set IDX=0
for %%J in ("%JARDIR%\gt-*.jar") do (
  "%JAR%" tf "%%~fJ" | findstr /i "META-INF/services/org.geotools.filter.FunctionFactory" >nul 2>&1
  if not errorlevel 1 (
    set /a IDX+=1
    set TMPDIR=%STAGING%\_funcfac_!IDX!
    if exist "!TMPDIR!" rmdir /s /q "!TMPDIR!"
    mkdir "!TMPDIR!"
    pushd "!TMPDIR!"
    "%JAR%" xf "%%~fJ" META-INF/services/org.geotools.filter.FunctionFactory
    if exist "!TMPDIR!\META-INF\services\org.geotools.filter.FunctionFactory" (
      echo.>> "%FF_SVC%"
      type "!TMPDIR!\META-INF\services\org.geotools.filter.FunctionFactory" >> "%FF_SVC%"
    )
    popd
    rmdir /s /q "!TMPDIR!" >nul 2>&1
  )
)
endlocal

REM 4f) Merge legacy FunctionExpression SPI (defensive, for older loaders)
echo STAGE: merge FunctionExpression SPI (META-INF/services/org.geotools.filter.FunctionExpression)
set "FE_SVC=%SVC_DIR%\org.geotools.filter.FunctionExpression"
if exist "%FE_SVC%" del /f /q "%FE_SVC%"
setlocal ENABLEDELAYEDEXPANSION
set IDX=0
for %%J in ("%JARDIR%\gt-*.jar") do (
  "%JAR%" tf "%%~fJ" | findstr /i "META-INF/services/org.geotools.filter.FunctionExpression" >nul 2>&1
  if not errorlevel 1 (
    set /a IDX+=1
    set TMPDIR=%STAGING%\_funcexpr_!IDX!
    if exist "!TMPDIR!" rmdir /s /q "!TMPDIR!"
    mkdir "!TMPDIR!"
    pushd "!TMPDIR!"
    "%JAR%" xf "%%~fJ" META-INF/services/org.geotools.filter.FunctionExpression
    if exist "!TMPDIR!\META-INF\services\org.geotools.filter.FunctionExpression" (
      echo.>> "%FE_SVC%"
      type "!TMPDIR!\META-INF\services\org.geotools.filter.FunctionExpression" >> "%FE_SVC%"
    )
    popd
    rmdir /s /q "!TMPDIR!" >nul 2>&1
  )
)
endlocal

REM 4g) Merge Coverage Processing Operation SPI
echo STAGE: merge Coverage Operation SPI (META-INF/services/org.geotools.api.coverage.processing.Operation)
set "SVC_DIR=%STAGING%\META-INF\services"
if not exist "%SVC_DIR%" mkdir "%SVC_DIR%"
set "OP_SVC=%SVC_DIR%\org.geotools.api.coverage.processing.Operation"
if exist "%OP_SVC%" del /f /q "%OP_SVC%"
setlocal ENABLEDELAYEDEXPANSION
set IDX=0
for %%J in ("%JARDIR%\gt-*.jar") do (
  "%JAR%" tf "%%~fJ" | findstr /i "META-INF/services/org.geotools.api.coverage.processing.Operation" >nul 2>&1
  if not errorlevel 1 (
    set /a IDX+=1
    set TMPDIR=%STAGING%\_covops_!IDX!
    if exist "!TMPDIR!" rmdir /s /q "!TMPDIR!"
    mkdir "!TMPDIR!"
    pushd "!TMPDIR!"
    "%JAR%" xf "%%~fJ" META-INF/services/org.geotools.api.coverage.processing.Operation
    if exist "!TMPDIR!\META-INF\services\org.geotools.api.coverage.processing.Operation" (
      echo.>> "%OP_SVC%"
      type "!TMPDIR!\META-INF\services\org.geotools.api.coverage.processing.Operation" >> "%OP_SVC%"
    )
    popd
    rmdir /s /q "!TMPDIR!" >nul 2>&1
  )
)
endlocal

REM 5) Remove signature files that can break merged jars
if exist "%STAGING%\META-INF" (
  del /f /q "%STAGING%\META-INF\*.SF" >nul 2>&1
  del /f /q "%STAGING%\META-INF\*.RSA" >nul 2>&1
  del /f /q "%STAGING%\META-INF\*.DSA" >nul 2>&1
  del /f /q "%STAGING%\META-INF\MANIFEST.MF" >nul 2>&1
)

REM 6) Create fat jar
echo STAGE: create fat jar
if exist "%FAT_JAR%" del /f /q "%FAT_JAR%"
"%JAR%" --create --file "%FAT_JAR%" -C "%STAGING%" .
if errorlevel 1 (
  echo ERROR: Fat jar creation failed
  exit /b 5
)

REM 7) Report success
for %%A in ("%FAT_JAR%") do set SIZE=%%~zA
echo SUCCESS: Built %FAT_JAR% (size: %SIZE% bytes)

echo STAGE: verify key classes present in fat jar
"%JAR%" tf "%FAT_JAR%" | findstr /i "org/readraster/ReadRasterAll.class" >nul && echo + Found ReadRasterAll.class || echo - Missing ReadRasterAll.class
"%JAR%" tf "%FAT_JAR%" | findstr /i "org/geotools/referencing/factory/epsg" >nul && echo + Found GeoTools EPSG classes || echo - Missing GeoTools EPSG classes
"%JAR%" tf "%FAT_JAR%" | findstr /i "org/hsqldb" >nul && echo + Found HSQLDB classes || echo - Missing HSQLDB classes
REM Verify key EPSG SPI descriptors (GeoTools API + OGC)
"%JAR%" tf "%FAT_JAR%" | findstr /i "META-INF/services/org.geotools.api.referencing.AuthorityFactory" >nul && echo + Found GT AuthorityFactory SPI || echo - Missing GT AuthorityFactory SPI
"%JAR%" tf "%FAT_JAR%" | findstr /i "META-INF/services/org.geotools.api.referencing.crs.CRSAuthorityFactory" >nul && echo + Found GT CRSAuthorityFactory SPI || echo - Missing GT CRSAuthorityFactory SPI
"%JAR%" tf "%FAT_JAR%" | findstr /i "META-INF/services/org.opengis.referencing.crs.CRSAuthorityFactory" >nul && echo + Found OGC CRSAuthorityFactory SPI || echo - Missing OGC CRSAuthorityFactory SPI
"%JAR%" tf "%FAT_JAR%" | findstr /i "META-INF/registryFile.jai" >nul && echo + Found merged JAI registry || echo - Missing JAI registry
exit /b 0

:mergeJar
set "JARFILE=%~1"
set "JARNAME=%~2"
echo %JARNAME% | findstr /i "sfi stata" >nul
if errorlevel 1 (
  echo + Merging: %JARNAME%
  "%JAR%" xf "%JARFILE%"
) else (
  echo - Skipping (provided by Stata): %JARNAME%
)
goto :eof

:ensure_spi
set "_SVC_NAME=%~1"
set "_SVC_FILE=%SVC_DIR%\%_SVC_NAME%"
if not exist "%_SVC_FILE%" type nul > "%_SVC_FILE%"
findstr /i "%PROV%" "%_SVC_FILE%" >nul 2>&1
if errorlevel 1 (
  echo %PROV%>>"%_SVC_FILE%"
)
goto :eof
