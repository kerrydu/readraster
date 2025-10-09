# readraster Package Workflow / 工作流程指南

*Last updated: 2025-10-09*

---
## 1. Research Scenario Overview / 研究场景概述
Many empirical studies need to quantify environmental or geographic exposure (temperature, pollution, vegetation, night lights, elevation) for Areas of Interest (AOIs) such as administrative regions, grid cells, or site locations. Typical data sources:
- GeoTIFF raster (remote sensing, processed imagery)
- NetCDF multi-dimensional climate / environmental model outputs
- Shapefile polygons (administrative boundaries, ecological zones)
- Point locations (stations, firm addresses, monitoring sites)

The `readraster` toolkit standardizes a reproducible pipeline completely inside Stata.

---
## 2. High-level Workflow / 高层工作流
```
          GeoTIFF source (.tif)                  NetCDF source (.nc)
          ----------------------                --------------------
                  |                                      |
              gtiffdisp                               ncdisp
        (inspect metadata)                     (inspect metadata)
                  |                                      |
              gtiffread                                ncread
        (vectorize raster cells)             (extract / slice variables)
                  |                                      |
          +-------------------+                +-------------------+
          |                   |                |                   |
      gzonalstats        matchgeop + IDW   gzonalstats        matchgeop + IDW
 (zonal polygon stats)  (point exposure) (zonal polygon stats) (point exposure)
```

Decision: Choose `gzonalstats` if you have polygon zones and want aggregated cell statistics; choose `matchgeop` + inverse distance weighted average (IDW) if you instead have discrete locations (points) and want to attach surrounding raster-derived values as continuous exposure metrics.

---
## 3. Step 1: Inspect Metadata / 查看元数据
### 3.1 GeoTIFF: `gtiffdisp`
Purpose: Confirm spatial resolution, CRS, band count, NoData, extent.

Example:
```stata
gtiffdisp DMSP-like2020.tif
```
Questions answered:
- Projection suitable? Need CRS conversion? (`crsconvert` or rely on internal reprojection in later steps)
- Full extent or sub-window needed?
- Single band or choose with `band()` later?

### 3.2 NetCDF: `ncdisp`
Purpose: Understand dimensions (time, lat, lon, level), variable names, units, missing value code, CRS metadata.

Example:
```stata
local url "...tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"
ncdisp using `url'
// Focus on target variable
ncdisp tas using `url'
```
Questions answered:
- Dimension ordering? (time lat lon) or (lat lon time)?
- Need subsetting (temporal slice, spatial window)?
- Are latitude values descending (common in some climate data)?

---
## 4. Step 2: Extract / Vectorize Raster Data / 栅格读取
### 4.1 GeoTIFF: `gtiffread`
Turns raster cells into a rectangular grid dataset with at least: x, y, value (plus optional band-specific fields). Optionally subset by origin/size (if implemented) or filter after loading.

