# readraster Stata Toolkit

## Overview

`readraster` is a Stata command bundle that integrates the Java GeoTools and NetCDF libraries so researchers can work directly with raster data inside Stata. The accompanying [manuscript](https://github.com/kerrydu/readraster/blob/develop/manuscript.pdf) describes the motivation, command syntax, and application cases in detail.

## Installation

```stata
net install readraster, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/develop/)
net get readraster, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/develop/)
```

## Java Environment and Dependencies

All Java runtime and library setup steps are documented in [java_environment_config.md](https://github.com/kerrydu/readraster/blob/develop/java_environment_config.md). Review that guide for:

- JDK requirements for Stata 17 versus Stata 18+
- Initialisation of the GeoTools 34.0 and NetCDF-Java 5.9.1 libraries
- Verification and troubleshooting tips after installation

## Command Overview

The toolkit exposes seven commands that follow the workflow described in the manuscript:

- **Metadata inspection**
  - `gtiffdisp` reports GeoTIFF bands, spatial extent, resolution, and CRS details
  - `ncdisp` lists NetCDF variables, dimensions, coordinates, and attributes
- **Raster import**
  - `gtiffread` reads GeoTIFF pixels, supports subsetting, and can transform coordinates on the fly
  - `ncread` imports NetCDF variables to Stata (or CSV) with optional dimension slicing
- **Spatial operations**
  - `zonalstats` computes statistics such as average, sum, min, max, count, and standard deviation for polygons intersecting a GeoTIFF or NetCDF raster
  - `crsconvert` converts x/y coordinate pairs between CRSs specified by EPSG codes or reference files
  - `matchgeop` finds nearest neighbours between point datasets using great-circle distance (kilometres or miles)

## Workflow Snapshot

Section 3 of the manuscript explains how the commands work together:

1. Inspect raw files with `gtiffdisp` and `ncdisp` to understand structure and coordinate systems.
2. Bring raster values into Stata with `gtiffread` or `ncread`, subsetting large rasters by index windows when necessary.
3. Harmonise CRSs using `crsconvert`, then derive exposure metrics via `zonalstats` (polygons) or `matchgeop` (points).

## Example Highlights

The examples chapter showcases the workflow using Chinese nighttime light data (`DMSP-like2020.tif`) and NEX-GDDP-CMIP6 climate projections:

- Preview metadata
  ```stata
  gtiffdisp DMSP-like2020.tif
  ncdisp using "https://.../tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"
  ```
- Extract a buffered Hunan extent
  ```stata
  shp2dta using "hunan.shp", database(hunan_db) coordinates(hunan_coord)
  use hunan_coord.dta, clear
  crsconvert _X _Y, gen(alber) from(hunan.shp) to(DMSP-like2020.tif)

  * Determine row/column bounds (buffered by 2 km)
  gtiffread DMSP-like2020.tif, origin(1 1) size(-1 1) clear
  * ...compute start_row/start_col/n_rows/n_cols...

  gtiffread DMSP-like2020.tif, origin(`start_row' `start_col') size(`n_rows' `n_cols') clear
  save DMSP-like2020.dta, replace
  ```
- Compute prefecture-level averages
  ```stata
  zonalstats DMSP-like2020.tif using hunan.shp, stats("avg") clear
  save hunan_light.dta, replace
  ```
- Derive 80 km IDW exposure at city centroids
  ```stata
  matchgeop ORIG_FID lat lon using light_china.dta, neighbors(n wsg84_y wsg84_x) within(80) gen(distance)
  bysort city: egen idw_light = total(value / distance) / total(1 / distance)
  ```

These vignettes emphasise consistent CRS handling, raster subsetting without interpolation, and both polygon-based and point-based exposure estimation.

## Practical Notes and Limitations

- The dependency JAR files are large; manual download (see `java_environment_config.md`) can save time versus fetching within Stata.
- Advanced GeoTools operations such as buffering, raster clipping, or resampling are not yet exposed.
- Outputs are textual tables; use Stata graphics or external GIS tools for visualisation.

## Acknowledgment

Kerui Du gratefully acknowledges support from the National Natural Science Foundation of China (Grant nos. 72473119 and 72074184).

## Contact

- Kerui Du, School of Management, Xiamen University — kerrydu@xmu.edu.cn
- Chunxia Chen, School of Management, Xiamen University — chenchunxia@stu.xmu.edu.cn
- Shuo Hu, School of Economics, Southwestern University of Finance and Economics — advancehs@163.com
- Yang Song, School of Economics, Hefei University of Technology — ss0706082021@163.com
- Ruipeng Tang (corresponding author), School of Economics, Hefei University of Technology — tanruipeng@hfut.edu.cn


