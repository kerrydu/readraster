cap program drop zonalstats
program define zonalstats
version 18.0
syntax using/, Xvar(varname) Yvar(varname) Valuevar(varname) ///
    frame(name) [STATs(string) CRS(string) NOData(real -9999) ]

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

// 默认 CRS (WGS84)
if "`crs'"=="" {
    local crs "EPSG:4326"
}

parse_crsopt `crs'
local crstype  `r(crstype)'
local crsvalue `r(crsvalue)'

if `crstype'==1 { 
    // 检查文件后缀是不是tif
    local ext = substr("`crsvalue'", strlen("`crsvalue'")-3, 3)
    if "`ext'"!=".tif" {
        di as error "Shapefile must have .tif extension"
        exit 198
    }
    if !strmatch("`crsvalue'", "*:\\*") & !strmatch("`crsvalue'", "/*") {
        local crsvalue = "`c(pwd)'/`crsvalue'"
    }
}
if `crstype'==2{
    // 检查文件后缀是不是nc
    local ext = substr("`crsvalue'", strlen("`crsvalue'")-2, 2)
    if "`ext'"!=".nc" {
        di as error "Shapefile must have .nc extension"
        exit 198
    }
    if !strmatch("`crsvalue'", "*:\\*") & !strmatch("`crsvalue'", "/*") {
        local crsvalue = "`c(pwd)'/`crsvalue'"
    }
}

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




// qui sort `yvar' `xvar'
// local xdelta = `xvar'[2] - `xvar'[1]
qui su `xvar' , meanonly
scalar xmin = r(min)
scalar xmax = r(max)
qui su `yvar' , meanonly
scalar ymin = r(min)
scalar ymax = r(max)
qui gsort `xvar' -`yvar'
scalar resolution = `yvar'[1] - `yvar'[2]

distinct `xvar'
scalar width = r(ndistinct) 
distinct `yvar'
scalar height = r(ndistinct) 

// // 准备数据：提取 x, y, value 到临时文件
// tempfile vectordata
// quietly {
//     // 保留非缺失的观测
//     preserve
//     keep if !missing(`xvar') & !missing(`yvar') 
    
//     // 按 x 和 y 排序（这有助于后续处理）
//     sort `xvar' `yvar'
    
//     // 只保留需要的变量
//     keep `xvar' `yvar' `valuevar'
    
//     // 保存为 CSV 格式供 Java 读取
//     export delimited using "`vectordata'.csv", delimiter(",") novarnames replace
//     restore
// }

// local vectordata = subinstr(`"`vectordata'"',"\","/",.)

// 处理 frame 选项
if "`frame'" != "" {
    // 检查 frame 是否已存在
    cap frame describe `frame'
    if !_rc {
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
java: ZonalStats.main("`xvar'", "`yvar'", "`valuevar'", "`shpfile'", "`crsvalue'", `nodata', "`stats'")

// 添加变量标签
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
    di as text "Use 'frame change `pwf' for switching back to the previous frame"
}

end

// 辅助程序：移除引号
cap program drop removequotes
program define removequotes, rclass
version 16
syntax, file(string) 
return local file `file'
end


program define parse_crsopt, rclass

syntax anyting,[tif nc]
if "`tif'"!="" & "`nc'"!="" {
    di as error "Options tif and nc are mutually exclusive"
    exit 198
}
local crstype 0
local crsvalue `anything'
if "`tif'"!="" {
    return local crstype 1
}
if "`nc'"!="" {
    return local crstype 2
}

return local crstype `crstype'
return local crsvalue `crsvalue'

end


java:


// Core GeoTools libraries
/cp gt-main-32.0.jar
/cp gt-coverage-32.0.jar
/cp gt-shapefile-32.0.jar
/cp gt-process-raster-32.0.jar
/cp gt-epsg-hsql-32.0.jar
/cp gt-epsg-extension-32.0.jar
/cp gt-referencing-32.0.jar
/cp gt-api-32.0.jar
/cp gt-metadata-32.0.jar

// External dependencies
/cp json-simple-1.1.1.jar
/cp commons-lang3-3.15.0.jar
/cp commons-io-2.16.1.jar
/cp jts-core-1.20.0.jar

import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.List;
import java.util.ArrayList;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.awt.image.WritableRaster;
import java.awt.image.DataBuffer;

import org.geotools.api.feature.simple.SimpleFeature;
import org.geotools.api.referencing.crs.CoordinateReferenceSystem;
import org.geotools.coverage.grid.GridCoverage2D;
import org.geotools.coverage.grid.GridCoverageFactory;
import org.geotools.coverage.grid.GridGeometry2D;
import org.geotools.coverage.grid.GridEnvelope2D;
import org.geotools.data.shapefile.ShapefileDataStore;
import org.geotools.data.shapefile.ShapefileDataStoreFactory;
import org.geotools.data.simple.SimpleFeatureCollection;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.store.ReprojectingFeatureCollection;
import org.geotools.geometry.jts.ReferencedEnvelope;
import org.geotools.process.raster.RasterZonalStatistics;
import org.geotools.referencing.CRS;

