
cap program drop gtiffdisp_core
program define gtiffdisp_core,rclass
version 17

syntax anything,[*]

if "`options'"!=""{
    di as error `"Invalid option ignored: `options'"'
}

local using `anything'

removequotes,file(`using')

local using = usubinstr(`"`using'"',"\","/",.)
// 判断路径是否为绝对路径
if !strmatch("`using'", "*:/*") & !strmatch("`using'", "/*") {
    // 如果是相对路径，拼接当前工作目录
    local using = "`c(pwd)'/`using'"
}
local using = usubinstr(`"`using'"',"\","/",.)

local rc = fileexists("`using'")
if `rc'==0{
	di as error `"`using'" NOT found'
	exit
}


java: GtiffReader.info("`using'")

/* ///bands、width、height、minX、minY、xRes 和 yRes
return scalar nband = bands
return scalar ncol = width
return scalar nrow = height
return scalar minX = minX
return scalar minY = minY
return scalar Xcellsize = xRes
return scalar Ycellsize = yRes */

end

////////////////////////


cap program drop removequotes
program define removequotes,rclass
    version 16
    syntax, file(string) 
    return local file `file'
end

////////////////////


java:

/cp gt-main-34.0.jar
/cp gt-referencing-34.0.jar
/cp gt-epsg-hsql-34.0.jar
/cp gt-epsg-extension-34.0.jar
/cp gt-geotiff-34.0.jar
/cp gt-coverage-34.0.jar
/cp gt-process-raster-34.0.jar


import org.geotools.api.coverage.grid.GridCoverage;
import org.geotools.api.geometry.Bounds;
import org.geotools.api.parameter.GeneralParameterValue;
import org.geotools.api.referencing.crs.CoordinateReferenceSystem;
import org.geotools.coverage.GridSampleDimension;
import org.geotools.coverage.grid.GridCoverage2D;
import org.geotools.coverage.grid.io.GridCoverage2DReader;
import org.geotools.gce.geotiff.GeoTiffReader;
import org.geotools.referencing.CRS;
import org.geotools.util.factory.Hints;
import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import com.stata.sfi.Scalar;

public class GtiffReader {
    public static void info(String filePath) {
        //String filePath = "E:/qwc_working/SynologyDrive/气候变化_电力消费/灯光数据处理/data/light/DMSP-like2019.tif";
        
        readGeoTiffMetadata(filePath);
    }

    public static void readGeoTiffMetadata(String filePath) {
        File file = new File(filePath);
        if (!file.exists()) {
            System.err.println("File does not exist: " + filePath);
            return;
        }

        GridCoverage2DReader reader = null;
        try {
            // 1. Read with axis order handling
            reader = new GeoTiffReader(file, new Hints(
                Hints.FORCE_LONGITUDE_FIRST_AXIS_ORDER, 
                Boolean.TRUE  // Set FALSE if coordinates look incorrect
            ));
            
            GridCoverage2D coverage = (GridCoverage2D) reader.read((GeneralParameterValue[]) null);
            
            // // 2. Band information
            // GridSampleDimension[] bands = coverage.getSampleDimensions();
            // System.out.println("\n=== Band Information ===");
            // System.out.println("Number of bands: " + bands.length);
            // Scalar.setValue("bands", bands.length);

            // for (int i = 0; i < bands.length; i++) {
            //     System.out.printf("Band %d: %s%n", i+1, bands[i].getDescription().toString());
            // }
 
        // 2. Band information
        GridSampleDimension[] bands = coverage.getSampleDimensions();
        System.out.println("\n=== Band Information ===");
        System.out.println("Number of bands: " + bands.length);
        Scalar.setValue("bands", bands.length);
        

        for (int i = 0; i < bands.length; i++) {
            // 获取NoData值
            double[] noDataValues = bands[i].getNoDataValues();
            String noDataInfo = "NoData: ";
            
            if (noDataValues != null && noDataValues.length > 0) {
                // 处理多NoData值情况
                if (noDataValues.length > 1) {
                    noDataInfo += Arrays.toString(noDataValues);
                } else {
                    // 智能格式化输出
                    if (noDataValues[0] == (int)noDataValues[0]) {
                        noDataInfo += String.format("%d", (int)noDataValues[0]);
                    } else {
                        noDataInfo += String.format("%.4f", noDataValues[0]);
                    }
                }
            } else {
                noDataInfo += "Not defined";
            }
    
            // 清理描述文本并输出
            String cleanDescription = bands[i].getDescription().toString()
                .replaceAll("[\\[\\]]", "") // 移除方括号
                .replaceAll("^\\s+", "");   // 移除前导空格
            
            System.out.printf("Band %-2d: %-20s | %s%n", 
                i+1, 
                (cleanDescription.length() > 20 ? 
                    cleanDescription.substring(0, 17) + "..." : // 截断长描述
                    cleanDescription),
                noDataInfo
            );
        }           

            // 3. Spatial extent & resolution
            Bounds envelope = coverage.getEnvelope();
            double minX = envelope.getMinimum(0);
            double maxX = envelope.getMaximum(0);
            double minY = envelope.getMinimum(1);
            double maxY = envelope.getMaximum(1);
            
            int width = coverage.getRenderedImage().getWidth();
            int height = coverage.getRenderedImage().getHeight();
            double xRes = (maxX - minX) / width;
            double yRes = (maxY - minY) / height;

            
            System.out.println("\n=== Spatial Characteristics ===");
            System.out.printf("X range: [%.4f ~ %.4f]%n", minX, maxX);
            System.out.printf("Y range: [%.4f ~ %.4f]%n", minY, maxY);
            System.out.printf("Resolution: X=%.4f units/pixel, Y=%.4f units/pixel%n", xRes, yRes);
            Scalar.setValue("width", width);
            Scalar.setValue("height", height);
            Scalar.setValue("xRes", xRes);
            Scalar.setValue("yRes", yRes);
            Scalar.setValue("minX", minX);
            Scalar.setValue("minY", minY);
            Scalar.setValue("maxX", maxX);
            Scalar.setValue("maxY", maxY);


            // 4. Coordinate system verification
            CoordinateReferenceSystem crs = coverage.getCoordinateReferenceSystem();
            System.out.println("\n=== Coordinate System ===");
            System.out.println("CRS Name: " + CRS.toSRS(crs));
            System.out.println("CRS WKT: " + crs.toWKT());  // Full projection parameters
            
            // 5. Unit verification
            System.out.println("\n=== Units ===");
            System.out.println("X unit: " + crs.getCoordinateSystem().getAxis(0).getUnit());
            System.out.println("Y unit: " + crs.getCoordinateSystem().getAxis(1).getUnit());

            // 6. Filtered metadata
            System.out.println("\n=== Filtered Metadata ===");
            Set<String> excludeKeys = new HashSet<>(Arrays.asList(
                "tile_cache_key", "tile_cache", 
                "JAI.ImageReader", "JAI.ImageReadParam", "PamDataset"
            ));
            
            for (String key : coverage.getPropertyNames()) {
                if (!excludeKeys.contains(key)) {
                    Object value = coverage.getProperty(key);
                    if (value != null) {
                        String valStr = value.toString();
                        valStr = valStr.length() > 50 ? 
                            valStr.substring(0, 47) + "..." : valStr;
                        System.out.printf("%-28s: %s%n", key, valStr);
                    }
                }
            }

        } catch (IOException e) {
            System.err.println("File read error: " + e.getMessage());
        } finally {
            // 7. Proper resource closure
            if (reader != null) {
                try {
                    reader.dispose();  // Correct disposal method
                } catch (IOException e) {
                    System.err.println("Error closing reader: " + e.getMessage());
                }
            }
        }
    }
}




end
