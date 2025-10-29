# Java Environment and Dependency Configuration

## Overview

The `readraster` package requires Java runtime environment and specific Java libraries to handle geospatial raster data processing. This section provides comprehensive guidance for configuring the Java environment and required dependencies across different Stata versions.

## Java JDK Configuration

### Stata Version Requirements

- **Stata 17**: Requires manual installation and configuration of Java JDK 17 
- **Stata 18**: Includes built-in Java runtime environment (no additional configuration needed)
- **Stata 19**: Includes built-in Java runtime environment (no additional configuration needed)

### For Stata 17 

#### Step 1: Download and Install Java JDK 17

Download and install Java JDK 17 from one of the following sources:

- Oracle JDK: [https://www.oracle.com/java/technologies/downloads/](https://www.oracle.com/java/technologies/downloads/)
- OpenJDK: [https://openjdk.org/](https://openjdk.org/)

Select the JDK installation package for the corresponding operating system.

![](https://github.com/tricia1353/picture/blob/main/jdk17-download.png)

#### Step 2: Configure Java in Stata

After installing the Java JDK, configure the Java home directory in Stata by executing:

```stata
. java set home "path_to_java_home_dir"
```

Replace `path_to_java_home_dir` with the actual path to your Java JDK installation directory. Examples:

- Windows: `"C:\Program Files\Java\jdk-17"`
- Linux: `"/usr/lib/jvm/java-17-openjdk-amd64"`

![](https://github.com/tricia1353/picture/blob/main/set_home.png)

#### Step 3: Verify Configuration

Verify the Java configuration by running:

```stata
. java query
```
![](https://github.com/tricia1353/picture/blob/main/java%20query.png)


Note: the default JDK version can be restored by running:

```stata
. java set home default
```


### For Stata 18/Stata 19 Users

Stata 18 and later versions include a compatible Java runtime environment. No additional Java JDK installation or configuration is required.

## GeoTools Library Setup

The GeoTools library (Version 34.0) is required for GeoTIFF file operations including `gtiffdisp`, `gtiffread`, `gtiffwrite`, `gzonalstats`, and `crsconvert` commands.

### Automated Setup (Recommended)

For simplified setup, use the dedicated initialization command:

```stata
. geotools_init, download plus(geotools)
```

**Note**: This process may take several minutes as Stata downloads files from the internet.

### Manual Setup (Faster Alternative)

1. Manually download GeoTools 34.0 from:  
   [https://master.dl.sourceforge.net/project/geotools/GeoTools%2034%20Releases/34.0/geotools-34.0-bin.zip](https://master.dl.sourceforge.net/project/geotools/GeoTools%2034%20Releases/34.0/geotools-34.0-bin.zip)

   <img width="2492" height="1350" alt="image" src="https://github.com/tricia1353/picture/blob/main/geotools34_download.png" />


3. Unzip the downloaded file

4. Initialize the environment by running:

```stata
. geotools_init path_to_geotools-34.0/lib, plus(geotools)
```

Replace `path_to_geotools-34.0/lib` with the actual file path to your unzipped GeoTools 34.0 lib folder.

For example, in my Win11 PC, the path is as follows.

![](https://github.com/tricia1353/picture/blob/main/geotools34_path.png)

Then, path_to_geotools-34.0/lib is "C:\Users\kerry\Desktop\Download\geotools-34.0\lib".

```stata
. geotools_init  "C:\Users\kerry\Desktop\Download\geotools-34.0\lib", plus(geotools)
```



## NetCDF Library Setup

The NetCDF library (Version 5.9.1) is required for NetCDF file operations including `ncdisp` and `ncread` commands.
url: [https://downloads.unidata.ucar.edu/netcdf-java/5.9.1/netcdfAll-5.9.1.jar](https://downloads.unidata.ucar.edu/netcdf-java/5.9.1/netcdfAll-5.9.1.jar)
<img width="2390" height="1336" alt="image" src="https://github.com/user-attachments/assets/ab3a6011-0658-4a0c-a4ad-600acba42586" />


### Automated Setup

Use the dedicated initialization command:

```stata
. netcdf_init, download plus(netcdf)
```

**Note**: This configuration is only required the first time you use the package.

## Configuration Verification

After completing the setup process, you can verify that all dependencies are properly configured by running basic commands:

```stata
// Test GeoTools setup
. gtiffdisp filename.tif

// Test NetCDF setup
. ncdisp using "filename.nc"
```

## Troubleshooting

### Common Issues

1. **Java not found error**: Ensure Java JDK is properly installed and configured using `java set home`
2. **Library loading errors**: Verify that the correct library versions are downloaded and paths are correctly specified
3. **Permission issues**: Ensure Stata has read/write access to the directories containing the Java libraries

### Version Compatibility

- Java JDK 17 is required for Stata 17 
- GeoTools 34.0 is the supported version for all geospatial operations
- NetCDF-Java 5.9.1 is the supported version for NetCDF operations

## Summary

Proper Java environment configuration is essential for the `readraster` package functionality. Stata 18/Stata 19 users benefit from built-in Java support, while Stata 17 users need manual JDK installation. The automated setup commands (`geotools_init` and `netcdf_init`) simplify the dependency management process, though manual download may be preferable for faster setup in some environments.