import com.stata.sfi.Data;
import com.stata.sfi.SFIToolkit;

public class ZonalStats {

    static {
        System.setProperty("org.geotools.referencing.forceXY", "true");
        Logger.getLogger("org.geotools").setLevel(Level.WARNING);
    }

    public static void main(String xVar, String yVar, String valueVar, 
                           String shpPath, String crsString, String statsParam) 
                           throws Exception {
        
        ShapefileDataStore shapefileDataStore = null;
        SimpleFeatureIterator featureIterator = null;
        
        try {
            // Parse requested statistics
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
            System.out.println("Reading vector data from Stata...");
            int nObs = Data.getObsTotal();
            
            int xVarIndex = Data.getVarIndex(xVar);
            int yVarIndex = Data.getVarIndex(yVar);
            int valueVarIndex = Data.getVarIndex(valueVar);
            
            double[] xValues = new double[nObs];
            double[] yValues = new double[nObs];
            double[] values = new double[nObs];
            
            for (int i = 0; i < nObs; i++) {
                xValues[i] = Data.getNum(xVarIndex, i + 1);
                yValues[i] = Data.getNum(yVarIndex, i + 1);
                values[i] = Data.getNum(valueVarIndex, i + 1);
            }
            
            System.out.println("Read " + nObs + " observations");
            
            // Step 2: Determine grid parameters
           // get xmin, xmax, ymin, ymax, resolution from stata scalars
            double minX = Data.getScalar("xmin");
            double maxX = Data.getScalar("xmax");
            double minY = Data.getScalar("ymin");
            double maxY = Data.getScalar("ymax");
            double resolution = Data.getScalar("resolution");
            // get width, height from stata scalars
            int width = Data.getScalar("width");
            int height = Data.getScalar("height");
            
            System.out.println("Grid parameters:");
            System.out.println("  Bounds: (" + minX + ", " + minY + ") to (" + maxX + ", " + maxY + ")");
            System.out.println("  Resolution: " + resolution);
            System.out.println("  Dimensions: " + width + " x " + height);
            
            // Step 3: Create raster from vector data
            WritableRaster raster = java.awt.image.Raster.createWritableRaster(
                new java.awt.image.BandedSampleModel(
                    DataBuffer.TYPE_DOUBLE, width, height, 1
                ), null
            );
            
            // Fill with nodata value
            double noDataValue = -9999.0;
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    raster.setSample(x, y, 0, noDataValue);
                }
            }
            
            // Fill raster with data
            for (int i = 0; i < nObs; i++) {
                int col = (int)Math.round((xValues[i] - minX) / resolution);
                int row = (int)Math.round((maxY - yValues[i]) / resolution); // Flip Y
                
                if (col >= 0 && col < width && row >= 0 && row < height) {
                    raster.setSample(col, row, 0, values[i]);
                }
            }
            
            System.out.println("Raster created successfully");
            
            // Step 4: Create GridCoverage2D
            // 从stata获取local crstype
            string crsType = Data.getLocal("crstype");
            if (crsType.equals("0")) {
                CoordinateReferenceSystem crs = CRS.decode(crsString);
            } 
            else if (crsType.equals("1")) {
                //从tif文件获取crs
                File tifFile = new File(crsString);
                if (!tifFile.exists()) {
                    System.out.println("TIF file does not exist: " + crsString);
                    return;
                }
                CoordinateReferenceSystem crs = GeoTools.getCRS(tifFile);
            }
            else if (crsType.equals("2")) {
                //从nc文件获取crs
                File ncFile = new File(crsString);
                if (!ncFile.exists()) {
                    System.out.println("NetCDF file does not exist: " + crsString);
                    return;
                }
                CoordinateReferenceSystem crs = GeoTools.getCRS(ncFile);
            }
            else {
                System.out.println("Invalid CRS type: " + crsType);
                return;
            }
            
            ReferencedEnvelope envelope = new ReferencedEnvelope(
                minX, maxX, minY, maxY, crs
            );
            
            GridCoverageFactory factory = new GridCoverageFactory();
            GridCoverage2D coverage = factory.create(
                "VectorRaster",
                raster,
                envelope
            );
            
            System.out.println("GridCoverage2D created with CRS: " + crsString);
            
