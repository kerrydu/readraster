# 🌍 Breaking Through Stata's Geospatial Data Processing Limitations: New Geospatial Data Toolkit Released

**Language / 语言**: [🇺🇸 English](#english-version) | [🇨🇳 中文](#中文版本)

---

## <a id="english-version"></a>🇺🇸 English Version

### 📈 Why Is Geospatial Data So Important?

In today's data-driven research environment, geospatial data has become an indispensable research tool across multiple fields including economics, environmental science, and public health. From analyzing global agricultural climate risks using satellite remote sensing data, to supplementing official economic development indicators with nighttime light data, to studying the impact of agricultural straw burning on air pollution and health through satellite data—geospatial data is providing us with unprecedented research perspectives.

### 🚫 Pain Points for Stata Users

Although Stata excels in traditional data processing and statistical inference, it has obvious limitations when handling geographic data:

- **Limited Format Support**: Cannot directly import common geographic data formats like GeoTIFF and NetCDF
- **Cumbersome Workflow**: Requires data preprocessing in ArcGIS, QGIS, R, or Python before importing into Stata
- **Low Efficiency**: Fragmented workflows affect research reproducibility and increase operational complexity

### 💡 Innovative Solution: readraster Toolkit

A research team from Xiamen University, Southwestern University of Finance and Economics, and Hefei University of Technology has fully leveraged the Java integration functionality introduced in Stata 18 to develop a brand-new geospatial data processing toolkit.

#### 📦 Quick Installation

**One-click Installation Command**:
```stata
net install readraster, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/main/)
```

**Project Homepage**: https://github.com/kerrydu/readraster

#### 🔧 Core Functions

**9 Powerful New Commands**:

1. **Environment Configuration Commands**
   - `geotools_init`: Configure GeoTools Java dependencies
   - ~~`netcdf_init`: Configure NetCDF Java dependencies~~

2. **Data Exploration Commands**
   - `gtiffdisp`: Display GeoTIFF file metadata
   - `ncdisp`: Display NetCDF file metadata

3. **Data Reading Commands**
   - `gtiffread`: Read GeoTIFF data and vectorize
   - `ncread`: Read NetCDF data and vectorize
   - `ncsubset`: Slice a NetCDF variable and write a new NetCDF file (drops non-spatial singleton axes)

4. **Spatial Operation Commands**
   - `crsconvert`: Coordinate system conversion
   - `gzonalstats`: Calculate zonal statistics (mean, standard deviation, extremes, etc.)
   - `matchgeop`: Nearest neighbor matching based on geographic location

#### 🎯 Supported Data Formats

**GeoTIFF Format**
- 🌟 **Advantages**: Industry standard format, wide software support, suitable for 2D/3D raster data
- 📊 **Applications**: High-resolution imagery, Digital Elevation Models (DEM)

**NetCDF Format**
- 🌟 **Advantages**: Scientific data standard, supports complex multi-dimensional datasets, rich metadata
- 📊 **Applications**: Climate model outputs, time series data

### 🚀 Practical Application Scenarios

#### Environment Setup Examples

**GeoTools Dependency Configuration**:

Since GeoTools library files are large, the download process may be time-consuming. We recommend users manually download the GeoTools package from Sourceforge to save time:

🔗 **Manual Download Address**: https://sourceforge.net/projects/geotools/files/GeoTools%2032%20Releases/32.0/

```stata
// After manual download and extraction, initialize GeoTools environment
geotools_init "C:/geotools-32.0/lib/"

// Or download directly within Stata (slower)
geotools_init, download
```

~~**NetCDF Dependency Configuration**:~~

```stata

```

#### Data Exploration Examples

##### 🔍 GeoTIFF File Metadata Exploration

Let's use China's improved DMSP nighttime light data (DMSP-like2020.tif) as an example to show how to view detailed information of GeoTIFF files:

```stata
// View GeoTIFF metadata
gtiffdisp DMSP-like2020.tif
```

**Output Interpretation**:
```
=== Band Information ===
Number of bands: 1
Band 1 : GRAY_INDEX | NoData: Not defined

=== Spatial Characteristics ===
X range: [-2643772.8565 ~ 2212227.1435]
Y range: [1871896.5263 ~ 5926896.5263]
Resolution: X=1000.0000 units/pixel, Y=1000.0000 units/pixel

=== Coordinate System ===
CRS Name: PCS Name = WGS_1984_Albers
CRS WKT: PROJCS["PCS Name = WGS_1984_Albers", ...]

=== Unit Information ===
X unit: m
Y unit: m
```

This output tells us:
- 📊 **Single-band Data**: Contains one grayscale index band
- 🗺️ **Coordinate System**: Uses WGS_1984_Albers equal-area conic projection
- 📐 **Spatial Resolution**: 1000m×1000m/pixel
- 📏 **Coverage Range**: X-axis ~4.86 million meters, Y-axis ~4.05 million meters

##### 🌐 NetCDF File Metadata Exploration

For climate data, we use the NEX-GDDP-CMIP6 dataset as an example to show NetCDF file metadata viewing:

```stata
// Define remote NetCDF file URL
local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/" + ///
    "NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/" + ///
    "tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"

// View entire NetCDF file structure
ncdisp using "`url'"
```

**Key Information Interpretation**:
```
[Dimension Information]
time: 365 days
lat: 600 latitude points
lon: 1440 longitude points

[Variable Information]
tas: Daily near-surface air temperature (time lat lon)
time: Time dimension (days since 2040-01-01)
lat: Latitude dimension
lon: Longitude dimension
```

View detailed attributes of specific variables:

```stata
// View detailed temperature variable information
ncdisp tas using "`url'"
```

**Output Interpretation**:
- 🌡️ **Variable Meaning**: Daily Near-Surface Air Temperature
- 📊 **Data Type**: float type, shape [365, 600, 1440]
- 🌍 **Unit**: Kelvin temperature (K)
- ❌ **Missing Values**: 1.0E20

##### 📍 Actual Data Reading Examples

**Reading Hunan Province Nighttime Light Data**:

```stata
// 1. Coordinate system conversion (convert Hunan province boundaries to match data file projection)
shp2dta using "hunan.shp", database(hunan_db) coordinates(hunan_coord)
use "hunan_coord.dta", clear
crsconvert _X _Y, gen(alber_) from(hunan.shp) to(DMSP-like2020.tif)

// 2. Determine reading range (extend boundaries by 2000m to ensure complete coverage)
qui sum alber__X
local maxX = r(max)+2000
local minX = r(min)-2000

// 3. Read raster data for specified region
gtiffread DMSP-like2020.tif, origin(`start_row' `start_col') ///
    size(`n_rows' `n_cols') clear
```

**Reading Hunan Province Temperature Data**:

```stata
// Hunan Province longitude/latitude range: 108°47'E-114°15'E, 24°38'N-30°08'N
local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/..."

// 1. Determine longitude index range
ncread lon using "`url'", clear
gen n = _n
qui sum n if lon>=108 & lon<=115
local lon_start = r(min)
local lon_count = r(N)

// 2. Determine latitude index range  
ncread lat using "`url'", clear
gen n = _n
qui sum n if lat>=24 & lat<=31
local lat_start = r(min)
local lat_count = r(N)

// 3. Read Hunan Province 2050 annual temperature data
ncread tas using "`url'", clear origin(1 `lat_start' `lon_start') ///
    size(-1 `lat_count' `lon_count')

// 4. Process time dimension
gen date = time - 3650.5 + date("2050-01-01", "YMD")
format date %td
```


These examples demonstrate the powerful capabilities of the toolkit:

✅ **Complete Metadata Display**: Quickly understand data structure and attributes

✅ **Precise Regional Extraction**: Intelligent data clipping based on geographic boundaries

✅ **Multi-format Support**: Unified processing of GeoTIFF and NetCDF formats

✅ **Coordinate System Conversion**: Automatic handling of different projection systems

✅ **Time Dimension Processing**: Intelligent parsing of time encoding formats

### 🔧 Technical Implementation Details

The readraster toolkit leverages Stata 18+'s Java plugin functionality:

#### 📊 Core Technical Features

##### 🌐 Multi-dimensional Data Processing Capabilities
- **GeoTIFF Support**: Based on Geotools underlying library, supports multi-band raster data
- **NetCDF Integration**: Uses Unidata NetCDF-Java library to process scientific data
- **Memory Optimization**: Intelligent chunked reading, supports large dataset processing
- **Streaming Processing**: Supports direct access to remote data sources without local downloads

##### 🗺️ Geospatial Computing
- **Coordinate Reference System (CRS) Conversion**: Supports over 4000 projection systems
- **Spatial Indexing**: Efficient geographic location matching algorithms
- **Zonal Statistics**: Vectorized zonal statistics calculations


#### 🔬 Algorithm Implementation Details

##### Raster Data Vectorization Algorithm
```stata
// Efficient raster-to-vector algorithm example
gtiffread elevation.tif, clear
// Automatically generates: x, y, value variables
// Supports conditional filtering and regional clipping
```

#### 📖 In-depth Technical Documentation

Want to learn more about technical implementation details? Please check the complete technical documentation:

📄 **Technical Manual**: https://github.com/kerrydu/readraster/blob/main/readraster-manuscript.pdf

### 🔮 Future Outlook

Although this toolkit has greatly enhanced Stata's geospatial data processing capabilities, the research team has also identified future improvement directions:

- **Storage Optimization**: Reduce disk footprint of dependency libraries
- **Function Expansion**: Add more advanced geographic processing functions (buffer creation, raster clipping, etc.)
- **Visualization Enhancement**: Provide more intuitive data operation interfaces

### 🎉 Significance for Researchers

The release of this toolkit is of milestone significance for researchers who rely on Stata for statistical analysis:

✅ **Simplified Workflow**: Process geographic data directly within Stata

✅ **Improved Efficiency**: Avoid switching between multiple software

✅ **Enhanced Reproducibility**: Complete analysis process recording

✅ **Lower Barriers**: No need to master additional GIS software

### 📚 Learn More

This research is led by Associate Professor Kerry Du's team from the School of Management at Xiamen University, in collaboration with researchers from Southwestern University of Finance and Economics and Hefei University of Technology. The development of this toolkit was supported by the National Natural Science Foundation of China (Project Numbers: 72473119 and 72074184).

**Related Resources**:
- 🗂️ **Project Homepage**: https://github.com/kerrydu/readraster
- 📦 **GeoTools Download**: https://sourceforge.net/projects/geotools/files/GeoTools%2032%20Releases/32.0/
- 📖 **Complete Documentation**: See project GitHub page for details

---

*The release of this toolkit marks an important step forward for Stata in the field of geospatial data analysis. For researchers, this is not only a technical breakthrough, but also opens the door to new research possibilities.🚪✨*

**Keywords**: #Stata #GeospatialData #GeoTIFF #NetCDF #DataAnalysis #AcademicResearch

---

## <a id="中文版本"></a>🇨🇳 中文版本

### 📈 为什么地理空间数据如此重要？

在当今数据驱动的研究环境中，地理空间数据已经成为经济学、环境科学、公共卫生等多个领域不可或缺的研究工具。从卫星遥感数据分析全球农业气候风险，到利用夜间灯光数据补充官方经济发展指标，再到通过卫星数据研究农业秸秆燃烧对空气污染和健康的影响——地理空间数据正在为我们提供前所未有的研究视角。

### 🚫 Stata用户的痛点

尽管Stata在传统数据处理和统计推断方面表现卓越，但在处理地理数据方面却存在明显局限：

- **格式支持有限**：无法直接导入GeoTIFF和NetCDF等常用地理数据格式
- **工作流程繁琐**：需要在ArcGIS、QGIS、R或Python中预处理数据，再导入Stata
- **效率低下**：分割式的工作流程影响研究的可重现性，增加了操作复杂度

### 💡 创新解决方案：readraster工具包

来自厦门大学、西南财经大学和合肥工业大学的研究团队，充分利用Stata 18引入的Java集成功能，开发了一套全新的地理空间数据处理工具包。

#### 📦 快速安装

**一键安装命令**：
```stata
net install readraster, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/main/)
```

**项目主页**：https://github.com/kerrydu/readraster

#### 🔧 核心功能

**9个强大的新命令**：

1. **环境配置命令**
   - `geotools_init`：配置GeoTools Java依赖
   - ~~`netcdf_init`：配置NetCDF Java依赖~~

2. **数据探索命令**
   - `gtiffdisp`：显示GeoTIFF文件元信息
   - `ncdisp`：显示NetCDF文件元信息

3. **数据读取命令**
   - `gtiffread`：读取GeoTIFF数据并向量化
   - `ncread`：读取NetCDF数据并向量化
   - `ncsubset`：切片NetCDF变量并写入新NetCDF（删除非空间的单例坐标轴）

4. **空间操作命令**
   - `crsconvert`：坐标系转换
   - `gzonalstats`：计算区域统计（均值、标准差、最值等）
   - `nzonalstats`：NetCDF区域统计（基于gzonalstats扩展）
   - `matchgeop`：基于地理位置的最近邻匹配

#### 🎯 支持的数据格式

**GeoTIFF格式**
- 🌟 **优势**：工业标准格式，软件支持广泛，适合2D/3D栅格数据
- 📊 **应用**：高分辨率影像、数字高程模型(DEM)

**NetCDF格式**
- 🌟 **优势**：科学数据标准，支持复杂多维数据集，元数据丰富
- 📊 **应用**：气候模型输出、时间序列数据

### 🚀 实际应用场景

#### 环境设置示例

**GeoTools依赖配置**：

由于GeoTools库文件较大，下载过程可能较为耗时。我们建议用户手动从Sourceforge下载GeoTools包以节省时间：

🔗 **手动下载地址**：https://sourceforge.net/projects/geotools/files/GeoTools%2032%20Releases/32.0/

```stata
// 手动下载并解压后，初始化GeoTools环境
geotools_init "C:/geotools-32.0/lib/"

// 或者直接在Stata内下载（较慢）
geotools_init, download
```

~~**NetCDF依赖配置**：~~

```stata

```

#### 数据探索示例

##### 🔍 GeoTIFF文件元数据探索

让我们以中国改进的DMSP夜间灯光数据（DMSP-like2020.tif）为例，展示如何查看GeoTIFF文件的详细信息：

```stata
// 查看GeoTIFF元数据
gtiffdisp DMSP-like2020.tif
```

**输出结果解读**：
```
=== 波段信息 ===
Number of bands: 1
Band 1 : GRAY_INDEX | NoData: Not defined

=== 空间特征 ===
X range: [-2643772.8565 ~ 2212227.1435]
Y range: [1871896.5263 ~ 5926896.5263]
Resolution: X=1000.0000 units/pixel, Y=1000.0000 units/pixel

=== 坐标系统 ===
CRS Name: PCS Name = WGS_1984_Albers
CRS WKT: PROJCS["PCS Name = WGS_1984_Albers", ...]

=== 单位信息 ===
X unit: m
Y unit: m
```

这个输出告诉我们：
- 📊 **单波段数据**：包含一个灰度索引波段
- 🗺️ **坐标系统**：采用WGS_1984_Albers等面积圆锥投影
- 📐 **空间分辨率**：1000米×1000米/像素
- 📏 **覆盖范围**：X轴约486万米，Y轴约405万米

##### 🌐 NetCDF文件元数据探索

对于气候数据，我们以NEX-GDDP-CMIP6数据集为例，展示NetCDF文件的元数据查看：

```stata
// 定义远程NetCDF文件URL
local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/" + ///
    "NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/" + ///
    "tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"

// 查看整个NetCDF文件结构
ncdisp using "`url'"
```

**关键信息解读**：
```
[维度信息]
time: 365天
lat: 600个纬度点
lon: 1440个经度点

[变量信息]
tas: 日平均近地表气温 (time lat lon)
time: 时间维度 (days since 2040-01-01)
lat: 纬度维度
lon: 经度维度
```

查看特定变量的详细属性：

```stata
// 查看温度变量详细信息
ncdisp tas using "`url'"
```

**输出解读**：
- 🌡️ **变量含义**：Daily Near-Surface Air Temperature
- 📊 **数据类型**：float型，形状为[365, 600, 1440]
- 🌍 **单位**：开尔文温度(K)
- ❌ **缺失值**：1.0E20

##### 📍 实际数据读取示例

**读取湖南省夜间灯光数据**：

```stata
// 1. 坐标系转换（将湖南省边界转为与数据文件一致的投影）
shp2dta using "hunan.shp", database(hunan_db) coordinates(hunan_coord)
use "hunan_coord.dta", clear
crsconvert _X _Y, gen(alber_) from(hunan.shp) to(DMSP-like2020.tif)

// 2. 确定读取范围（扩展边界2000米确保完全覆盖）
qui sum alber__X
local maxX = r(max)+2000
local minX = r(min)-2000

// 3. 读取指定区域的栅格数据
gtiffread DMSP-like2020.tif, origin(`start_row' `start_col') ///
    size(`n_rows' `n_cols') clear
```

**读取湖南省气温数据**：

```stata
// 湖南省经纬度范围：108°47'E-114°15'E, 24°38'N-30°08'N
local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/..."

// 1. 确定经度索引范围
ncread lon using "`url'", clear
gen n = _n
qui sum n if lon>=108 & lon<=115
local lon_start = r(min)
local lon_count = r(N)

// 2. 确定纬度索引范围  
ncread lat using "`url'", clear
gen n = _n
qui sum n if lat>=24 & lat<=31
local lat_start = r(min)
local lat_count = r(N)

// 3. 读取湖南省2050年全年气温数据
ncread tas using "`url'", clear origin(1 `lat_start' `lon_start') ///
    size(-1 `lat_count' `lon_count')

// 4. 处理时间维度
gen date = time - 3650.5 + date("2050-01-01", "YMD")
format date %td
```


这些示例展现了工具包的强大功能：

✅ **元数据完整显示**：快速了解数据结构和属性

✅ **精确区域提取**：基于地理边界智能裁切数据

✅ **多格式支持**：统一处理GeoTIFF和NetCDF格式

✅ **坐标系转换**：自动处理不同投影系统

✅ **时间维度处理**：智能解析时间编码格式

### 🔧 技术实现细节

readraster工具包利用Stata 18+的Java插件功能：

#### 📊 核心技术特性

##### 🌐 多维数据处理能力
- **GeoTIFF支持**：基于Geotools底层库，支持多波段栅格数据
- **NetCDF集成**：利用Unidata NetCDF-Java库处理科学数据
- **内存优化**：智能分块读取，支持大型数据集处理
- **流式处理**：支持远程数据源直接访问，无需本地下载

##### 🗺️ 地理空间计算
- **坐标参考系统（CRS）转换**：支持超过4000种投影系统
- **空间索引**：高效的地理位置匹配算法
- **区域统计**：矢量化的zonal statistics计算


#### 🔬 算法实现详解

##### 栅格数据向量化算法
```stata
// 高效的栅格转向量算法示例
gtiffread elevation.tif, clear
// 自动生成：x, y, value变量
// 支持条件筛选和区域裁剪
```

#### 📖 深入技术文档

想了解更多技术实现细节？请查看完整的技术文档：

📄 **技术手册**：https://github.com/kerrydu/readraster/blob/main/readraster-manuscript.pdf

### 🔮 未来展望

虽然这套工具已经大大增强了Stata的地理空间数据处理能力，但研究团队也指出了未来的改进方向：

- **存储优化**：减少依赖库的磁盘占用
- **功能扩展**：添加更多高级地理处理功能（缓冲区创建、栅格裁剪等）
- **可视化增强**：提供更直观的数据操作界面

### 🎉 对研究者的意义

这套工具的发布对于依赖Stata进行统计分析的研究者来说具有里程碑意义：

✅ **简化工作流程**：在Stata内直接处理地理数据

✅ **提高效率**：避免在多个软件间切换

✅ **增强可重现性**：完整的分析流程记录

✅ **降低门槛**：无需掌握额外的GIS软件

### 📚 了解更多

这项研究由厦门大学管理学院杜克锐副教授团队主导，联合西南财经大学和合肥工业大学的研究者共同完成。该工具包的开发得到了国家自然科学基金（项目编号：72473119和72074184）的资助。

**相关资源**：
- 🗂️ **项目主页**：https://github.com/kerrydu/readraster
- 📦 **GeoTools下载**：https://sourceforge.net/projects/geotools/files/GeoTools%2032%20Releases/32.0/
- 📖 **完整文档**：详见项目GitHub页面

---

*这个工具包的发布，标志着Stata在地理空间数据分析领域迈出了重要一步。对于广大研究者来说，这不仅是技术上的突破，更是打开了新的研究可能性的大门。🚪✨*

**关键词**：#Stata #地理空间数据 #GeoTIFF #NetCDF #数据分析 #学术研究

---
*发布日期：2025年10月5日*
