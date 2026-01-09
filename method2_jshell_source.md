# Method 2: Using JShell with Java Source Code

[← Back to Main Configuration Guide](javaenvconfig.md)

## Overview

This method uses JShell with Java source code instead of precompiled JARs. This approach requires manual library setup but is **recommended for Chinese users** who cannot access GitHub resources directly within Stata.

**Requirements:**
- Java JDK 17
- GeoTools 34.0 libraries
- NetCDF-Java 5.9.1 library

---

## Step-by-Step Setup

### 1. Java JDK 17 Configuration

#### For Stata 17 Users

<span id="JDK17"></span>

##### Step 1.1: Download and Install Java JDK 17

Download and install Java JDK 17 from one of the following sources:

- Oracle JDK: [https://www.oracle.com/java/technologies/downloads/](https://www.oracle.com/java/technologies/downloads/)
- OpenJDK: [https://openjdk.org/](https://openjdk.org/)

Select the JDK installation package for your operating system.

![JDK 17 Download](https://github.com/tricia1353/picture/blob/main/jdk17-download.png)

##### Step 1.2: Configure Java in Stata

After installing the Java JDK, configure the Java home directory in Stata:

```stata
. java set home "path_to_java_home_dir"
```

Replace `path_to_java_home_dir` with the actual path to your Java JDK installation directory. Examples:

- Windows: `"C:\Program Files\Java\jdk-17"`
- Linux: `"/usr/lib/jvm/java-17-openjdk-amd64"`

![Set Home](https://github.com/tricia1353/picture/blob/main/set_home.png)

##### Step 1.3: Verify Configuration

Verify the Java configuration by running:

```stata
. java query
```

![Java Query](https://github.com/tricia1353/picture/blob/main/java%20query.png)

**Note:** The default JDK version can be restored by running:

```stata
. java set home default
```

#### For Stata 18 Users

Stata 18 includes a compatible Java runtime environment. **No additional Java JDK installation or configuration is required.**

#### For Stata 19 Users

Stata 19 requires manual installation and configuration of Java JDK 17 for Method 2. Follow the same steps as Stata 17 users above.

---

### 2. GeoTools Library Setup

The GeoTools library (Version 34.0) is required for GeoTIFF file operations including `gtiffdisp`, `gtiffread`, `gtiffwrite`, `gzonalstats`, and `crsconvert` commands.

#### Option A: Automated Setup (Requires Internet Access)

For simplified setup, use the dedicated initialization command:

```stata
. geotools_init, download plus(geotools)
```

**Note:** This process may take several minutes as Stata downloads files from the internet.

#### Option B: Manual Setup (Recommended for Chinese Users)

1. **Manually download GeoTools 34.0** from:  
   [https://master.dl.sourceforge.net/project/geotools/GeoTools%2034%20Releases/34.0/geotools-34.0-bin.zip](https://master.dl.sourceforge.net/project/geotools/GeoTools%2034%20Releases/34.0/geotools-34.0-bin.zip)

   <img width="2492" height="1350" alt="GeoTools Download" src="https://github.com/tricia1353/picture/blob/main/geotools34_download.png" />

2. **Unzip the downloaded file** to a location on your computer

3. **Initialize the environment** by running:

   ```stata
   . geotools_init path_to_geotools-34.0/lib, plus(geotools)
   ```

   Replace `path_to_geotools-34.0/lib` with the actual file path to your unzipped GeoTools 34.0 lib folder.

   **Example:** If you extracted GeoTools to `C:\Users\kerry\Desktop\Download\geotools-34.0`:

   ![GeoTools Path](https://github.com/tricia1353/picture/blob/main/geotools34_path.png)

   Then run:

   ```stata
   . geotools_init "C:\Users\kerry\Desktop\Download\geotools-34.0\lib", plus(geotools)
   ```

---

### 3. NetCDF Library Setup

The NetCDF library (Version 5.9.1) is required for NetCDF file operations including `ncdisp` and `ncread` commands.

**Download URL:** [https://downloads.unidata.ucar.edu/netcdf-java/5.9.1/netcdfAll-5.9.1.jar](https://downloads.unidata.ucar.edu/netcdf-java/5.9.1/netcdfAll-5.9.1.jar)

<img width="2390" height="1336" alt="NetCDF Download" src="https://github.com/user-attachments/assets/ab3a6011-0658-4a0c-a4ad-600acba42586" />

#### Option A: Automated Setup

Use the dedicated initialization command:

```stata
. netcdf_init, download plus(netcdf)
```

#### Option B: Manual Setup

1. **Download netcdfAll-5.9.1.jar** from the URL above
2. **Place the JAR file** in a known directory
3. **Initialize with the path** to the JAR file:

   ```stata
   . netcdf_init "path_to_netcdfAll-5.9.1.jar", plus(netcdf)
   ```

**Note:** This configuration is only required the first time you use the package.

---

## Configuration Verification

After completing the setup process, verify that all dependencies are properly configured:

```stata
// Test GeoTools setup
. gtiffdisp filename.tif

// Test NetCDF setup
. ncdisp using "filename.nc"
```

---

## Troubleshooting

### Common Issues

1. **Java not found error**: Ensure Java JDK 17 is properly installed and configured using `java set home`
2. **Library loading errors**: Verify that the correct library versions are downloaded and paths are correctly specified
3. **Permission issues**: Ensure Stata has read/write access to the directories containing the Java libraries
4. **Path issues on Windows**: Use forward slashes `/` or double backslashes `\\` in file paths

### Version Compatibility

- **Java JDK 17** is required for Stata 17 and Stata 19
- **GeoTools 34.0** is the supported version for all geospatial operations
- **NetCDF-Java 5.9.1** is the supported version for NetCDF operations

---

## Summary

Method 2 provides more control over dependency management:
- ✅ Works without direct GitHub access from Stata
- ✅ Recommended for users in China
- ✅ Manual library management
- ✅ Suitable for Stata 17, 18, and 19
- ⚠️ Requires manual download and configuration

**Prefer automated setup?** → [Method 1: Using Precompiled JARs](method1_precompiled_jars.md)

[← Back to Main Configuration Guide](javaenvconfig.md)
