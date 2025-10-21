# GeoTools 32 to 34 Upgrade Summary

## Overview
This document summarizes the changes made to upgrade the Java code from GeoTools 32 to GeoTools 34.

## Files Updated
1. `gtiffread_core.ado`
2. `gzonalstats_core.ado`
3. `gtiffdisp_core.ado`
4. `crsconvert_core.ado`
5. `nzonalstats_core.ado`
6. `netcdfutils.ado`

## Changes Made

### 1. JAR File Version Updates
Updated all GeoTools JAR files from version 32.0 to 34.0:
- `gt-metadata-32.0.jar` → `gt-metadata-34.0.jar`
- `gt-api-32.0.jar` → `gt-api-34.0.jar`
- `gt-main-32.0.jar` → `gt-main-34.0.jar`
- `gt-referencing-32.0.jar` → `gt-referencing-34.0.jar`
- `gt-epsg-hsql-32.0.jar` → `gt-epsg-hsql-34.0.jar`
- `gt-epsg-extension-32.0.jar` → `gt-epsg-extension-34.0.jar`
- `gt-geotiff-32.0.jar` → `gt-geotiff-34.0.jar`
- `gt-coverage-32.0.jar` → `gt-coverage-34.0.jar`
- `gt-process-raster-32.0.jar` → `gt-process-raster-34.0.jar`
- `gt-shapefile-32.0.jar` → `gt-shapefile-34.0.jar`

### 2. ImageIO Plugins for TIFF
GeoTools 34 works with standard ImageIO plus TwelveMonkeys plugins (no ImageN/JAI jars required on modern JREs):
- Add: `imageio-tiff-3.10.1.jar`, `imageio-core-3.10.1.jar`
- Add: `common-image-3.10.1.jar`, `common-io-3.10.1.jar`, `common-lang-3.10.1.jar`

### 3. NetCDF Library Update
Updated NetCDF library version to match GeoTools 34 requirements:
- ~~`netcdfAll-5.9.1.jar` → `netcdfAll-5.5.3.jar`~~

## Key Requirements for GeoTools 34

### Java Version Requirement
- **GeoTools 34 requires Java 17** (no longer supports Java 11)
- Ensure your development and runtime environment uses Java 17

### API Compatibility
- Most existing API methods remain compatible
- `CRS.reset()`, `CRS.decode()`, `CRS.findMathTransform()`, and `CRS.parseWKT()` methods are still available
- `NetcdfDatasets.openDataset()` method remains compatible

### Dependencies
- Eclipse ImageN 0.9.0 replaces JAI 1.1.3
- ~~NetCDF 5.5.3 is the recommended version for GeoTools 34~~
- All other dependencies (JTS, Commons libraries) remain the same

## Testing Recommendations

1. **Java Version Check**: Verify that Java 17 is being used
2. **Functionality Testing**: Test all GeoTIFF reading, zonal statistics, and CRS conversion functions
3. **Image Processing**: Verify that image operations work correctly with Eclipse ImageN
4. **NetCDF Operations**: Test NetCDF file reading and processing
5. **Memory Usage**: Monitor memory usage as GeoTools 34 may have different memory requirements

## Potential Issues to Watch For

1. **Java Version**: Ensure Java 17 is available in the environment
2. **Image Processing**: Some image operations may behave differently with Eclipse ImageN
3. **NetCDF Compatibility**: Some NetCDF files may require different handling with version 5.5.3
4. **Memory Requirements**: GeoTools 34 may have different memory usage patterns

## Next Steps

1. Update your Java runtime to version 17
2. Test all functionality with the upgraded libraries
3. Monitor for any runtime errors or compatibility issues
4. Update documentation if any API changes affect user-facing functionality

## References
- [GeoTools 34 Release Notes](https://www.osgeo.org/foundation-news/geotools-34-0-released/)
- [GeoTools Upgrade Guide](https://docs.geotools.org/stable/userguide/welcome/upgrade.html)
- [GeoTools 34 API Documentation](https://docs.geotools.org/latest/javadocs/index.html)
