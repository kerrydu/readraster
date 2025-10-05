
cap program drop crsconvert_core
program define crsconvert_core
version 18

syntax varlist(min=2 max=2 numeric), gen(string) from(string) to(string)

local x: word 1 of `varlist'
local y: word 2 of `varlist'

confirm new var `gen'`x'
confirm new var `gen'`y'

qui gen double `gen'`x' = .
qui gen double `gen'`y' = .

// 处理 from 和 to 参数的路径
local from `from'
local to `to'

if strpos(lower("`from'"), ".tif") | strpos(lower("`from'"), ".shp") {
    removequotes, file(`from')
    local from `r(file)'
    local from = subinstr("`from'", "\", "/", .)
     // 只对相对路径拼接 c(pwd)
     if !regexm("`from'", "^[A-Za-z]:/") & !strmatch("`from'", "/*") {
        local from = "`c(pwd)'/`from'"
    }
    local from = subinstr("`from'", "\", "/", .)
}

// 检查 to 是否是文件路径
if strpos(lower("`to'"), ".tif") | strpos(lower("`to'"), ".shp") {
    removequotes, file(`to')
    local to `r(file)'
    local to = subinstr("`to'", "\", "/", .)
     if !regexm("`to'", "^[A-Za-z]:/") & !strmatch("`to'", "/*") {
        local to = "`c(pwd)'/`to'"
    }
    local to = subinstr("`to'", "\", "/", .)
}

// 调用 Java 方法
java: crsconvert("`x'", "`y'", "`gen'`x'", "`gen'`y'", "`from'", "`to'")

end

cap program drop removequotes
program define removequotes,rclass
version 16
syntax, file(string) 
return local file `file'
end


java:


/cp gt-main-32.0.jar
/cp gt-referencing-32.0.jar
/cp gt-epsg-hsql-32.0.jar
/cp gt-epsg-extension-32.0.jar
/cp gt-geotiff-32.0.jar
/cp gt-coverage-32.0.jar
/cp gt-shapefile-32.0.jar
/cp gt-api-32.0.jar
/cp gt-metadata-32.0.jar

/cp json-simple-1.1.1.jar
/cp commons-lang3-3.15.0.jar
/cp commons-io-2.16.1.jar
/cp jts-core-1.20.0.jar



import org.geotools.api.referencing.crs.CoordinateReferenceSystem;
import org.geotools.api.referencing.operation.MathTransform;
import org.geotools.api.referencing.operation.TransformException;
import org.geotools.geometry.jts.JTS;
import org.geotools.geometry.jts.JTSFactoryFinder;
import org.geotools.referencing.CRS;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import com.stata.sfi.Data;
import com.stata.sfi.SFIToolkit;
import org.geotools.gce.geotiff.GeoTiffReader;
import org.geotools.coverage.grid.GridCoverage2D;
import org.geotools.data.shapefile.ShapefileDataStoreFactory;
import org.geotools.data.shapefile.ShapefileDataStore;
import java.util.logging.ConsoleHandler;
import java.util.logging.Handler;
import java.util.logging.Level;
import java.util.logging.Logger;

// Initialization method to replace the static block
void initializeGeoTools() {
    // Disable the JSON-related service loading at startup
    System.setProperty("org.geotools.referencing.forceXY", "true");
    System.setProperty("org.geotools.factory.hideLegacyServiceImplementations", "true");

    // Suppress specific service loader errors
    Logger logger = Logger.getLogger("org.geotools.util.factory");
    logger.setLevel(Level.SEVERE);

    // Suppress INFO level messages from GeoTools
    Logger geoToolsLogger = Logger.getLogger("org.geotools");
    geoToolsLogger.setLevel(Level.WARNING);
    for (Handler handler : geoToolsLogger.getHandlers()) {
        if (handler instanceof ConsoleHandler) {
            handler.setLevel(Level.WARNING);
        }
    }
}


void crsconvert(String x, String y, String newx, String newy, 
                            String sourceCRS, String targetCRS) {

    
    try {
        // Call the initialization method
        initializeGeoTools();

        // Reset CRS cache
        CRS.reset("all");

        // 判断 sourceCRS 和 targetCRS 的类型
        CoordinateReferenceSystem source = parseCRS(sourceCRS);
        CoordinateReferenceSystem target = parseCRS(targetCRS);

        // 打印转换信息
        System.out.println("Converting coordinates from CRS:");
        System.out.println("Source CRS: " + source.toString());
        System.out.println("Target CRS: " + target.toString());

        // 创建转换器
        MathTransform transform = CRS.findMathTransform(source, target, true);
        GeometryFactory geometryFactory = JTSFactoryFinder.getGeometryFactory();

        // 复用坐标对象
        Coordinate coord = new Coordinate();
        Point point = geometryFactory.createPoint(coord);

        // 获取变量索引
        int xIndex = Data.getVarIndex(x);
        int yIndex = Data.getVarIndex(y);
        int newxIndex = Data.getVarIndex(newx);
        int newyIndex = Data.getVarIndex(newy);
        Long TotalObs = Data.getObsTotal();

        // 转换循环
        for (int i = 1; i <= TotalObs; i++) {
            try {
                coord.x = Data.getNum(xIndex, i);
                coord.y = Data.getNum(yIndex, i);

                Geometry transformed = JTS.transform(point, transform);
                Coordinate result = transformed.getCoordinate();

                Data.storeNumFast(newxIndex, i, result.x);
                Data.storeNumFast(newyIndex, i, result.y);
            } catch (Exception e) {
                SFIToolkit.error("Error at obs " + i);
            }
        }
        Data.updateModified();
    } catch (Exception e) {
        SFIToolkit.error("Conversion failed: " + e.getMessage());
    }
}

// 修改后的 parseCRS 方法
CoordinateReferenceSystem parseCRS(String crsInput) throws Exception {
    try {
        // 如果输入是 GeoTIFF 文件
        if (crsInput.toLowerCase().endsWith(".tif")) {
            return readCRSFromGeoTIFF(crsInput);
        } 
        // 如果输入是 Shapefile 文件
        else if (crsInput.toLowerCase().endsWith(".shp")) {
            return readCRSFromShapefile(crsInput);
        } 
        // 如果输入是 EPSG 编码
        else if (crsInput.startsWith("EPSG:")) {
            return CRS.decode(crsInput, true); // 强制使用 XY 顺序
        } 
        // 假设输入是 WKT 字符串
        else {
            return CRS.parseWKT(crsInput);
        }
    } catch (Exception e) {
        throw new Exception("Failed to parse CRS from input: " + crsInput + ". Error: " + e.getMessage(), e);
    }
}


// 从 GeoTIFF 文件读取 CRS
CoordinateReferenceSystem readCRSFromGeoTIFF(String filePath) throws Exception {
    GeoTiffReader reader = null;
    try {
        reader = new GeoTiffReader(new File(filePath));
        return reader.getCoordinateReferenceSystem();
    } catch (Exception e) {
        throw new Exception("Failed to read CRS from GeoTIFF file: " + filePath + ". Error: " + e.getMessage(), e);
    } finally {
        if (reader != null) {
            reader.dispose(); // 确保释放资源
        }
    }
}

// 从 Shapefile 文件读取 CRS
CoordinateReferenceSystem readCRSFromShapefile(String filePath) throws Exception {
    ShapefileDataStore shapefileDataStore = null;
    try {
        File shpFile = new File(filePath);
        if (!shpFile.exists()) {
            throw new Exception("Shapefile does not exist: " + filePath);
        }

        // 检查 Shapefile 的必要组件
        String basePath = filePath.substring(0, filePath.lastIndexOf("."));
        File shxFile = new File(basePath + ".shx");
        File dbfFile = new File(basePath + ".dbf");
        File prjFile = new File(basePath + ".prj");

        /* if (!shxFile.exists() || !dbfFile.exists() || !prjFile.exists()) {
            throw new Exception("Missing required shapefile components (.shx, .dbf, or .prj): " + filePath);
        } */

                    if (!shxFile.exists() || !dbfFile.exists()) {
                System.out.println("Warning: Missing required shapefile components:");
                if (!shxFile.exists()) System.out.println(" - Missing .shx index file");
                if (!dbfFile.exists()) System.out.println(" - Missing .dbf attribute file");
                if (!prjFile.exists()) System.out.println(" - Missing .prj attribute file");
                System.out.println("A complete shapefile requires .shp, .shx, .dbf and .prj files.");
                throw new Exception("Incomplete shapefile: " + filePath);
            }

            ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
            Map<String, Object> shpParams = new HashMap<>();
            shpParams.put("url", shpFile.toURI().toURL());
            shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);

            // Set UTF-8 encoding explicitly
            /* shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8")); */
        CoordinateReferenceSystem crs = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
        /* System.out.println("PRJ file path: " + prjFile.getAbsolutePath()); */

        /* // 使用 ShapefileDataStore 解析 CRS
        Map<String, Object> params = new HashMap<>();
        params.put("url", shpFile.toURI().toURL());
        ShapefileDataStoreFactory factory = new ShapefileDataStoreFactory();
        shapefileDataStore = (ShapefileDataStore) factory.createDataStore(params);

        if (shapefileDataStore == null) {
            throw new Exception("Failed to create ShapefileDataStore for: " + filePath);
        }

        // 获取 CRS
        CoordinateReferenceSystem crs = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
if (crs == null) {
            throw new Exception("CRS is null for Shapefile: " + filePath);
        }*/

        return crs; 
    } catch (Exception e) {
        throw new Exception("Failed to read CRS from Shapefile: " + filePath + ". Error: " + e.getMessage(), e);
    } finally {
        if (shapefileDataStore != null) {
            shapefileDataStore.dispose(); // 确保释放资源
        }
    }
}

end