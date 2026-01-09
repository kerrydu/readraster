# Java Environment and Dependency Configuration

## Overview

The `readraster` package requires Java runtime environment and specific Java libraries to handle geospatial raster data processing. This guide provides comprehensive instructions for configuring the Java environment and dependencies.

**We offer two distinct methods to use the package:**

---

## 🎯 Quick Decision Guide

### Choose Your Method:

| **Method** | **Best For** | **Requirements** | **Difficulty** |
|------------|-------------|------------------|----------------|
| **[Method 1: Precompiled JARs](method1_precompiled_jars.md)** | Users with reliable GitHub access from Stata | JDK 17/21 (Stata 17 only) | ⭐ Easy |
| **[Method 2: JShell with Source Code](method2_jshell_source.md)** | Chinese users or those with limited GitHub access | JDK 17 + Manual library setup | ⭐⭐ Moderate |

---

## 📋 Method Comparison

### Method 1: Using Precompiled JARs
- ✅ **Automated setup** - one command download and configuration
- ✅ **Faster installation** - no manual library management
- ✅ **Simpler workflow** - fewer steps required
- ⚠️ **Requires GitHub access** from within Stata
- ⚠️ **Not recommended for Chinese users** due to potential network restrictions

**Quick Start Commands:**
```stata
. geotools_init, compiled
. netcdf_init, compiled
```

👉 **[Go to Method 1 Documentation →](method1_precompiled_jars.md)**

---

### Method 2: Using JShell with Java Source Code
- ✅ **Works without direct GitHub access** from Stata
- ✅ **Recommended for Chinese users**
- ✅ **Manual control** over library versions and locations
- ⚠️ **Requires manual download** of libraries
- ⚠️ **More setup steps** required

**Quick Start Commands:**
```stata
. geotools_init, download plus(geotools)
. netcdf_init, download plus(netcdf)
```

👉 **[Go to Method 2 Documentation →](method2_jshell_source.md)**

---

## 🖥️ Stata Version Requirements

| **Stata Version** | **Method 1** | **Method 2** | **Notes** |
|-------------------|--------------|--------------|-----------|
| **Stata 17** | Manual JDK 17/21 setup required | Manual JDK 17 setup required | Bundled with JDK 11 (insufficient) |
| **Stata 18** | No JDK setup needed ✅ | No JDK setup needed ✅ | Built-in Java runtime |
| **Stata 19** | No JDK setup needed ✅ | Manual JDK 17 setup required | Built-in runtime (Method 1 only) |

---

## 📚 What's Required?

### GeoTools Library (Version 34.0)
Required for GeoTIFF operations:
- `gtiffdisp` - Display GeoTIFF file information
- `gtiffread` - Read GeoTIFF raster data
- `gtiffwrite` - Write GeoTIFF files
- `gzonalstats` - Calculate zonal statistics
- `crsconvert` - Coordinate reference system conversion

### NetCDF Library (Version 5.9.1)
Required for NetCDF operations:
- `ncdisp` - Display NetCDF file information
- `ncread` - Read NetCDF data

---

## 🚀 Getting Started

1. **Choose your method** based on your location and network access
2. **Click the appropriate link** above to access detailed instructions
3. **Follow the step-by-step guide** for your chosen method
4. **Verify configuration** by running test commands

---

## 🔧 Need Help?

- **Stata 17 users**: Both methods require [JDK 17 configuration](method2_jshell_source.md#JDK17)
- **Chinese users**: We strongly recommend [Method 2](method2_jshell_source.md)
- **Quick setup**: Choose [Method 1](method1_precompiled_jars.md) if you have GitHub access
- **Manual control**: Choose [Method 2](method2_jshell_source.md) for custom library management

---

## 📖 Detailed Documentation

- **[Method 1: Using Precompiled JARs →](method1_precompiled_jars.md)**
- **[Method 2: Using JShell with Java Source Code →](method2_jshell_source.md)**

---

## Summary

Proper Java environment configuration is essential for the `readraster` package functionality. Choose the method that best fits your network environment and Stata version, then follow the detailed instructions in the corresponding documentation page.