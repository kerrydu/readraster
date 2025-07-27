cap program drop gtiffread2
program define gtiffread2
version 18.0
syntax anything, SHPfile(string) [CRScode(string) band(real 1) IDfield(string) NAMEfield(string) clear]

// 调用核心函数
gtiffread2_core `0'

end

////////////////////////////////////////

cap program drop gtiffread2_core
program define gtiffread2_core
version 18.0
syntax anything, SHPfile(string) [CRScode(string) band(real 1) IDfield(string) NAMEfield(string) clear]

// 参数处理逻辑
if "`clear'" != "clear" {
    qui describe
    if r(N) > 0 | r(k) > 0 {
        di as error "Data already in memory, use the clear option to overwrite"
        exit 198
    }
} 
else {
    clear
}

local using `anything'

// 处理文件路径
removequotes, file(`using')
local using = usubinstr(`"`using'"',"\","/",.)
if !strmatch("`using'", "*:/*") & !strmatch("`using'", "/*") {
    local using = "`c(pwd)'/`using'"
}
local using = usubinstr(`"`using'"',"\","/",.)

// 处理shp文件路径
removequotes, file(`shpfile')
local shpfile = usubinstr(`"`shpfile'"',"\","/",.)
if !strmatch("`shpfile'", "*:/*") & !strmatch("`shpfile'", "/*") {
    local shpfile = "`c(pwd)'/`shpfile'"
}
local shpfile = usubinstr(`"`shpfile'"',"\","/",.)

// 检查文件是否存在
if !fileexists("`using'") {
    di as error "GeoTIFF file `using' not found"
    exit 601
}
if !fileexists("`shpfile'") {
    di as error "Shapefile `shpfile' not found"
    exit 601
}

if "`crscode'" == "" {
    local crscode "None"
}

// 处理 crscode 参数
if strpos(lower("`crscode'"), ".tif") | strpos(lower("`crscode'"), ".shp") {
    removequotes, file(`crscode')
    local crscode `r(file)'
    local crscode = subinstr("`crscode'", "\", "/", .)
    if !strmatch("`crscode'", "*:\\*") & !strmatch("`crscode'", "/*") {
        local crscode = "`c(pwd)'/`crscode'"
    }
    local crscode = subinstr("`crscode'", "\", "/", .)
}

// 设置默认字段名
if "`idfield'" == "" {
    local idfield "ID"
}
if "`namefield'" == "" {
    local namefield "NAME"
}

// 初始化 Stata 数据结构
qui {
    gen double x = .
    gen double y = .
    gen double value = .
    gen str50 region_id = ""
    gen str100 region_name = ""
}

// 调用Java函数按区域读取栅格
java: GeoTiffRegionReader.readByRegions("`using'", `band', "`crscode'", "`shpfile'", "`idfield'", "`namefield'")

// 添加标签和注释
label variable x "GeoTiff X Coordinate"
label variable y "GeoTiff Y Coordinate" 
label variable value "Pixel Value (Band `band')"
label variable region_id "Administrative Region ID"
label variable region_name "Administrative Region Name"

// 显示结果摘要
qui count
local total_obs = r(N)
qui count if region_id != ""
local matched_obs = r(N)

di as text "Raster reading completed:"
di as text "  Total observations: " as result `total_obs'
di as text "  Regions processed: " as result `matched_obs'

end

////////////////////////////////////////

java:
// 继承之前的import语句，并添加新的import
import com.stata.sfi.*;
import org.geotools.coverage.grid.GridCoverage2D;
import org.geotools.coverage.grid.GridGeometry2D;
import org.geotools.gce.geotiff.GeoTiffReader;
import org.geotools.api.referencing.operation.MathTransform;
import org.geotools.referencing.CRS;
import org.geotools.api.referencing.operation.TransformException;
import org.geotools.geometry.Position2D;
import org.geotools.coverage.grid.GridCoordinates2D;
import org.geotools.coverage.GridSampleDimension;
import java.awt.image.Raster;
import java.io.File;
import org.geotools.data.shapefile.ShapefileDataStore;
import org.geotools.api.referencing.crs.CoordinateReferenceSystem;
import org.geotools.data.shapefile.ShapefileDataStoreFactory;
import org.geotools.geometry.jts.JTS;
import org.geotools.geometry.jts.JTSFactoryFinder;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Envelope;
import com.stata.sfi.Data;
import com.stata.sfi.SFIToolkit;

// Shapefile处理相关imports
import org.geotools.data.simple.SimpleFeatureSource;
import org.geotools.data.simple.SimpleFeatureCollection;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.api.feature.simple.SimpleFeature;
import org.geotools.api.feature.type.AttributeDescriptor;
import org.locationtech.jts.geom.prep.PreparedGeometry;
import org.locationtech.jts.geom.prep.PreparedGeometryFactory;
import java.util.*;

public class GeoTiffRegionReader {

    private static final int MAX_OBS = 1_000_000_000;

    public static void readByRegions(String geotiffPath, int bandIndex,
                                   String targetEpsg, String shapefilePath,
                                   String idField, String nameField) throws Exception {
        
        GeoTiffReader reader = null;
        ShapefileDataStore shapefileDataStore = null;
        SimpleFeatureIterator features = null;
        
        try {
            // 打开GeoTIFF
            reader = new GeoTiffReader(new File(geotiffPath));
            GridCoverage2D coverage = reader.read(null);
            
            // 验证波段
            Raster raster = coverage.getRenderedImage().getData();
            validateBand(coverage, raster, bandIndex - 1);
            
            // 获取NoData值
            double noData = getNoDataValue(coverage, bandIndex);
            
            // 创建坐标变换
            MathTransform transform = createTransform(coverage, targetEpsg);
            
            // 加载Shapefile
            shapefileDataStore = loadShapefile(shapefilePath);
            SimpleFeatureSource featureSource = shapefileDataStore.getFeatureSource();
            SimpleFeatureCollection featureCollection = featureSource.getFeatures();
            
            // 检查字段是否存在
            boolean hasIdField = hasAttribute(featureSource, idField);
            boolean hasNameField = hasAttribute(featureSource, nameField);
            
            if (!hasIdField) {
                SFIToolkit.displayln("Warning: ID field '" + idField + "' not found. Using FID instead.");
            }
            if (!hasNameField) {
                SFIToolkit.displayln("Warning: Name field '" + nameField + "' not found. Using empty string.");
            }

            // 创建坐标变换（shapefile到raster）
            CoordinateReferenceSystem shapeCRS = featureSource.getSchema().getCoordinateReferenceSystem();
            CoordinateReferenceSystem rasterCRS = coverage.getCoordinateReferenceSystem();
            MathTransform shapeToRaster = null;
            
            if (shapeCRS != null && !CRS.equalsIgnoreMetadata(shapeCRS, rasterCRS)) {
                shapeToRaster = CRS.findMathTransform(shapeCRS, rasterCRS, true);
            }

            // 估算总观测数
            long estimatedObs = estimateTotalObservations(featureCollection, coverage, shapeToRaster);
            if (estimatedObs > MAX_OBS) {
                SFIToolkit.errorln("Estimated observations exceed maximum limit: " + estimatedObs);
                return;
            }
            Data.setObsTotal(estimatedObs);

            // 逐个处理每个行政区域
            features = featureCollection.features();
            int currentObs = 1;
            int regionCount = 0;
            
            while (features.hasNext()) {
                SimpleFeature feature = features.next();
                Geometry geometry = (Geometry) feature.getDefaultGeometry();
                
                if (geometry != null) {
                    // 获取区域信息
                    String id = hasIdField ? getAttributeAsString(feature, idField) : feature.getID();
                    String name = hasNameField ? getAttributeAsString(feature, nameField) : "";
                    
                    // 变换几何体到栅格坐标系
                    if (shapeToRaster != null) {
                        geometry = JTS.transform(geometry, shapeToRaster);
                    }
                    
                    // 处理该区域
                    currentObs = processRegion(coverage, geometry, id, name, bandIndex - 1, 
                                             noData, transform, currentObs);
                    regionCount++;
                }
            }
            
            Data.updateModified();
            SFIToolkit.displayln("Processed " + regionCount + " regions, " + (currentObs - 1) + " observations");
            
        } catch (Exception e) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
            throw new RuntimeException(e);
        } finally {
            if (features != null) features.close();
            if (reader != null) reader.dispose();
            if (shapefileDataStore != null) shapefileDataStore.dispose();
        }
    }

    private static int processRegion(GridCoverage2D coverage, Geometry geometry, 
                                   String regionId, String regionName,
                                   int bandIndex, double noData, 
                                   MathTransform transform, int startObs) throws Exception {
        
        // 获取几何体的边界框
        Envelope envelope = geometry.getEnvelopeInternal();
        
        // 将地理坐标转换为栅格坐标
        GridGeometry2D gridGeometry = coverage.getGridGeometry();
        Position2D minPos = new Position2D(envelope.getMinX(), envelope.getMinY());
        Position2D maxPos = new Position2D(envelope.getMaxX(), envelope.getMaxY());
        
        GridCoordinates2D minGrid = gridGeometry.worldToGrid(minPos);
        GridCoordinates2D maxGrid = gridGeometry.worldToGrid(maxPos);
        
        // 获取栅格数据
        Raster raster = coverage.getRenderedImage().getData();
        int rasterHeight = raster.getHeight();
        int rasterWidth = raster.getWidth();
        
        // 调整边界到栅格范围内
        int startRow = Math.max(0, Math.min(minGrid.y, maxGrid.y));
        int endRow = Math.min(rasterHeight - 1, Math.max(minGrid.y, maxGrid.y));
        int startCol = Math.max(0, Math.min(minGrid.x, maxGrid.x));
        int endCol = Math.min(rasterWidth - 1, Math.max(minGrid.x, maxGrid.x));
        
        // 创建几何体的准备版本用于高效的空间查询
        PreparedGeometry preparedGeometry = PreparedGeometryFactory.prepare(geometry);
        GeometryFactory geometryFactory = JTSFactoryFinder.getGeometryFactory();
        
        int currentObs = startObs;
        
        // 遍历边界框内的所有像素
        for (int row = startRow; row <= endRow; row++) {
            for (int col = startCol; col <= endCol; col++) {
                double value = raster.getSampleDouble(col, row, bandIndex);
                if (isNoData(value, noData)) continue;
                
                // 将栅格坐标转换为地理坐标
                Position2D pos = new Position2D();
                pos.setLocation(gridGeometry.gridToWorld(new GridCoordinates2D(col, row)));
                
                // 检查点是否在几何体内
                Point point = geometryFactory.createPoint(new Coordinate(pos.getX(), pos.getY()));
                if (preparedGeometry.contains(point)) {
                    // 应用坐标变换（如果需要）
                    if (transform != null) {
                        double[] src = {pos.getX(), pos.getY()};
                        double[] dst = new double[2];
                        transform.transform(src, 0, dst, 0, 1);
                        pos.setLocation(dst[0], dst[1]);
                    }
                    
                    // 存储到Stata
                    Data.storeNum(1, currentObs, pos.getX());
                    Data.storeNum(2, currentObs, pos.getY());
                    Data.storeNum(3, currentObs, value);
                    Data.storeStr(4, currentObs, regionId);
                    Data.storeStr(5, currentObs, regionName);
                    currentObs++;
                }
            }
        }
        
        return currentObs;
    }

    private static long estimateTotalObservations(SimpleFeatureCollection featureCollection,
                                                GridCoverage2D coverage,
                                                MathTransform shapeToRaster) throws Exception {
        // 简单估算：计算所有区域边界框的总面积
        SimpleFeatureIterator iterator = featureCollection.features();
        long totalEstimate = 0;
        
        try {
            GridGeometry2D gridGeometry = coverage.getGridGeometry();
            Raster raster = coverage.getRenderedImage().getData();
            
            while (iterator.hasNext()) {
                SimpleFeature feature = iterator.next();
                Geometry geometry = (Geometry) feature.getDefaultGeometry();
                
                if (geometry != null) {
                    if (shapeToRaster != null) {
                        geometry = JTS.transform(geometry, shapeToRaster);
                    }
                    
                    Envelope envelope = geometry.getEnvelopeInternal();
                    Position2D minPos = new Position2D(envelope.getMinX(), envelope.getMinY());
                    Position2D maxPos = new Position2D(envelope.getMaxX(), envelope.getMaxY());
                    
                    GridCoordinates2D minGrid = gridGeometry.worldToGrid(minPos);
                    GridCoordinates2D maxGrid = gridGeometry.worldToGrid(maxPos);
                    
                    int rows = Math.abs(maxGrid.y - minGrid.y) + 1;
                    int cols = Math.abs(maxGrid.x - minGrid.x) + 1;
                    
                    totalEstimate += (long) rows * cols;
                }
            }
        } finally {
            iterator.close();
        }
        
        // 考虑到不是所有像素都在多边形内，估算一个较小的值
        return Math.min(totalEstimate / 2, MAX_OBS);
    }

    // 辅助方法 - 重用之前的方法
    private static ShapefileDataStore loadShapefile(String shapefilePath) throws Exception {
        File shpFile = new File(shapefilePath);
        ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
        Map<String, Object> params = new HashMap<>();
        params.put("url", shpFile.toURI().toURL());
        ShapefileDataStore dataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(params);
        dataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));
        return dataStore;
    }

    private static boolean hasAttribute(SimpleFeatureSource featureSource, String attributeName) {
        for (AttributeDescriptor descriptor : featureSource.getSchema().getAttributeDescriptors()) {
            if (descriptor.getLocalName().equalsIgnoreCase(attributeName)) {
                return true;
            }
        }
        return false;
    }

    private static String getAttributeAsString(SimpleFeature feature, String attributeName) {
        Object value = feature.getAttribute(attributeName);
        return value != null ? value.toString() : "";
    }

    private static MathTransform createTransform(GridCoverage2D coverage, String crsInput) 
        throws Exception {
        if ("None".equalsIgnoreCase(crsInput)) return null;

        CoordinateReferenceSystem targetCRS;
        if (crsInput.toLowerCase().endsWith(".tif")) {
            targetCRS = readCRSFromGeoTIFF(crsInput);
        } else if (crsInput.toLowerCase().endsWith(".shp")) {
            targetCRS = readCRSFromShapefile(crsInput);
        } else if (crsInput.startsWith("EPSG:")) {
            targetCRS = CRS.decode(crsInput, true);
        } else {
            throw new IllegalArgumentException("Invalid CRS input: " + crsInput);
        }

        return CRS.findMathTransform(coverage.getCoordinateReferenceSystem(), targetCRS);
    }

    private static double getNoDataValue(GridCoverage2D coverage, int bandIndex) {
        GridSampleDimension sampleDim = coverage.getSampleDimension(bandIndex-1);
        double[] noDataValues = sampleDim.getNoDataValues();
        
        if (noDataValues == null || noDataValues.length == 0) {
            return Double.NaN;
        }
        return noDataValues[0];
    }

    private static boolean isNoData(double value, double noData) {
        if (Double.isNaN(noData)) {
            return Double.isNaN(value);
        }
        return (Math.abs(value - noData) < 1e-9);
    }

    private static void validateBand(GridCoverage2D coverage, Raster raster, int bandIndex) {
        if (bandIndex < 0 || bandIndex >= raster.getNumBands()) {
            throw new IllegalArgumentException("Invalid band index: " + bandIndex 
                + " (Total bands: " + raster.getNumBands() + ")");
        }
    }

    private static CoordinateReferenceSystem readCRSFromGeoTIFF(String filePath) throws Exception {
        GeoTiffReader reader = null;
        try {
            reader = new GeoTiffReader(new File(filePath));
            return reader.getCoordinateReferenceSystem();
        } finally {
            if (reader != null) {
                reader.dispose();
            }
        }
    }

    private static CoordinateReferenceSystem readCRSFromShapefile(String filePath) throws Exception {
        ShapefileDataStore shapefileDataStore = null;
        try {
            File shpFile = new File(filePath);
            ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
            Map<String, Object> shpParams = new HashMap<>();
            shpParams.put("url", shpFile.toURI().toURL());
            shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);
            return shapefileDataStore.getSchema().getCoordinateReferenceSystem();
        } finally {
            if (shapefileDataStore != null) {
                shapefileDataStore.dispose();
            }
        }
    }
}

end