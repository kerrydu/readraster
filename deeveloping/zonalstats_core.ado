cap program drop zonalstats_core
program define zonalstats_core
version 17.0
syntax using/, Xvar(varname) Yvar(varname) Valuevar(varname) ///
    frame(name) CRS(string) [STATs(string)  NOData(real -9999) ]

// 默认统计量
if "`stats'"=="" {
    local stats "avg"
}

// 检查统计量是否在支持列表中
local stats_inlist count avg min max std sum
foreach stat of local stats {
    local unsupported: list stats - stats_inlist
    if "`unsupported'" != "" {
        di as error "Invalid stats parameter, must be a combination of count, avg, sum, min, max, and std"
        exit 198
    }
}

// 处理 shapefile 路径
local shpfile `using'
removequotes, file(`shpfile')
local shpfile `r(file)'
local shpfile = subinstr(`"`shpfile'"',"\","/",.)

// 判断路径是否为绝对路径
if !strmatch("`shpfile'", "*:\\*") & !strmatch("`shpfile'", "/*") {
    local shpfile = "`c(pwd)'/`shpfile'"
}

// 检查 shapefile 是否存在及其组件
local shpfile = subinstr(`"`shpfile'"',"\","/",.)

// 默认 CRS (WGS84)
if "`crs'"=="" {
    local crs "EPSG:4326"
}

parse_crsopt `crs'
local crstype  `r(crstype)'
local crsvalue `r(crsvalue)'

if `crstype'==1 { 
    // 检查文件后缀是不是tif
    local ext = substr("`crsvalue'", strlen("`crsvalue'")-3, 4)
    if "`ext'"!=".tif" {
        di as error "CRS reference file must have .tif extension"
        exit 198
    }
    if !strmatch("`crsvalue'", "*:\\*") & !strmatch("`crsvalue'", "/*") {
        local crsvalue = "`c(pwd)'/`crsvalue'"
    }
}
if `crstype'==2{
    // 检查文件后缀是不是shp
    local ext = substr("`crsvalue'", strlen("`crsvalue'")-3, 4)
    if "`ext'"!=".shp" {
        di as error "CRS reference file must have .shp extension"
        exit 198
    }
    if !strmatch("`crsvalue'", "*:\\*") & !strmatch("`crsvalue'", "/*") {
        local crsvalue = "`c(pwd)'/`crsvalue'"
    }
}
if `crstype'==3{
    // 检查文件后缀是不是nc
    local ext = substr("`crsvalue'", strlen("`crsvalue'")-2, 3)
    if "`ext'"!=".nc" {
        di as error "CRS reference file must have .nc extension"
        exit 198
    }
    if !strmatch("`crsvalue'", "*:\\*") & !strmatch("`crsvalue'", "/*") {
        local crsvalue = "`c(pwd)'/`crsvalue'"
    }
}

scalar crstype = `crstype'

local crsvalue = subinstr(`"`crsvalue'"',"\","/",.)

// 检查变量是否存在
confirm variable `xvar' `yvar' `valuevar'

// 检查数据是否已排序（建议但非必需）
quietly isid `xvar' `yvar', missok
if _rc {
    di as text "Note: Data is not uniquely identified by `xvar' and `yvar'"
    di as text "Duplicate coordinates will use the last value"
}

qui pwf 
local pwf = r(currentframe)

// 计算栅格参数
qui su `xvar', meanonly
scalar xmin = r(min)
scalar xmax = r(max)
qui su `yvar', meanonly
scalar ymin = r(min)
scalar ymax = r(max)
qui gsort `xvar' -`yvar'
scalar resolution = `yvar'[1] - `yvar'[2]

distinct `xvar'
scalar width = r(ndistinct) 
distinct `yvar'
scalar height = r(ndistinct) 

// 处理 frame 选项
if "`frame'" != "" {
    // 检查 frame 是否已存在
    cap cwf `frame'
    if _rc =0 {
        qui cwf `pwf'
        di as error "Frame `frame' already exists. Please use a different name or drop the existing frame."
        exit 110
    }
    
    // 创建新 frame
    frame create `frame'
    di as text "Results will be stored in frame: `frame'"
    
    // 切换到目标 frame
    frame change `frame'
    di as text "Switched to frame: `frame'"
}

