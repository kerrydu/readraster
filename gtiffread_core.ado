
cap program drop gtiffread_core
program define gtiffread_core
version 17
syntax anything, [CRScode(string) band(real 1) origin(numlist min=2 max=2 integer >0) size(numlist min=2 max=2 integer)  clear]
greadvalue `0'
    
end 
////////////////////////////////////////


cap program drop greadvalue
program define greadvalue
version 17
syntax anything, [CRScode(string) band(real 1) origin(numlist min=2 max=2 integer >0) size(numlist min=2 max=2 integer) clear]

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

removequotes, file(`using')
local using = usubinstr(`"`using'"',"\","/",.)
if !strmatch("`using'", "*:/*") & !strmatch("`using'", "/*") {
    local using = "`c(pwd)'/`using'"
}
local using = usubinstr(`"`using'"',"\","/",.)

if "`crscode'" == "" {
    local crscode "None" // Default to "None" if not provided
}

//// 处理 crscode 参数
if strpos(lower("`crscode'"), ".tif") | strpos(lower("`crscode'"), ".shp") {
    removequotes, file(`crscode')
    local crscode `r(file)'
    local crscode = subinstr("`crscode'", "\", "/", .)
    if !strmatch("`crscode'", "*:\\*") & !strmatch("`crscode'", "/*") {
        local crscode = "`c(pwd)'/`crscode'"
    }
    local crscode = subinstr("`crscode'", "\", "/", .)
}



//初始化 Stata 数据结构
qui {
    gen double x = .
    gen double y = .
    gen double value = .
}

if "`origin'" == "" {
    java: GeoTiff.exportToStata("`using'", `band', "`crscode'", 0, -1, 0, -1)
} 
else {
    local startRow: word 1 of `origin'
    local startCol: word 2 of `origin'
    local startCol = `startCol' - 1
    local startRow = `startRow' - 1

    if "`size'" == "" {
        local endRow -1
        local endCol -1
    } 
    else {
        local endRow: word 1 of `size'
        local endCol: word 2 of `size'
        local endRow = `endRow' + `startRow'
        local endCol = `endCol' + `startCol'
    }

    java: GeoTiff.exportToStata("`using'", `band', "`crscode'", `startRow', `endRow', `startCol', `endCol')
}

// 添加标签和注释
label variable x "GeoTiff X Coordinate"
label variable y "GeoTiff Y Coordinate"
label variable value "Pixel Value (Band `band')"

end

cap program drop removequotes
program define removequotes,rclass
    version 16
    syntax, file(string) 
    return local file `file'
end

////////////////////////////////////////

java:
// GeoTiffToStataExporter.java
/cp gt-metadata-34.0.jar
/cp gt-api-34.0.jar
/cp gt-main-34.0.jar
/cp gt-referencing-34.0.jar
/cp gt-epsg-hsql-34.0.jar
/cp gt-epsg-extension-34.0.jar
/cp gt-geotiff-34.0.jar
/cp gt-coverage-34.0.jar
/cp gt-process-raster-34.0.jar
/cp gt-shapefile-34.0.jar
/cp json-simple-1.1.1.jar
/cp commons-lang3-3.18.0.jar
/cp commons-io-2.19.0.jar
/cp jts-core-1.20.0.jar



import com.stata.sfi.*;
import org.geotools.coverage.grid.GridCoverage2D;
import org.geotools.coverage.grid.GridGeometry2D;
import org.geotools.gce.geotiff.GeoTiffReader;
import org.geotools.api.referencing.operation.MathTransform;
import org.geotools.referencing.CRS;
// Add the missing import for TransformException
import org.geotools.api.referencing.operation.TransformException;
import org.geotools.geometry.Position2D;
import org.geotools.coverage.grid.GridCoordinates2D;
// 在import部分添加以下两行
import org.geotools.coverage.GridSampleDimension;
import org.geotools.api.coverage.SampleDimension;
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
import com.stata.sfi.Data;
import com.stata.sfi.SFIToolkit;





public class GeoTiff {

    private static final int BLOCK_SIZE = 100_000;
    private static final int MAX_OBS = 1_000_000_000;

    public static void exportToStata(String geotiffPath, int bandIndex,
                                    String targetEpsg, 
                                    int startRow, int endRow,
                                    int startCol, int endCol) throws Exception {
        

        GeoTiffReader reader = null;
        try {
            reader = new GeoTiffReader(new File(geotiffPath));
            
            // Define the read bounds based on the input parameters
            GridCoverage2D coverage = reader.read((org.geotools.api.parameter.GeneralParameterValue[]) null);
            Raster raster = coverage.getRenderedImage().getData();
            int rasterHeight = raster.getHeight();
            int rasterWidth = raster.getWidth();

            // Adjust endRow and endCol if they are -1 (read to the end)
            if (endRow == -1) endRow = rasterHeight - 1;
            if (endCol == -1) endCol = rasterWidth - 1;

            // Validate coordinates
            validateCoordinates(raster, startRow, endRow, startCol, endCol);
            validateBand(coverage, raster, bandIndex - 1);

            // Calculate the subset bounds
            int subsetWidth = endCol - startCol ;
            int subsetHeight = endRow - startRow ;

            // Create a sub-raster for the specified bounds
            Raster subRaster = raster.createChild(
                startCol, startRow, subsetWidth, subsetHeight, 
                0, 0, null
            );

            // Calculate total observations
            long totalObs = calculateTotalObs(0, subsetHeight - 1, 0, subsetWidth - 1);
            if (totalObs > MAX_OBS) {
                SFIToolkit.errorln("Reading too many observations");
                return;
            }
            Data.setObsTotal(totalObs);

            // Process the sub-raster directly
            processBlocks(subRaster, bandIndex - 1, coverage.getGridGeometry(),
                         getNoDataValue(coverage, bandIndex),
                         createTransform(coverage, targetEpsg),
                         0, subsetHeight - 1, 0, subsetWidth - 1,
                         startRow, startCol);

        } catch (Exception e) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
            throw new RuntimeException(e);
        } finally {
            if (reader != null) {
                try { reader.dispose(); } 
                catch (Exception e) { 
                    SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
                }
            }
        }
    }

    private static void processBlocks(Raster raster, int bandIndex,
                                    GridGeometry2D gridGeometry,
                                    double noData, MathTransform transform,
                                    int startRow, int endRow,
                                    int startCol, int endCol,
                                    int originalStartRow, int originalStartCol) {
        int currentObs = 1;
        try {
            CRS.reset("all");
            for (int y = startRow; y <= endRow; y++) {
                for (int x = startCol; x <= endCol; x++) {
                    int originalX = originalStartCol + x;
                    int originalY = originalStartRow + y;

                    double value = raster.getSampleDouble(x, y, bandIndex);
                    if (isNoData(value, noData)) continue;

                    Position2D pos = convertCoordinate(gridGeometry, originalX, originalY, transform);
                    Data.storeNum(1, currentObs, pos.getX());
                    Data.storeNum(2, currentObs, pos.getY());
                    Data.storeNum(3, currentObs, value);
                    currentObs++;
                }
            }
            Data.updateModified();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static Position2D convertCoordinate(GridGeometry2D gridGeometry,
                                              int x, int y,
                                              MathTransform transform)
        throws TransformException {
        Position2D pos = new Position2D();
        pos.setLocation(gridGeometry.gridToWorld(new GridCoordinates2D(x, y)));
        
        if (transform != null) {
            double[] src = {pos.getX(), pos.getY()};
            double[] dst = new double[2];
            transform.transform(src, 0, dst, 0, 1);
            pos.setLocation(dst[0], dst[1]);
        }
        return pos;
    }

    // 必要工具方法
    // 修正后的正确写法
    private static void validateCoordinates(Raster raster, 
                                        int startRow, int endRow,
                                        int startCol, int endCol) {
        int maxRow = raster.getHeight() - 1;
        int maxCol = raster.getWidth() - 1;
        

        if(startRow > maxRow ){
            SFIToolkit.displayln("startRow: " + startRow + ", startCol: " + startCol + ", endRow: " + endRow + ", endCol: " + endCol);
            // 打印 maxRow, maxCol
            SFIToolkit.displayln("maxRow: " + maxRow + ", maxCol: " + maxCol);
            SFIToolkit.errorln("Starting Coordinates are out of range: startRow>" + maxRow);
        }
        if(startCol > maxCol ){
            SFIToolkit.displayln("startRow: " + startRow + ", startCol: " + startCol + ", endRow: " + endRow + ", endCol: " + endCol);
            // 打印 maxRow, maxCol
            SFIToolkit.displayln("maxRow: " + maxRow + ", maxCol: " + maxCol);
            SFIToolkit.errorln("Starting Coordinates are out of range: startCol>" + maxCol);
        }
        
        if (endRow > maxRow || endCol > maxCol) {
            SFIToolkit.errorln("Ending Coordinates are out of range");
            SFIToolkit.errorln("Maximum range: " + raster.getHeight() + "x" + raster.getWidth());
            throw new IllegalArgumentException(
                String.format(
                    "Coordinates are out of range (maximum range: %dx%d)", 
                    raster.getHeight(), 
                    raster.getWidth() // 正确闭合括号
                ) // 结束String.format参数
            ); // 结束throw语句
        }
    }

    private static long calculateTotalObs(int startRow, int endRow, 
                                        int startCol, int endCol) {
        return (long)(endRow - startRow + 1) * (endCol - startCol + 1);
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
            throw new IllegalArgumentException("Invalid CRS input: " + crsInput + 
                                               ". Must be an EPSG code, GeoTIFF, or Shapefile.");
        }

        return CRS.findMathTransform(coverage.getCoordinateReferenceSystem(), targetCRS);
    }

private static double getNoDataValue(GridCoverage2D coverage, int bandIndex) {
    GridSampleDimension sampleDim = coverage.getSampleDimension(bandIndex-1);
    double[] noDataValues = sampleDim.getNoDataValues();
    
    // 添加空值保护
    if (noDataValues == null || noDataValues.length == 0) {
        // SFIToolkit.displayln("WARNING: NoData value not found for band " + bandIndex);
        return Double.NaN; // 返回标准NaN值
    }
    return noDataValues[0];
}

// 修改数值判断逻辑
private static boolean isNoData(double value, double noData) {
    // 处理NaN情况
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
        
        // 新增元数据检查
        GridSampleDimension sampleDim = coverage.getSampleDimension(bandIndex);
        // if (sampleDim.getNoDataValues() == null) {
        //     SFIToolkit.displayln("Notice: Band " + (bandIndex+1) + " has no NoData value defined");
 }


    // 新增 parseCRS 方法
    private static CoordinateReferenceSystem parseCRS(String crsInput) throws Exception {
        try {
            if (crsInput.toLowerCase().endsWith(".tif")) {
                return readCRSFromGeoTIFF(crsInput);
            } else if (crsInput.toLowerCase().endsWith(".shp")) {
                return readCRSFromShapefile(crsInput);
            } else if (crsInput.startsWith("EPSG:")) {
                return CRS.decode(crsInput, true);
            } else {
                return CRS.parseWKT(crsInput);
            }
        } catch (Exception e) {
            throw new Exception("Failed to parse CRS from input: " + crsInput + ". Error: " + e.getMessage(), e);
        }
    }

    // 新增 readCRSFromGeoTIFF 方法
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

    // 新增 readCRSFromShapefile 方法
    private static CoordinateReferenceSystem readCRSFromShapefile(String filePath) throws Exception {
        ShapefileDataStore shapefileDataStore = null;
        try {
            File shpFile = new File(filePath);
            if (!shpFile.exists()) {
                throw new Exception("Shapefile does not exist: " + filePath);
            }

            String basePath = filePath.substring(0, filePath.lastIndexOf("."));
            File shxFile = new File(basePath + ".shx");
            File dbfFile = new File(basePath + ".dbf");
            File prjFile = new File(basePath + ".prj");

            if (!shxFile.exists() || !dbfFile.exists()) {
                throw new Exception("Incomplete shapefile: " + filePath);
            }

            ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
            Map<String, Object> shpParams = new HashMap<>();
            shpParams.put("url", shpFile.toURI().toURL());
            shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);

            shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));
            CoordinateReferenceSystem crs = shapefileDataStore.getSchema().getCoordinateReferenceSystem();

            if (crs == null) {
                throw new Exception("CRS is null for Shapefile: " + filePath);
            }

            return crs;
        } finally {
            if (shapefileDataStore != null) {
                shapefileDataStore.dispose();
            }
        }
    }
}

end