Typical usage:
```stata
gtiffread DMSP-like2020.tif, clear
```
After this you can filter to AOI bounding box to reduce memory:
```stata
keep if x>=`xmin' & x<=`xmax' & y>=`ymin' & y<=`ymax'
```

### 4.2 NetCDF: `ncread`
Extract a chosen variable (single time step or all) into long form (e.g., time, lat, lon, value). Subset via `origin()` + `size()` or by filtering indices.

```stata
ncread tas using `url', clear origin(1 `lat_start' `lon_start') size(-1 `lat_count' `lon_count')
```
Then you may compute daily / annual summaries or convert Kelvin to Celsius:
```stata
gen tas_c = tas - 273.15
collapse (mean) tas_c, by(lat lon)
```

---
## 5. Step 3A: Polygon Zonal Statistics with `gzonalstats` / 多边形区域统计
Use when you have AOI polygons (administrative boundaries, buffers, ecological zones). Two modes:
- Raster mode: Directly supply GeoTIFF and shapefile.
- Vector mode: Supply an in-memory grid (from `gtiffread` or aggregated `ncread`) with x,y,value variables and shapefile.

### 5.1 Raster Mode
```stata
gzonalstats DMSP-like2020.tif using hunan.shp, stats("avg sum") clear
```
Outputs one record per polygon with requested stats (avg, sum, min, max, std, count).

### 5.2 Vector Mode
If you already transformed / pre-processed raster cells into a grid inside Stata:
```stata
// Suppose dataset has lon lat nl_value
rename lon x
rename lat y
rename nl_value value

// Compute zonal mean + count
gzonalstats using hunan.shp, xvar(x) yvar(y) valuevar(value) frame(nl_stats) crs(EPSG:4326) stats("avg count")
```
Benefits:
- Reuse transformed / masked cell data
- Avoid re-reading large GeoTIFF multiple times

---
## 6. Step 3B: Point Exposure via `matchgeop` + Inverse Distance Weighting / 点位暴露估计
Use when you have discrete site locations (e.g., firm HQ, monitoring station) and need a localized exposure measure from surrounding raster cells instead of polygon aggregation.

### 6.1 `matchgeop`
Matches each point to nearest raster cell(s) or polygon attributes (depending on implementation). Ideal for categorical attributes or nearest-value assignment.

### 6.2 Inverse Distance Weighted (IDW) Average
If exposure should reflect a smooth surface rather than a single nearest cell, compute a weighted average of k nearby raster cells:
\( Exposure_i = \frac{\sum_{j \in N_i} w_{ij} v_j}{\sum_{j \in N_i} w_{ij}} \), where \( w_{ij} = d_{ij}^{-p} \) (commonly p=2 and distance in projected meters).

Workflow sketch:
```stata
// 1. Read / build raster grid
gtiffread DMSP-like2020.tif, clear
// 2. Keep subset around points (optional)
// 3. Prepare site points dataset in frame sites
frame create sites
frame sites: use firm_sites, clear
// 4. For each point, find k nearest cells (pseudo outline)
// (Actual implementation may rely on matchgeop or a custom Java helper)
```

Practical computation approach in Stata:
1. Compute distance between each point and candidate cells (use projected CRS).  
2. Keep k nearest per point (e.g., by sorting).  
3. Generate weight = distance^(-p); normalize; compute weighted value.

---
## 7. Choosing Between `gzonalstats` vs `matchgeop` + IDW / 选择策略
| Situation / 场景 | Prefer gzonalstats | Prefer matchgeop + IDW |
|------------------|--------------------|-------------------------|
| AOIs are polygons (admin, buffers) | ✅ Natural aggregation unit | ❌ Would ignore polygon boundaries |
| Need sums / totals (e.g., total emissions) | ✅ Correct additive stats | ⚠️ Point exposure is not additive |
| Need average over area | ✅ Area-consistent | ⚠️ Sensitive to search radius choice |
| Only have site points (no polygons) | ❌ Requires polygons | ✅ Directly usable |
| Want smooth localized exposure | ⚠️ Raster mean may be coarse | ✅ IDW yields localized smoothing |
| Computational cost (large polygons) | Efficient (polygon masking) | Potentially high if many points × neighbors |

### Conceptual Difference / 概念区别
- `gzonalstats`: Aggregates all raster cells fully inside each polygon (or intersecting) → area-based statistics (extensive or intensive depending on stat). Produces one row per polygon.
- `matchgeop` + IDW: Produces one exposure value per point by weighting nearby cell values; no area weighting of entire polygons; results reflect local neighborhood conditions.

### When They Approximate Each Other
If polygons are very small (approaching point-like) and IDW uses only the single nearest cell (p → ∞), both reduce to assigning the cell value—then results converge.

---
## 8. Best Practices / 最佳实践
**CRS Handling**
- Use projected CRS (meters) for distance-based IDW to avoid distortion (e.g., EPSG:3857, national equal-area, or UTM zone).
- Ensure shapefile CRS matches raster CRS or rely on internal reprojection in `gzonalstats`.

**Subsetting Early**
- Clip to AOI bounding box before heavy operations to reduce memory.
- For NetCDF, read only needed time slices (e.g., one year or monthly averages).

**Performance**
- Limit statistics list to essentials (e.g., only "avg" if mean suffices).
- Cache intermediate grid (vector mode) if repeating multiple polygon analyses.

**Quality Checks**
- Inspect resulting counts: unexpectedly low count may indicate CRS mismatch or misaligned grid.
- Plot sample points vs grid (export to GIS if necessary) to validate alignment.

**Reproducibility**
- Store raw file URLs / versions in a do-file header.
- Log CRS transformations and parameter choices (band, nodata, k neighbors, p exponent).

---
## 9. Example Integrated Pipeline / 综合示例
### 9.1 GeoTIFF → Zonal Mean Night Lights by City
```stata
// Inspect
gtiffdisp DMSP-like2020.tif
// Aggregate directly
gzonalstats DMSP-like2020.tif using cities.shp, stats("avg sum") clear
```

### 9.2 NetCDF → Annual Temperature by Province
```stata
local url "...tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"
// Discover dimensions
ncdisp tas using `url'
// Read subset (full year, limited lat/lon window)
ncread tas using `url', clear origin(1 `lat_start' `lon_start') size(-1 `lat_count' `lon_count')
// Convert to Celsius and annual average grid
replace tas = tas - 273.15
collapse (mean) tas, by(lat lon)
// Rename to x,y,value pattern if needed
rename (lon lat tas) (x y value)
// Zonal average by provinces
gzonalstats using provinces.shp, xvar(x) yvar(y) valuevar(value) frame(temp_stats) crs(EPSG:4326) stats("avg std")
```

### 9.3 Point Exposure (Firm Sites) from Night Lights Using IDW
```stata
// Build grid
gtiffread DMSP-like2020.tif, clear
// Project coordinates if needed
// Prepare sites
frame create sites
frame sites: use firm_sites, clear
// Suppose we computed distances and selected k nearest into temp dataset 'neighbors'
// Weighted average exposure
by site_id: gen w = dist^-2
by site_id: egen wsum = total(w)
by site_id: egen exposure = total(w*value)/wsum
```

---
## 10. English Summary (Brief)
1. Inspect raster metadata (gtiffdisp / ncdisp).
2. Extract raster data (gtiffread / ncread).
3. For area aggregation use gzonalstats (raster or vector mode). For localized point exposure use matchgeop + IDW.
4. Ensure consistent CRS, subset early, and request only needed statistics.

---
## 11. Glossary / 术语表
- AOI: Area of Interest 区域兴趣范围
- CRS: Coordinate Reference System 坐标参考系统
- IDW: Inverse Distance Weighting 反距离加权
- NoData: 缺失值编码

---
## 12. Citation / 引用
If you use this toolkit in academic work, please cite the project repository: https://github.com/kerrydu/readraster

---
## 13. Feedback / 反馈
Issues / feature requests: open a GitHub issue. 欢迎在 GitHub 上提建议或报告问题。