// 调用 Java 代码
di as text "Processing vector data with zonal statistics..."
java: ZonalStatsFromData.main("`xvar'", "`yvar'", "`valuevar'", "`shpfile'", `crstype', "`crsvalue'", `nodata', "`stats'")

// 添加变量标签 - 与 gzonalstats_core.ado 完全一致
cap confirm var count
if !_rc {
    label var count "Number of pixels in zone"
}
cap confirm var avg
if !_rc {
    label var avg "Average pixel value in zone"
}
cap confirm var min
if !_rc {
    label var min "Minimum pixel value in zone"
}
cap confirm var max
if !_rc {
    label var max "Maximum pixel value in zone"
}
cap confirm var std
if !_rc {
    label var std "Standard deviation of pixel values in zone"
}
cap confirm var sum
if !_rc {
    label var sum "Sum of pixel values in zone"
}

// 显示完成信息
if "`frame'" != "" {
    di as text "Results successfully stored in frame: `frame'"
    di as text "Current frame: `frame'"
    di as text "Use 'frame change `pwf'' for switching back to the previous frame"
}

end

// 辅助程序：移除引号
cap program drop removequotes
program define removequotes, rclass
version 16
syntax, file(string) 
return local file `file'
end

cap program drop parse_crsopt
program define parse_crsopt, rclass
syntax anything, [tif shp nc]

// 检查选项互斥性
local optcount = ("`tif'"!="") + ("`shp'"!="") + ("`nc'"!="")
if `optcount' > 1 {
    di as error "Options tif, shp, and nc are mutually exclusive"
    exit 198
}

local crstype 0
local crsvalue `anything'

if "`tif'"!="" {
    local crstype 1
}
if "`shp'"!="" {
    local crstype 2
}
if "`nc'"!="" {
    local crstype 3
}

return local crstype `crstype'
return local crsvalue `crsvalue'

end

////////////////////////////////////////

java:

// 添加 NetCDF 相关的 jar 包
/cp gt-main-32.0.jar
/cp gt-coverage-32.0.jar
/cp gt-shapefile-32.0.jar
/cp gt-geotiff-32.0.jar
/cp gt-process-raster-32.0.jar
/cp gt-epsg-hsql-32.0.jar
/cp gt-epsg-extension-32.0.jar
/cp gt-referencing-32.0.jar
/cp gt-api-32.0.jar
/cp gt-metadata-32.0.jar

// NetCDF 相关依赖
/cp gt-netcdf-32.0.jar
/cp netcdf4-5.5.3.jar
/cp cdm-core-5.5.3.jar
/cp udunits-5.5.3.jar

// External dependencies
/cp json-simple-1.1.1.jar
/cp commons-lang3-3.15.0.jar
/cp commons-io-2.16.1.jar
/cp jts-core-1.20.0.jar

// 添加 NetCDF 相关的 import
import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.List;
import java.util.ArrayList;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.logging.ConsoleHandler;
import java.util.logging.Handler;
import java.awt.image.WritableRaster;
import java.awt.image.DataBuffer;

// GeoTools API imports
import org.geotools.api.parameter.GeneralParameterValue;
import org.geotools.api.parameter.ParameterValue;
import org.geotools.api.feature.simple.SimpleFeature;
import org.geotools.api.referencing.crs.CoordinateReferenceSystem;
import org.geotools.api.coverage.grid.GridEnvelope;

// GeoTools implementation imports
import org.geotools.coverage.grid.GridCoverage2D;
import org.geotools.coverage.grid.GridCoverageFactory;
import org.geotools.coverage.grid.GridGeometry2D;
import org.geotools.coverage.grid.GridEnvelope2D;
import org.geotools.coverage.grid.io.AbstractGridCoverage2DReader;
import org.geotools.coverage.grid.io.AbstractGridFormat;
import org.geotools.data.shapefile.ShapefileDataStore;
import org.geotools.data.shapefile.ShapefileDataStoreFactory;
import org.geotools.data.simple.SimpleFeatureCollection;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.store.ReprojectingFeatureCollection;
import org.geotools.gce.geotiff.GeoTiffReader;
import org.geotools.geometry.jts.ReferencedEnvelope;
import org.geotools.process.raster.RasterZonalStatistics;
import org.geotools.referencing.CRS;

