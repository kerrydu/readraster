# ReadRasterAll Consolidated Java

This folder contains a single consolidated Java class `ReadRasterAll` that merges the Java code previously embedded in the Stata ADO files:

- `gzonalstats_core.ado` (zonal statistics on GeoTIFF) -> `zonalstatics(...)`
- `nzonalstats_core.ado` (zonal statistics on NetCDF) -> `nzonalstatics(...)`
- `gtiffread_core.ado` (pixel export) -> `geotiffExport(...)`
- `gtiffdisp_core.ado` (metadata) -> `gtiffInfo(...)`

## 1. Prerequisites

- Java JDK 8+ (GeoTools 34.0 works with 8+, recommend 11 or 17).
- Apache Maven 3.8+.
- A local Stata installation providing the SFI Java API JAR (e.g. `sfi-api.jar`). Set an environment variable `STATA_SFI_JAR` pointing to that JAR.

On Windows (PowerShell):

```powershell
$env:STATA_SFI_JAR = "C:\Program Files\Stata18\utilities\java\sfi-api.jar"
```

Adjust the path to match your Stata install.

## 2. Build (Fat / Shaded JAR)

From the `java` directory:

```powershell
cd c:\readraster\java
mvn -q clean package
```

Resulting jar: `target\readraster-all-1.0.0-all.jar` (contains GeoTools, NetCDF, JTS, etc. — excludes the Stata SFI which Stata loads itself).

## 3. Using From Stata

Copy the fat jar somewhere accessible (e.g. `c:\readraster\lib\readraster-all-1.0.0-all.jar`). In each ADO where you previously had multiple `/cp` lines, replace them with a single classpath add for the fat jar:

```stata
java:
/cp "c:/readraster/lib/readraster-all-1.0.0-all.jar"
end
```

Then update calls:

- GeoTIFF zonal stats (original):
  ```stata
  java: zonalstatics.main("shp.shp", "raster.tif", 0, "avg sum", "")
  ```
  New:
  ```stata
  java: ReadRasterAll.zonalstatics("shp.shp", "raster.tif", 0, "avg sum", "")
  ```

- NetCDF zonal stats:
  ```stata
  java: ReadRasterAll.nzonalstatics("zones.shp", "data.nc", "temperature", "avg min max", "", "", "EPSG:4326")
  ```

- GeoTIFF pixel export (band 1, full extent):
  ```stata
  java: ReadRasterAll.geotiffExport("raster.tif", 1, "None", 0, -1, 0, -1)
  ```

- GeoTIFF metadata:
  ```stata
  java: ReadRasterAll.gtiffInfo("raster.tif")
  ```

### Using with `javacall`

This project provides `static int mymethod(String[] args)` (and an alias `static int method1(String[] args)`) compatible with Stata's `javacall`.

Recommended syntax (pass arguments via `args()` and the fat jar via `jars()`):

- GeoTIFF zonal stats:
  ```stata
  javacall ReadRasterAll method1, jars("c:/readraster/lib/readraster-all-1.0.0-all.jar") ///
      args("zonalstatics zones.shp raster.tif 0 \"avg sum\" \"\"")
  ```

- NetCDF zonal stats:
  ```stata
  javacall ReadRasterAll method1, jars("c:/readraster/lib/readraster-all-1.0.0-all.jar") ///
      args("nzonalstatics zones.shp data.nc temperature avg \"\" \"\" EPSG:4326")
  ```

- GeoTIFF pixel export:
  ```stata
  javacall ReadRasterAll method1, jars("c:/readraster/lib/readraster-all-1.0.0-all.jar") ///
      args("geotiffExport raster.tif 1 None 0 -1 0 -1")
  ```

- GeoTIFF metadata:
  ```stata
  javacall ReadRasterAll method1, jars("c:/readraster/lib/readraster-all-1.0.0-all.jar") ///
      args("gtiffInfo raster.tif")
  ```

## 4. Origin/Size Notes (NetCDF)
Pass `originParam` and `sizeParam` exactly as the existing code expected (space or comma separated indices). They are zero-based internally.

## 5. Updating Dependencies
To change versions, edit `pom.xml` property values (e.g. `<geotools.version>`). Re-run `mvn clean package`.

## 6. Troubleshooting
- If Maven cannot find `netcdfAll`, ensure you have Internet access; it's fetched from Maven Central.
- If Stata cannot find SFI classes: verify `STATA_SFI_JAR` env variable and that the jar path is correct. (The build excludes SFI on purpose.)
- CRS errors: supply explicit EPSG code as `EPSG:4326` or a projection WKT.
- Memory / file locks: The code disposes readers and calls `System.gc()` similar to original logic; if locks persist, ensure no other process is holding the file.

## 7. License Considerations
You are repackaging GeoTools + NetCDF + Apache components. Check original license files (see original `geotools-34.0/licenses`). Keep them if distributing.

## 8. Next Steps / Possible Enhancements
- Add unit tests (e.g. JUnit) for each public method.
- Add CRS override for GeoTIFF when missing.
- Optionally minimize shaded jar with `minimizeJar=true` once stable.

---
Built JAR unifies previous scattered `/cp` lines into a single dependency for easier maintenance.
