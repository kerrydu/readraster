cap program drop gtiffwrite_core
program define gtiffwrite_core
version 17
syntax anything, [xvar(varname) yvar(varname) valuevar(varname) crs(string) nodata(real -9999) resolution(numlist min=2 max=2) replace]

// 默认变量名
if "`xvar'" == "" local xvar "x"
if "`yvar'" == "" local yvar "y"
if "`valuevar'" == "" local valuevar "value"

// 检查变量存在
confirm variable `xvar' `yvar' `valuevar'

// 输出文件名
local outfile `anything'
if "`replace'" == "" {
    confirm new file "`outfile'"
}

// 默认 CRS
if "`crs'" == "" local crs "EPSG:4326"

// 分辨率
if "`resolution'" != "" {
    local xres: word 1 of `resolution'
    local yres: word 2 of `resolution'
} else {
    // 从数据推断分辨率
    qui su `xvar', meanonly
    local xmin = r(min)
    local xmax = r(max)
    qui su `yvar', meanonly
    local ymin = r(min)
    local ymax = r(max)
    // 假设规则网格，计算分辨率
    qui levelsof `xvar', local(xlevels)
    local nx: word count `xlevels'
    local xres = (`xmax' - `xmin') / (`nx' - 1)
    qui levelsof `yvar', local(ylevels)
    local ny: word count `ylevels'
    local yres = (`ymax' - `ymin') / (`ny' - 1)
}

// 调用 Java
java: StataToGeoTiff.exportToGeoTIFF("`outfile'", "`xvar'", "`yvar'", "`valuevar'", "`crs'", `nodata', `xres', `yres')

di "GeoTIFF written to `outfile'"

end

////////////////////////////////////////

java:
// StataToGeoTiffExporter.java

/cp jai_core-1.1.3.jar
/cp jai_imageio-1.1.jar
/cp gt-metadata-32.0.jar       
/cp gt-api-32.0.jar
/cp gt-main-32.0.jar
/cp gt-referencing-32.0.jar
/cp gt-epsg-hsql-32.0.jar
/cp gt-epsg-extension-32.0.jar
/cp gt-geotiff-32.0.jar
/cp gt-coverage-32.0.jar
/cp gt-process-raster-32.0.jar
/cp gt-shapefile-32.0.jar

/cp json-simple-1.1.1.jar
/cp commons-lang3-3.15.0.jar
/cp commons-io-2.16.1.jar
/cp jts-core-1.20.0.jar

import com.stata.sfi.*;
import org.geotools.coverage.grid.GridCoverage2D;
import org.geotools.coverage.grid.GridCoverageFactory;
import org.geotools.coverage.grid.GridGeometry2D;
import org.geotools.gce.geotiff.GeoTiffWriter;
import org.geotools.api.referencing.crs.CoordinateReferenceSystem;
import org.geotools.referencing.CRS;
import org.geotools.geometry.Envelope2D;
import org.geotools.coverage.GridSampleDimension;
import org.geotools.api.coverage.SampleDimension;
import java.awt.image.BufferedImage;
import java.awt.image.WritableRaster;
import java.io.File;
import java.util.HashMap;
import java.util.Map;

public class StataToGeoTiff {

    public static void exportToGeoTIFF(String outfile, String xvar, String yvar, String valuevar,
                                       String crsStr, double nodata, double xres, double yres) throws Exception {
        try {
            // 获取观测数
            long nobs = Data.getObsTotal();
            if (nobs == 0) {
                SFIToolkit.errorln("No data in memory");
                return;
            }

            // 读取数据到数组
            double[] xvals = new double[(int)nobs];
            double[] yvals = new double[(int)nobs];
            double[] values = new double[(int)nobs];

            for (int i = 1; i <= nobs; i++) {
                xvals[i-1] = Data.getNum(Data.getVarIndex(xvar), i);
                yvals[i-1] = Data.getNum(Data.getVarIndex(yvar), i);
                values[i-1] = Data.getNum(Data.getVarIndex(valuevar), i);
            }

            // 推断网格参数
            double xmin = Double.MAX_VALUE, xmax = Double.MIN_VALUE;
            double ymin = Double.MAX_VALUE, ymax = Double.MIN_VALUE;
            for (int i = 0; i < nobs; i++) {
                xmin = Math.min(xmin, xvals[i]);
                xmax = Math.max(xmax, xvals[i]);
                ymin = Math.min(ymin, yvals[i]);
                ymax = Math.max(ymax, yvals[i]);
            }

            // 假设规则网格，计算宽度和高度
            int width = (int) Math.round((xmax - xmin) / xres) + 1;
            int height = (int) Math.round((ymax - ymin) / yres) + 1;

            // 创建栅格
            BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_USHORT_GRAY);
            WritableRaster raster = image.getRaster();

            // 检查值范围以确定数据类型
            double minVal = Double.MAX_VALUE;
            double maxVal = Double.MIN_VALUE;
            for (int i = 0; i < nobs; i++) {
                minVal = Math.min(minVal, values[i]);
                maxVal = Math.max(maxVal, values[i]);
            }

            // 如果值是整数，使用整数栅格；否则使用浮点
            boolean isInteger = (minVal == (int)minVal && maxVal == (int)maxVal);
            if (!isInteger) {
                // 使用浮点栅格
                image = new BufferedImage(width, height, BufferedImage.TYPE_FLOAT_GRAY);
                raster = image.getRaster();
            }

            // 初始化为 NoData
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    raster.setSample(x, y, 0, nodata);
                }
            }

            // 填充值
            for (int i = 0; i < nobs; i++) {
                int col = (int) Math.round((xvals[i] - xmin) / xres);
                int row = (int) Math.round((ymax - yvals[i]) / yres); // 注意 y 轴方向
                if (col >= 0 && col < width && row >= 0 && row < height) {
                    raster.setSample(col, row, 0, values[i]);
                }
            }

            // CRS
            CoordinateReferenceSystem crs = CRS.decode(crsStr, true);

            // 创建 GridCoverage
            GridCoverageFactory factory = new GridCoverageFactory();
            Envelope2D envelope = new Envelope2D(crs, xmin, ymin, xmax - xmin, ymax - ymin);
            GridSampleDimension[] bands = new GridSampleDimension[1];
            bands[0] = new GridSampleDimension("value", new double[]{nodata}, null);
            GridCoverage2D coverage = factory.create("grid", raster, envelope, bands);

            // 写入 GeoTIFF
            GeoTiffWriter writer = new GeoTiffWriter(new File(outfile));
            writer.write(coverage, null);
            writer.dispose();

        } catch (Exception e) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
            throw new RuntimeException(e);
        }
    }
}

end