// NetCDF imports
import org.geotools.imageio.netcdf.NetCDFReader;

// Stata SFI imports
import com.stata.sfi.Data;
import com.stata.sfi.DataFrame;
import com.stata.sfi.SFIToolkit;
import com.stata.sfi.Scalar;
import com.stata.sfi.Macro;

public class ZonalStatsFromData {

    static {
        // 完全参考 gzonalstats_core.ado 的日志设置
        System.setProperty("org.geotools.referencing.forceXY", "true");
        System.setProperty("org.geotools.factory.hideLegacyServiceImplementations", "true");

        Logger logger = Logger.getLogger("org.geotools.util.factory");
        logger.setLevel(Level.SEVERE);

        Logger geoToolsLogger = Logger.getLogger("org.geotools");
        geoToolsLogger.setLevel(Level.WARNING);
        for (Handler handler : geoToolsLogger.getHandlers()) {
            if (handler instanceof ConsoleHandler) {
                handler.setLevel(Level.WARNING);
            }
        }
    }

    public static void main(String xVar, String yVar, String valueVar, 
                           String shpPath, int crsType, String crsString, 
                           double noDataValue, String statsParam) throws Exception {
        
        // 资源管理 - 完全参考 gzonalstats_core.ado
        ShapefileDataStore shapefileDataStore = null;
        SimpleFeatureIterator featureIterator = null;
        SimpleFeatureCollection featureCollection = null;
        AbstractGridCoverage2DReader crsReader = null;
        
        try {
            // Disable excessive logging
            Logger.getGlobal().setLevel(Level.SEVERE);
            
            // Parse requested statistics - 与 gzonalstats_core.ado 完全一致
            String[] requestedStats = statsParam.toLowerCase().split("\\s+");
            boolean showCount = false, showAvg = false, showMin = false;
            boolean showMax = false, showStd = false, showSum = false;
            
            for (String stat : requestedStats) {
                switch(stat.trim()) {
                    case "count": showCount = true; break;
                    case "avg": showAvg = true; break;
                    case "min": showMin = true; break;
                    case "max": showMax = true; break;
                    case "std": showStd = true; break;
                    case "sum": showSum = true; break;
                }
            }
            
            // Step 1: Read vector data from Stata
            SFIToolkit.displayln("Reading vector data from Stata...");
            string pwf = Macro.getLocal("pwf");
            long nObs = DataFrame.getObsTotal(pwf);
            
            int xVarIndex = DataFrame.getVarIndex(pwf,xVar);
            int yVarIndex = DataFrame.getVarIndex(pwf,yVar);
            int valueVarIndex = DataFrame.getVarIndex(pwf,valueVar);
            
            double[] xValues = new double[nObs];
            double[] yValues = new double[nObs];
            double[] values = new double[nObs];
            
            for (int i = 0; i < nObs; i++) {
                xValues[i] = DataFrame.getNum(pwf,xVarIndex, i + 1);
                yValues[i] = DataFrame.getNum(pwf,yVarIndex, i + 1);
                values[i] = DataFrame.getNum(pwf,valueVarIndex, i + 1);
            }
            
            SFIToolkit.displayln("Read " + nObs + " observations");
            
            // Step 2: Get grid parameters from Stata scalars
            double minX = Scalar.getValue("xmin");
            double maxX = Scalar.getValue("xmax");
            double minY = Scalar.getValue("ymin");
            double maxY = Scalar.getValue("ymax");
            double resolution = Scalar.getValue("resolution");
            int width = (int)Scalar.getValue("width");
            int height = (int)Scalar.getValue("height");
            
            SFIToolkit.displayln("Grid parameters:");
            SFIToolkit.displayln("  Bounds: (" + minX + ", " + minY + ") to (" + maxX + ", " + maxY + ")");
            SFIToolkit.displayln("  Resolution: " + resolution);
            SFIToolkit.displayln("  Dimensions: " + width + " x " + height);
            
            // Step 3: Determine CRS - 添加 NetCDF 支持
            CoordinateReferenceSystem crs;
            if (crsType == 0) {
                // EPSG code
                crs = CRS.decode(crsString, true);
                SFIToolkit.displayln("Using CRS from EPSG code: " + crsString);
            } else if (crsType == 1) {
                // From TIF file
                File tifFile = new File(crsString);
                if (!tifFile.exists()) {
                    SFIToolkit.errorln("TIF file does not exist: " + crsString);
                    return;
                }
                crsReader = new GeoTiffReader(tifFile);
                crs = crsReader.getCoordinateReferenceSystem();
                SFIToolkit.displayln("Using CRS from TIF file: " + crsString);
            } else if (crsType == 2) {
                // From SHP file
                File shpFile = new File(crsString);
                if (!shpFile.exists()) {
                    SFIToolkit.errorln("Shapefile does not exist: " + crsString);
                    return;
                }
                ShapefileDataStoreFactory factory = new ShapefileDataStoreFactory();
                Map<String, Object> params = new HashMap<>();
                params.put("url", shpFile.toURI().toURL());
                ShapefileDataStore tempStore = (ShapefileDataStore) factory.createDataStore(params);
                crs = tempStore.getSchema().getCoordinateReferenceSystem();
                tempStore.dispose();
                SFIToolkit.displayln("Using CRS from shapefile: " + crsString);
            } else if (crsType == 3) {
                // From NetCDF file - 新增
                File ncFile = new File(crsString);
                if (!ncFile.exists()) {
                    SFIToolkit.errorln("NetCDF file does not exist: " + crsString);
                    return;
                }
                crsReader = new NetCDFReader(ncFile, null);
                crs = crsReader.getCoordinateReferenceSystem();
                SFIToolkit.displayln("Using CRS from NetCDF file: " + crsString);
                
                // 如果 NetCDF 文件没有明确的 CRS，尝试从元数据推断
                if (crs == null) {
                    SFIToolkit.displayln("Warning: NetCDF file does not contain explicit CRS information");
                    SFIToolkit.displayln("Attempting to infer CRS from metadata...");
                    
                    // 尝试读取常见的 CRS 属性
                    crs = inferCRSFromNetCDF(ncFile);
                    
                    if (crs == null) {
                        SFIToolkit.errorln("Could not infer CRS from NetCDF file. Please specify EPSG code explicitly.");
                        return;
                    } else {
                        SFIToolkit.displayln("Inferred CRS: " + crs.getName().toString());
                    }
                }
            } else {
                SFIToolkit.errorln("Invalid CRS type: " + crsType);
                return;
            }
            
            SFIToolkit.displayln("Raster CRS: " + crs.getName().toString());
            
            // Step 4: Create raster from vector data
            WritableRaster raster = java.awt.image.Raster.createWritableRaster(
                new java.awt.image.BandedSampleModel(
                    DataBuffer.TYPE_DOUBLE, width, height, 1
                ), null
            );
            
            // Fill with nodata value
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    raster.setSample(x, y, 0, noDataValue);
                }
            }
            
