# Method 1: Using Precompiled JARs

[← Back to Main Configuration Guide](javaenvconfig.md)

## Overview

This method uses precompiled JAR files for a simpler setup process. Stata can automatically download and configure all necessary dependencies.

**Requirements:**
- Java JDK 17 or JDK 21
- Precompiled JARs (automatically downloaded)

**Best for:**
- Users with reliable internet access from Stata
- Users who prefer automated setup
- Quick and easy installation

---

## Step-by-Step Setup

### 1. Java JDK Configuration

#### For Stata 17 Users

Stata 17 is bundled with JDK 11, so you need to manually install and configure JDK 17 or JDK 21.

##### Step 1.1: Download and Install Java JDK 17 or JDK 21

Download and install Java JDK 17 or JDK 21 from one of the following sources:

- **Oracle JDK**: [https://www.oracle.com/java/technologies/downloads/](https://www.oracle.com/java/technologies/downloads/)
- **OpenJDK**: [https://openjdk.org/](https://openjdk.org/)

Select the JDK installation package for your operating system.

![JDK 17 Download](https://github.com/tricia1353/picture/blob/main/jdk17-download.png)

##### Step 1.2: Configure Java in Stata

After installing the Java JDK, configure the Java home directory in Stata:

```stata
. java set home "path_to_java_home_dir"
```

Replace `path_to_java_home_dir` with the actual path to your Java JDK installation directory. Examples:

- **Windows**: `"C:\Program Files\Java\jdk-17"`
- **Linux**: `"/usr/lib/jvm/java-17-openjdk-amd64"`

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

See detailed JDK 17 configuration instructions here: [JDK 17 Configuration Guide](method2_jshell_source.md#JDK17)

#### For Stata 18 Users

Stata 18 includes a compatible Java runtime environment. **No additional Java JDK installation or configuration is required.** You can proceed directly to downloading the precompiled JARs.

#### For Stata 19 Users

Stata 19 includes a compatible Java runtime environment. **No additional Java JDK installation is required for Method 1.** You can proceed directly to downloading the precompiled JARs.

---

### 2. Download Precompiled JARs

The precompiled JARs include all necessary GeoTools and NetCDF libraries packaged for easy use.

#### For GeoTools Commands

To use GeoTIFF-related commands (`gtiffdisp`, `gtiffread`, `gtiffwrite`, `gzonalstats`, `crsconvert`), run:

```stata
. geotools_init, compiled
```

This command will:
- Automatically download the precompiled GeoTools JAR from GitHub
- Configure the Java classpath
- Set up all necessary dependencies

**Note:** 
- This requires internet access from within Stata
- The download may take a few minutes depending on your connection speed
- This configuration only needs to be done once

#### For NetCDF Commands

To use NetCDF-related commands (`ncdisp`, `ncread`), run:

```stata
. netcdf_init, compiled
```

This command will:
- Automatically download the precompiled NetCDF JAR from GitHub
- Configure the Java classpath
- Set up all necessary dependencies

**Note:** This configuration only needs to be done once.

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

## Limitations for Chinese Users

**Important:** For users in China, GitHub resources might not be directly accessible from within Stata due to network restrictions.

If you encounter connection issues when running `geotools_init, compiled` or `netcdf_init, compiled`, please use **[Method 2: JShell with Java Source Code](method2_jshell_source.md)** instead, which allows manual download and configuration of libraries.

---

## Troubleshooting

### Common Issues

1. **Download failures**: 
   - Check your internet connection
   - Verify that Stata can access GitHub (test in a web browser)
   - If GitHub is blocked, use [Method 2](method2_jshell_source.md)

2. **Java not found error** (Stata 17 only):
   - Ensure Java JDK 17 or JDK 21 is properly installed
   - Verify configuration using `java query`
   - Re-run `java set home "path_to_java_home_dir"`

3. **Classpath errors**:
   - Try re-running the initialization commands
   - Restart Stata and try again
   - If issues persist, try [Method 2](method2_jshell_source.md)

### Version Compatibility

- **Java JDK 17 or JDK 21** is required for Stata 17
- **Stata 18 and 19** have built-in Java support (no manual JDK installation needed)
- Precompiled JARs are compatible with all supported Stata versions (17, 18, 19)

---

## Summary

Method 1 provides the fastest and easiest setup:
- ✅ Automated download and configuration
- ✅ No manual library management
- ✅ One-command setup for each library
- ✅ Suitable for Stata 17, 18, and 19
- ⚠️ Requires internet access from Stata
- ⚠️ May not work for users in China or with restricted networks

**Need manual control or can't access GitHub?** → [Method 2: Using JShell with Java Source Code](method2_jshell_source.md)

[← Back to Main Configuration Guide](javaenvconfig.md)