            // Step 5: Load shapefile
            File shpFile = new File(shpPath);
            if (!shpFile.exists()) {
                System.out.println("Shapefile does not exist: " + shpPath);
                return;
            }
            
            ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
            Map<String, Object> shpParams = new HashMap<>();
            shpParams.put("url", shpFile.toURI().toURL());
            shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);
            shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));
            
            SimpleFeatureCollection featureCollection = shapefileDataStore.getFeatureSource().getFeatures();
            
            // Check CRS and reproject if needed
            CoordinateReferenceSystem vectorCRS = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
            if (!CRS.equalsIgnoreMetadata(crs, vectorCRS)) {
                System.out.println("Reprojecting shapefile to match raster CRS");
                featureCollection = new ReprojectingFeatureCollection(featureCollection, crs);
            }
            
            // Step 6: Calculate zonal statistics
            System.out.println("Calculating zonal statistics...");
            RasterZonalStatistics process = new RasterZonalStatistics();
            SimpleFeatureCollection resultFeatures = process.execute(
                coverage, 0, featureCollection, null
            );
            
            // Step 7: Export results to Stata
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
            System.out.println("Total features: " + totalFeatures);
            
            if (totalFeatures > 0) {
                // Set up Stata dataset (similar to original code)
                Data.setObsTotal(totalFeatures);
                
                SimpleFeature firstFeature = allFeatures.get(0);
                Map<String, Integer> attributeNameMap = new HashMap<>();
                List<String> idAttrNames = new ArrayList<>();
                
                int varIndex = 1;
                
                // Create ID variables
                for (int i = 0; i < firstFeature.getType().getAttributeCount(); i++) {
                    String attributeName = firstFeature.getType().getDescriptor(i).getLocalName();
                    
                    if (attributeName.equals("the_geom") || attributeName.startsWith("z_")) {
                        continue;
                    }
                    
                    if (!attributeName.equals("count") && !attributeName.equals("mean") &&
                        !attributeName.equals("min") && !attributeName.equals("max") &&
                        !attributeName.equals("stddev") && !attributeName.equals("sum")) {
                        
                        Object value = firstFeature.getAttribute(attributeName);
                        if (value instanceof Number) {
                            Data.addVarDouble(attributeName);
                        } else {
                            Data.addVarStr(attributeName, 244);
                        }
                        idAttrNames.add(attributeName);
                        attributeNameMap.put(attributeName, varIndex++);
                    }
                }
                
                // Create statistics variables
                if (showCount) {
                    Data.addVarDouble("count");
                    attributeNameMap.put("count", varIndex++);
                }
                if (showAvg) {
                    Data.addVarDouble("avg");
                    attributeNameMap.put("mean", varIndex++);
                }
                if (showMin) {
                    Data.addVarDouble("min");
                    attributeNameMap.put("min", varIndex++);
                }
                if (showMax) {
                    Data.addVarDouble("max");
                    attributeNameMap.put("max", varIndex++);
                }
                if (showStd) {
                    Data.addVarDouble("std");
                    attributeNameMap.put("stddev", varIndex++);
                }
                if (showSum) {
                    Data.addVarDouble("sum");
                    attributeNameMap.put("sum", varIndex++);
                }
                
                // Fill data
                for (int i = 0; i < totalFeatures; i++) {
                    SimpleFeature feature = allFeatures.get(i);
                    int stataObs = i + 1;
                    
                    // ID attributes
                    for (String idAttr : idAttrNames) {
                        Object value = feature.getAttribute(idAttr);
                        int stataVar = attributeNameMap.get(idAttr);
                        if (value != null) {
                            if (value instanceof Number) {
                                Data.storeNum(stataVar, stataObs, ((Number)value).doubleValue());
                            } else {
                                Data.storeStr(stataVar, stataObs, value.toString());
                            }
                        }
                    }
                    
                    // Statistics
                    if (showCount) {
                        Object value = feature.getAttribute("count");
                        if (value != null) {
                            Data.storeNum(attributeNameMap.get("count"), stataObs, 
                                        ((Number)value).doubleValue());
                        }
                    }
                    if (showAvg) {
                        Object value = feature.getAttribute("mean");
                        if (value != null) {
                            Data.storeNum(attributeNameMap.get("mean"), stataObs, 
                                        ((Number)value).doubleValue());
                        }
                    }
                    if (showMin) {
                        Object value = feature.getAttribute("min");
                        if (value != null) {
                            Data.storeNum(attributeNameMap.get("min"), stataObs, 
                                        ((Number)value).doubleValue());
                        }
                    }
                    if (showMax) {
                        Object value = feature.getAttribute("max");
                        if (value != null) {
                            Data.storeNum(attributeNameMap.get("max"), stataObs, 
                                        ((Number)value).doubleValue());
                        }
                    }
                    if (showStd) {
                        Object value = feature.getAttribute("stddev");
                        if (value != null) {
                            Data.storeNum(attributeNameMap.get("stddev"), stataObs, 
                                        ((Number)value).doubleValue());
                        }
                    }
                    if (showSum) {
                        Object value = feature.getAttribute("sum");
                        if (value != null) {
                            Data.storeNum(attributeNameMap.get("sum"), stataObs, 
                                        ((Number)value).doubleValue());
                        }
                    }
                }
                
                System.out.println("Data successfully exported to Stata");
            }
            
        } catch (Exception e) {
            System.out.println("Error: " + e.getMessage());
            e.printStackTrace();
        } finally {
            if (featureIterator != null) featureIterator.close();
            if (shapefileDataStore != null) shapefileDataStore.dispose();
            System.gc();
        }
    }
}

end