            // Fill raster with data
            for (int i = 0; i < nObs; i++) {
                int col = (int)Math.round((xValues[i] - minX) / resolution);
                int row = (int)Math.round((maxY - yValues[i]) / resolution);
                
                if (col >= 0 && col < width && row >= 0 && row < height) {
                    raster.setSample(col, row, 0, values[i]);
                }
            }
            
            SFIToolkit.displayln("Raster created successfully");
            
            // Step 5: Create GridCoverage2D
            ReferencedEnvelope envelope = new ReferencedEnvelope(
                minX, maxX, minY, maxY, crs
            );
            
            GridCoverageFactory factory = new GridCoverageFactory();
            GridCoverage2D coverage = factory.create(
                "VectorRaster",
                raster,
                envelope
            );
            
            SFIToolkit.displayln("GridCoverage2D created");
            
            // Step 6: Load shapefile - 完全参考 gzonalstats_core.ado
            File shpFile = new File(shpPath);
            if (!shpFile.exists()) {
                SFIToolkit.errorln("Shapefile does not exist: " + shpPath);
                return;
            }

            // Check for required components - 与 gzonalstats_core.ado 一致
            String basePath = shpPath.substring(0, shpPath.lastIndexOf("."));
            File shxFile = new File(basePath + ".shx");
            File dbfFile = new File(basePath + ".dbf");
            File prjFile = new File(basePath + ".prj");

            if (!shxFile.exists() || !dbfFile.exists() || !prjFile.exists()) {
                SFIToolkit.displayln("Warning: Missing required shapefile components:");
                if (!shxFile.exists()) SFIToolkit.displayln(" - Missing .shx index file");
                if (!dbfFile.exists()) SFIToolkit.displayln(" - Missing .dbf attribute file");
                if (!prjFile.exists()) SFIToolkit.displayln(" - Missing .prj projection file");
                SFIToolkit.errorln("A complete shapefile requires .shp, .shx, .dbf and .prj files.");
                return;
            }
            
            ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
            Map<String, Object> shpParams = new HashMap<>();
            shpParams.put("url", shpFile.toURI().toURL());
            shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);
            shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));
            
            featureCollection = shapefileDataStore.getFeatureSource().getFeatures();
            
            // CRS handling - 完全参考 gzonalstats_core.ado
            CoordinateReferenceSystem vectorCRS = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
            SFIToolkit.displayln("Shapefile CRS: " + vectorCRS.getName().toString());
            
            boolean needsReprojection = !CRS.equalsIgnoreMetadata(crs, vectorCRS);
            
            if (needsReprojection) {
                SFIToolkit.displayln("Reprojecting shapefile to match raster CRS");
                featureCollection = new ReprojectingFeatureCollection(featureCollection, crs);
            } else {
                SFIToolkit.displayln("Coordinate systems are compatible, no reprojection needed");
            }
            
            // Step 7: Calculate zonal statistics
            SFIToolkit.displayln("Calculating zonal statistics...");
            RasterZonalStatistics process = new RasterZonalStatistics();
            SimpleFeatureCollection resultFeatures = process.execute(
                coverage, 0, featureCollection, null
            );
            
            // Step 8: Process and export results - 完全参考 gzonalstats_core.ado 的处理方式
            List<SimpleFeature> allFeatures = new ArrayList<>();
            featureIterator = resultFeatures.features();
            try {
                while (featureIterator.hasNext()) {
                    allFeatures.add(featureIterator.next());
                }
            } finally {
                if (featureIterator != null) {
                    featureIterator.close();
                }
            }
            
            int totalFeatures = allFeatures.size();
            SFIToolkit.displayln("Total features: " + totalFeatures);
            
            if (totalFeatures > 0) {
                // 变量创建和数据填充逻辑 - 与 gzonalstats_core.ado 完全一致
                Map<String, Integer> attributeNameMap = new HashMap<>();
                List<String> idAttrNames = new ArrayList<>();
                String countAttrName = null;
                String avgAttrName = null;
                String minAttrName = null;
                String maxAttrName = null;
                String stddevAttrName = null;
                String sumAttrName = null;
                
                SimpleFeature firstFeature = allFeatures.get(0);
                for (int i = 0; i < firstFeature.getType().getAttributeCount(); i++) {
                    String attributeName = firstFeature.getType().getDescriptor(i).getLocalName();
                    
                    if (attributeName.equals("count")) {
                        if (showCount) countAttrName = attributeName;
                    } else if (attributeName.equals("avg")) {
                        if (showAvg) avgAttrName = attributeName;
                    } else if (attributeName.equals("min")) {
                        if (showMin) minAttrName = attributeName;
                    } else if (attributeName.equals("max")) {
                        if (showMax) maxAttrName = attributeName;
                    } else if (attributeName.equals("stddev")) {
                        if (showStd) stddevAttrName = attributeName;
                    } else if (attributeName.equals("sum")) {
                        if (showSum) sumAttrName = attributeName;
                    } else if (!attributeName.equals("the_geom") && !attributeName.equals("z_the_geom") &&
                              !attributeName.equals("sum_2")) {
                        idAttrNames.add(attributeName);
                    }
                }
                
                Data.setObsTotal(totalFeatures);
                
                int varIndex = 1;
                
                // Create ID attribute variables - 与 gzonalstats_core.ado 一致
                for (String idAttr : idAttrNames) {
                    Object value = firstFeature.getAttribute(idAttr);
                    
                    if (value instanceof Number) {
                        Data.addVarDouble(idAttr);
                        SFIToolkit.displayln("Created numeric variable: " + idAttr);
                    } else {
                        int strLength = 32;
                        if (value != null) {
                            String strValue = value.toString();
                            if (strValue.length() <= 16) {
                                strLength = 16;
                            } else if (strValue.length() <= 32) {
                                strLength = 32;
                            } else if (strValue.length() <= 48) {
                                strLength = 48;
                            } else {
                                strLength = 244;
                            }
                        }
                        
                        Data.addVarStr(idAttr, strLength);
                        SFIToolkit.displayln("Created string variable: " + idAttr + " (length " + strLength + ")");
                    }
                    
                    attributeNameMap.put(idAttr, varIndex++);
                }
                
                // Create statistics variables - 与 gzonalstats_core.ado 一致
                if (showCount && countAttrName != null) {
                    Data.addVarDouble("count");
                    attributeNameMap.put(countAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: count");
                }
                
                if (showAvg && avgAttrName != null) {
                    Data.addVarDouble("avg");
                    attributeNameMap.put(avgAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: avg");
                }
                
                if (showMin && minAttrName != null) {
                    Data.addVarDouble("min");
                    attributeNameMap.put(minAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: min");
                }
                
                if (showMax && maxAttrName != null) {
                    Data.addVarDouble("max");
                    attributeNameMap.put(maxAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: max");
                }
                
                if (showStd && stddevAttrName != null) {
                    Data.addVarDouble("std");
                    attributeNameMap.put(stddevAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: std");
                }
                
                if (showSum && sumAttrName != null) {
                    Data.addVarDouble("sum");
                    attributeNameMap.put(sumAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: sum");
                }
                
                // Fill data - 与 gzonalstats_core.ado 完全一致
                for (int i = 0; i < totalFeatures; i++) {
                    SimpleFeature feature = allFeatures.get(i);
                    int stataObs = i + 1;
                    
                    // ID attributes
                    for (String idAttr : idAttrNames) {
                        Object value = feature.getAttribute(idAttr);
                        int stataVar = attributeNameMap.get(idAttr);
                        
                        if (value != null) {
                            if (value instanceof Number) {
                                Data.storeNumFast(stataVar, stataObs, ((Number) value).doubleValue());
                            } else {
                                Data.storeStr(stataVar, stataObs, value.toString());
                            }
                        }
                    }
                    
                    // Statistics
                    if (showCount && countAttrName != null) {
                        Object value = feature.getAttribute(countAttrName);
                        if (value != null) {
                            Data.storeNumFast(attributeNameMap.get(countAttrName), stataObs, 
                                            ((Number) value).doubleValue());
                        }
                    }
                    
                    if (showAvg && avgAttrName != null) {
                        Object value = feature.getAttribute(avgAttrName);
                        if (value != null) {
                            Data.storeNumFast(attributeNameMap.get(avgAttrName), stataObs, 
                                            ((Number) value).doubleValue());
                        }
                    }
                    
                    if (showMin && minAttrName != null) {
                        Object value = feature.getAttribute(minAttrName);
                        if (value != null) {
                            Data.storeNumFast(attributeNameMap.get(minAttrName), stataObs, 
                                            ((Number) value).doubleValue());
                        }
                    }
                    
                    if (showMax && maxAttrName != null) {
                        Object value = feature.getAttribute(maxAttrName);
                        if (value != null) {
                            Data.storeNumFast(attributeNameMap.get(maxAttrName), stataObs, 
                                            ((Number) value).doubleValue());
                        }
                    }
                    
                    if (showStd && stddevAttrName != null) {
                        Object value = feature.getAttribute(stddevAttrName);
                        if (value != null) {
                            Data.storeNumFast(attributeNameMap.get(stddevAttrName), stataObs, 
                                            ((Number) value).doubleValue());
                        }
                    }
                    
                    if (showSum && sumAttrName != null) {
                        Object value = feature.getAttribute(sumAttrName);
                        if (value != null) {
                            Data.storeNumFast(attributeNameMap.get(sumAttrName), stataObs, 
                                            ((Number) value).doubleValue());
                        }
                    }
                }
                
                Data.updateModified();
                SFIToolkit.displayln("Data successfully exported to Stata dataset.");
            } else {
                SFIToolkit.displayln("No features found in the result set.");
            }
            
        } catch (Exception e) {
            SFIToolkit.errorln("Error in ZonalStatsFromData: " + e.getMessage());
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
        } finally {
            // 资源清理 - 与 gzonalstats_core.ado 完全一致
            try {
                if (featureIterator != null) {
                    featureIterator.close();
                }
                if (crsReader != null) {
                    crsReader.dispose();
                }
                if (shapefileDataStore != null) {
                    shapefileDataStore.dispose();
                }
                System.gc();
            } catch (Exception e) {
                SFIToolkit.errorln("Error closing resources: " + e.getMessage());
            }
        }
    }
    
    /**
     * 从 NetCDF 文件推断 CRS
     * 尝试读取常见的 CRS 相关属性
     */
    private static CoordinateReferenceSystem inferCRSFromNetCDF(File ncFile) {
        try {
            // 使用 NetCDF Java 库直接读取元数据
            ucar.nc2.NetcdfFile netcdfFile = ucar.nc2.NetcdfFiles.open(ncFile.getAbsolutePath());
            
            try {
                // 查找常见的 CRS 相关属性
                // 1. 查找 crs 变量
                ucar.nc2.Variable crsVar = netcdfFile.findVariable("crs");
                if (crsVar == null) {
                    crsVar = netcdfFile.findVariable("spatial_ref");
                }
                if (crsVar == null) {
                    crsVar = netcdfFile.findVariable("projection");
                }
                
                if (crsVar != null) {
                    // 尝试读取 EPSG 代码
                    ucar.nc2.Attribute epsgAttr = crsVar.findAttribute("epsg_code");
                    if (epsgAttr == null) {
                        epsgAttr = crsVar.findAttribute("EPSG");
                    }
                    
                    if (epsgAttr != null) {
                        int epsgCode = epsgAttr.getNumericValue().intValue();
                        SFIToolkit.displayln("Found EPSG code in NetCDF: " + epsgCode);
                        return CRS.decode("EPSG:" + epsgCode, true);
                    }
                    
                    // 尝试读取 WKT
                    ucar.nc2.Attribute wktAttr = crsVar.findAttribute("spatial_ref");
                    if (wktAttr == null) {
                        wktAttr = crsVar.findAttribute("crs_wkt");
                    }
                    
                    if (wktAttr != null) {
                        String wkt = wktAttr.getStringValue();
                        SFIToolkit.displayln("Found WKT in NetCDF");
                        return CRS.parseWKT(wkt);
                    }
                }
                
                // 2. 检查全局属性
                ucar.nc2.Attribute globalCrsAttr = netcdfFile.findGlobalAttribute("crs");
                if (globalCrsAttr != null) {
                    String crsString = globalCrsAttr.getStringValue();
                    if (crsString.startsWith("EPSG:")) {
                        return CRS.decode(crsString, true);
                    }
                }
                
                // 3. 默认假设为 WGS84
                SFIToolkit.displayln("No CRS metadata found, defaulting to WGS84 (EPSG:4326)");
                return CRS.decode("EPSG:4326", true);
                
            } finally {
                netcdfFile.close();
            }
            
        } catch (Exception e) {
            SFIToolkit.displayln("Error inferring CRS from NetCDF: " + e.getMessage());
            return null;
        }
    }
}

end