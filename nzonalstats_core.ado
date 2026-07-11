cap program drop nzonalstats_core
program define nzonalstats_core
version 17
syntax anything using/, origin(numlist integer >0) size(numlist integer) [STATs(string) var(string) clear  crs(string)]

// Check if clear option is provided when data is in memory
if "`clear'"=="" {
    qui describe
    if r(N) > 0 | r(k) > 0 {
        di as error "Data already in memory, use the clear option to overwrite"
        exit 198
    }
}

// Default variable name if not provided
if missing("`var'") {
    di as error "Variable name must be specified with var() option"
    exit 198
}

// Default value for stats if not provided
if missing("`stats'") {
    local stats "avg"
}

//check stats in supported list
local stats_inlist  count  avg min max std sum

foreach stat of local stats {
    local unsupported: list stats - stats_inlist
    if "`unsupported'" != "" {
        di as error "Invalid stats parameter, must be a combination of count, avg, sum, min, max, and std"
        exit 198
    }
}

// Convert file paths to Unix-style paths
local shpfile `using'
local using `anything'

removequotes, file(`using')
local using = subinstr(`"`using'"',"\","/",.)
local shpfile = subinstr(`"`shpfile'"',"\","/",.)
// 判断路径是否为绝对路径
//if !regexm("`using'", "^(https?|ftp|s3|gs|/vsicurl/|/vsis3/|/vsigs/|/vsiaz/|/vsicurl_streaming/|/vsihttp/|/vsimem/|/vsizip/|/vsitar/|/vsicurl/).*") ///
//    & !strmatch("`using'", "*:\\*") & !strmatch("`using'", "/*") {
if !strpos("`using'", "/") {
    local using = "`c(pwd)'/`using'"
}

removequotes, file(`shpfile')
local shpfile `r(file)'
// 判断路径是否为绝对路径
//if !strmatch("`shpfile'", "*:\\*") & !strmatch("`shpfile'", "/*") {
if !strpos("`shpfile'", "/") {
    // 如果是相对路径，拼接当前工作目录
    local shpfile = "`c(pwd)'/`shpfile'"
}

local using = subinstr(`"`using'"',"\","/",.)
local shpfile = subinstr(`"`shpfile'"',"\","/",.)

// Use the arguments passed to the program
local ncfile `"`using'"'

// Clear data in Stata directly if needed
if "`clear'" == "clear" {
    clear
}

// Parse origin and size
local origin0
if "`origin'"!="" {
    local no : word count `origin'
    forvalues i=1/`no' {
        local oi : word `i' of `origin'
        local origin0 `origin0' `=`oi'-1'
    }
}

if "`size'"=="" & "`origin'"!="" {
    local size
    local no : word count `origin'
    forvalues i=1/`no' {
        local size `size' -1
    }
}

// 检查 size 元素>1的个数不能大于2
if "`size'"!="" {
    local nsize : word count `size'
    local n_gt1 0
    forvalues i=1/`nsize' {
        local si : word `i' of `size'
        if `si'>1 {
            local n_gt1 = `n_gt1'+1
        }
    }
    if `n_gt1'>2 {
        di as error "Only 2D grids are supported: at most 2 dimensions with size>1."
        exit 198
    }
}

// Prepare CRS option
local usercrs "`crs'"

// Call Java with slicing if origin specified
if "`origin'"!="" {
    java: nzonalstatics.main("`shpfile'", "`ncfile'", "`var'", "`stats'", "`origin0'", "`size'", "`usercrs'")
} 
else {
    java: nzonalstatics.main("`shpfile'", "`ncfile'", "`var'", "`stats'", "", "", "`usercrs'")
}

// Add variable labels in Stata code after Java execution
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

end

// Remove quotes from file paths
cap program drop removequotes
program define removequotes,rclass
version 16
syntax, file(string)
return local file `file'
end

// Java code for nzonalstatics.

java:

// Core GeoTools libraries
/cp gt-metadata-34.0.jar
/cp gt-api-34.0.jar
/cp gt-main-34.0.jar
/cp gt-referencing-34.0.jar
/cp gt-epsg-hsql-34.0.jar
/cp gt-epsg-extension-34.0.jar
/cp gt-geotiff-34.0.jar
/cp gt-coverage-34.0.jar
/cp gt-shapefile-34.0.jar
/cp gt-geotiff-34.0.jar
/cp gt-process-raster-34.0.jar
/cp gt-epsg-hsql-34.0.jar
/cp gt-epsg-extension-34.0.jar
/cp gt-referencing-34.0.jar
/cp gt-api-34.0.jar
/cp gt-metadata-34.0.jar

// NetCDF libraries
/cp netcdfAll-5.9.1.jar

// External dependencies
/cp json-simple-1.1.1.jar
/cp commons-lang3-3.18.0.jar
/cp commons-io-2.19.0.jar
/cp jts-core-1.20.0.jar

// These are all the imports you need for the grid geometry handling
import java.awt.image.BufferedImage;
import java.awt.image.DataBufferFloat;
import java.awt.image.WritableRaster;
import java.awt.image.Raster;
import java.awt.image.ColorModel;
import java.awt.color.ColorSpace;
import java.awt.image.ComponentColorModel;
import java.awt.image.DataBuffer;
import java.awt.Transparency;

import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.List;
import java.util.ArrayList;
import java.util.logging.ConsoleHandler;
import java.util.logging.Handler;

import org.eclipse.imagen.media.range.Range;
import org.eclipse.imagen.media.range.RangeFactory;
import org.eclipse.imagen.media.stats.Statistics;
import org.eclipse.imagen.media.stats.Statistics.StatsType;
import org.eclipse.imagen.media.zonal.ZoneGeometry;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.MultiPolygon;
import org.locationtech.jts.geom.Polygon;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.CoordinateFilter;
import org.geotools.feature.simple.SimpleFeatureBuilder;
import org.geotools.data.collection.ListFeatureCollection;

// GeoTools API imports
import org.geotools.api.feature.simple.SimpleFeature;
import org.geotools.api.feature.type.AttributeDescriptor;
import org.geotools.api.feature.type.GeometryDescriptor;
import org.geotools.api.referencing.crs.CoordinateReferenceSystem;
import org.geotools.api.referencing.crs.GeographicCRS;

// GeoTools implementation imports
import org.geotools.coverage.grid.GridCoverage2D;
import org.geotools.data.shapefile.ShapefileDataStore;
import org.geotools.data.shapefile.ShapefileDataStoreFactory;
import org.geotools.data.simple.SimpleFeatureCollection;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.store.ReprojectingFeatureCollection;
import org.geotools.geometry.jts.ReferencedEnvelope;
import org.geotools.process.raster.RasterZonalStatistics2;
import org.geotools.referencing.CRS;
import org.geotools.coverage.grid.GridCoverageFactory;
import org.geotools.api.coverage.SampleDimension;
import org.geotools.coverage.GridSampleDimension;

// NetCDF imports
import ucar.nc2.dataset.NetcdfDataset;
import ucar.nc2.dataset.NetcdfDatasets;
import ucar.nc2.Variable;
import ucar.nc2.Attribute;
import ucar.ma2.Array;
import ucar.ma2.Index;
import ucar.ma2.MAMath;

// Stata SFI imports
import com.stata.sfi.Data;

public class nzonalstatics {

    static {
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
    
    private static BufferedImage floatArrayToImage(float[][] data) {
        int height = data.length;
        int width = data[0].length;
        float[] flat = new float[width * height];
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                flat[y * width + x] = data[height - 1 - y][x];
            }
        }
        java.awt.image.DataBuffer db = new java.awt.image.DataBufferFloat(flat, flat.length);
        int bands = 1;
        int[] bandOffsets = {0};
        java.awt.image.SampleModel sm = new java.awt.image.PixelInterleavedSampleModel(
            DataBuffer.TYPE_FLOAT, width, height, bands, width * bands, bandOffsets
        );
        java.awt.image.WritableRaster raster = java.awt.image.Raster.createWritableRaster(sm, db, null);

        ColorSpace cs = ColorSpace.getInstance(ColorSpace.CS_GRAY);
        boolean hasAlpha = false;
        boolean isAlphaPremultiplied = false;
        int transparency = Transparency.OPAQUE;
        int transferType = DataBuffer.TYPE_FLOAT;
        int[] nBits = {32};
        java.awt.image.ColorModel cm = new ComponentColorModel(
            cs, nBits, hasAlpha, isAlphaPremultiplied, transparency, transferType
        );
        return new BufferedImage(cm, raster, false, null);
    }

    public static void main(String shpPath, String ncPath, String varName, String statsParam, String originParam, String sizeParam, String userCrs) throws Exception {
        // Declare resources outside the try block so we can close them in finally
        ShapefileDataStore shapefileDataStore = null;
        NetcdfDataset ncFile = null;
        SimpleFeatureIterator featureIterator = null;
        SimpleFeatureCollection featureCollection = null;
        GridCoverage2D coverage = null;

        // Parse origin and size parameters
        int[] origin = null;
        int[] size = null;

        if (originParam != null && !originParam.isEmpty()) {
            String[] originStrings = originParam.split("[,\\s]+");
            origin = new int[originStrings.length];
            for (int i = 0; i < originStrings.length; i++) {
                origin[i] = Integer.parseInt(originStrings[i]);
            }
        }

        if (sizeParam != null && !sizeParam.isEmpty()) {
            String[] sizeStrings = sizeParam.split("[,\\s]+");
            size = new int[sizeStrings.length];
            for (int i = 0; i < sizeStrings.length; i++) {
                size[i] = Integer.parseInt(sizeStrings[i]);
            }
        }

        try {
            // Disable excessive logging
            Logger.getGlobal().setLevel(Level.SEVERE);

            // Parse requested statistics
            String[] requestedStats = statsParam.toLowerCase().split("\\s+");
            boolean showCount = false;
            boolean showAvg = false;
            boolean showMin = false;
            boolean showMax = false;
            boolean showStd = false;
            boolean showSum = false;

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

            // Check if vector data file exists
            File shpFile = new File(shpPath);
            if (!shpFile.exists()) {
                System.out.println("Shapefile does not exist: " + shpPath);
                return;
            }

            // Check for required components
            String basePath = shpPath.substring(0, shpPath.lastIndexOf("."));
            File shxFile = new File(basePath + ".shx");
            File dbfFile = new File(basePath + ".dbf");
            File prjFile = new File(basePath + ".prj");

            if (!shxFile.exists() || !dbfFile.exists() || !prjFile.exists()) {
                System.out.println("Warning: Missing required shapefile components:");
                if (!shxFile.exists()) System.out.println(" - Missing .shx index file");
                if (!dbfFile.exists()) System.out.println(" - Missing .dbf attribute file");
                if (!prjFile.exists()) System.out.println(" - Missing .prj attribute file");
                System.out.println("A complete shapefile requires .shp, .shx, .dbf and .prj files.");
                return;
            }

            // Load vector data (shapefile)
            ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
            Map<String, Object> shpParams = new HashMap<>();
            shpParams.put("url", shpFile.toURI().toURL());
            shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);

            // Set UTF-8 encoding explicitly
            shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));

            // Get shapefile's FeatureCollection
            featureCollection = shapefileDataStore.getFeatureSource().getFeatures();

            // Check if NetCDF file exists
            try {
                ncFile = NetcdfDatasets.openDataset(ncPath);
            } catch (Exception e) {
                System.out.println("NetCDF file cannot be opened: " + ncPath);
                e.printStackTrace();
                return;
            }

            // Open NetCDF file
            ncFile = NetcdfDatasets.openDataset(ncPath);

            // Find the specified variable
            Variable ncVar = ncFile.findVariable(varName);
            if (ncVar == null) {
                System.out.println("Variable '" + varName + "' not found in NetCDF file");
                return;
            }

            // Check variable dimensions
            List<ucar.nc2.Dimension> dimensions = ncVar.getDimensions();
            int numDims = dimensions.size();

            // Check if it's essentially 2D (spatial dimensions)
            if (numDims < 2) {
                System.out.println("Variable '" + varName + "' has " + numDims + " dimensions. Must have at least 2 dimensions.");
                return;

            
            }

        
            System.out.println("NetCDF variable '" + varName + "' type: " + ncVar.getDataType().toString());

            Attribute fillAttr = ncVar.findAttribute("_FillValue");
            if (fillAttr == null) fillAttr = ncVar.findAttribute("missing_value");
            Double fillAttrNumeric = attributeToDouble(fillAttr);
            if (fillAttr != null) {
                String attrType = fillAttr.getDataType().toString();
                if (fillAttrNumeric != null) {
                    System.out.println("NetCDF variable '" + varName + "' missing value attribute: " + fillAttrNumeric + " (type: " + attrType + ")");
                } else {
                    System.out.println("NetCDF variable '" + varName + "' missing value attribute present but not numeric (type: " + attrType + ")");
                }
            } else {
                System.out.println("NetCDF variable '" + varName + "' has no _FillValue or missing_value attribute.");
            }

            Array dataArray;
            if (origin != null && size != null && origin.length == size.length && origin.length == dimensions.size()) {
                dataArray = ncVar.read(origin, size);
            } else {
                dataArray = ncVar.read();
            }


            // display data array shape and dimensions
            int[] actualShape = dataArray.getShape();
            int actualDims = actualShape.length;

            int yDim = -1, xDim = -1;
            List<Integer> spatialDims = new ArrayList<>();
            for (int i = 0; i < actualDims; i++) {
                if (actualShape[i] > 1) {
                    spatialDims.add(i);
                }
            }
            if (spatialDims.size() < 2) {
                System.out.println("Error: Need at least 2 spatial dimensions with size > 1");
                return;
            }
            yDim = spatialDims.get(spatialDims.size() - 2);
            xDim = spatialDims.get(spatialDims.size() - 1);


            // Get coordinate variables for CRS and bounds
            CoordinateReferenceSystem ncCRS = extractCRSFromNetCDF(ncFile, ncVar);
            if (ncCRS != null) {
                System.out.println("NetCDF CRS detected: " + ncCRS.getName().toString() + ". User-provided CRS is ignored.");
            } else {
                if (userCrs != null && !userCrs.trim().isEmpty()) {
                    System.out.println("NetCDF CRS not detected. Using user-provided CRS: " + userCrs);
                    ncCRS = CRS.decode(userCrs, true);
                } else {
                    System.out.println("Error: NetCDF file does not contain CRS information and no CRS was provided. Please specify a CRS using the crs() option.");
                    return;
                }
            }


            Variable lonVar = null, latVar = null;
            for (Variable v : ncFile.getVariables()) {
                String stdName = v.findAttributeString("standard_name", "");
                String axis = v.findAttributeString("axis", "");
                String units = v.findAttributeString("units", "");
                String name = v.getShortName().toLowerCase();

                if (lonVar == null && (
                        "longitude".equals(stdName) ||
                        "X".equalsIgnoreCase(axis) ||
                        units.contains("degrees_east") ||
                        name.contains("lon") || name.equals("x") || name.contains("long"))) {
                    lonVar = v;
                }
                if (latVar == null && (
                        "latitude".equals(stdName) ||
                        "Y".equalsIgnoreCase(axis) ||
                        units.contains("degrees_north") ||
                        name.contains("lat") || name.equals("y"))) {
                    latVar = v;
                }
            }
            if (lonVar == null || latVar == null) {
                System.out.println("Unable to automatically identify longitude/latitude variables, please check the NetCDF file!");
                return;
            }

            // read lon/lat slices based on origin/size if provided
            Array lonSlice, latSlice;
            if (origin != null && size != null) {
                int[] lonStart = new int[1];
                int[] lonSize = new int[1];
                lonStart[0] = origin[xDim];
                lonSize[0] = size[xDim];
                lonSlice = lonVar.read(lonStart, lonSize);

                int[] latStart = new int[1];
                int[] latSize = new int[1];
                latStart[0] = origin[yDim];
                latSize[0] = size[yDim];
                latSlice = latVar.read(latStart, latSize);
            } else {
                lonSlice = lonVar.read();
                latSlice = latVar.read();
            }


            double lonRes = (lonSlice.getSize() > 1) ? Math.abs(lonSlice.getDouble(1) - lonSlice.getDouble(0)) : 0.0;
            double latRes = (latSlice.getSize() > 1) ? Math.abs(latSlice.getDouble(1) - latSlice.getDouble(0)) : 0.0;

            //bounds based on pixel edges
            double minLonEdge = lonSlice.getDouble(0) - lonRes / 2.0;
            double maxLonEdge = lonSlice.getDouble((int)lonSlice.getSize() - 1) + lonRes / 2.0;
            double minLatEdge = latSlice.getDouble(0) - latRes / 2.0;
            double maxLatEdge = latSlice.getDouble((int)latSlice.getSize() - 1) + latRes / 2.0;

            ReferencedEnvelope actualEnvelope = new ReferencedEnvelope(
                minLonEdge, maxLonEdge, minLatEdge, maxLatEdge, ncCRS);

            // get shp bounds
            ReferencedEnvelope shpBounds = featureCollection.getBounds();

            /* System.out.println("NetCDF bounds: " + actualEnvelope);
            System.out.println("Shapefile bounds: " + shpBounds);

            boolean intersects = actualEnvelope.intersects((org.locationtech.jts.geom.Envelope) shpBounds);
            System.out.println("Bounds intersection: " + intersects); */


            // Convert NetCDF array to 2D grid
            int[] shape = dataArray.getShape();
            int height = shape[shape.length - 2]; // Last dimension is typically latitude/y
            int width = shape[shape.length - 1];  // Second to last is typically longitude/x

            // Create GridCoverage2D from NetCDF data
            float[][] gridData = new float[height][width];
            Index index = dataArray.getIndex();

            boolean isDouble = false;
            double fillValueDouble = Double.NaN;
            float fillValueFloat = Float.NaN;
            if (ncVar.getDataType().isFloatingPoint()) {
                if (ncVar.getDataType().toString().equalsIgnoreCase("double")) {
                    isDouble = true;
                }
            }

            if (fillAttrNumeric != null) {
                if (isDouble) {
                    fillValueDouble = fillAttrNumeric;
                } else {
                    fillValueFloat = fillAttrNumeric.floatValue();
                }
            }

            boolean hasFill = (fillAttr != null);
            float validMin = Float.NaN;
            float validMax = Float.NaN;

            // Spatial dimensions were already identified once above (spatialDims built at
            // the top of this method). Re-deriving yDim/xDim here from that single list --
            // do NOT add to the list again, or the last-two-element lookup would grab the
            // wrong indices for non-(time,y,x) dimension orderings.
            if (spatialDims.size() < 2) {
                System.out.println("Error: Need at least 2 spatial dimensions with size > 1");
                return;
            }

            // Assume the last two non-singleton dimensions are spatial dimensions
            yDim = spatialDims.get(spatialDims.size() - 2);
            xDim = spatialDims.get(spatialDims.size() - 1);

            height = actualShape[yDim];
            width = actualShape[xDim];

            gridData = new float[height][width];

            int[] indices = new int[actualDims];

            for (int i = 0; i < actualDims; i++) {
                indices[i] = 0;
            }

            // Iterate over all spatial positions
            int missingCellCount = 0;
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    // Set the indices for the spatial dimensions
                    indices[yDim] = y;
                    indices[xDim] = x;
                    // Set the index for each dimension
                    for (int d = 0; d < actualDims; d++) {
                        index.setDim(d, indices[d]);
                    }
                    float value;
                    if (isDouble) {
                        double dval = dataArray.getDouble(index);
                        boolean isMissing = false;
                        if (!Double.isNaN(fillValueDouble)) {
                            isMissing = Double.compare(dval, fillValueDouble) == 0;
                        }
                        if (!isMissing && Double.isNaN(dval)) {
                            isMissing = true;
                        }
                        if (isMissing) {
                            missingCellCount++;
                            // Keep the real fill value so it can be registered as NoData
                            // (a single NaN would otherwise poison the whole zone's stats).
                            value = hasFill ? fillValueFloat : Float.NaN;
                        } else {
                            value = (float) dval;
                            if (Float.isNaN(validMin) || value < validMin) validMin = value;
                            if (Float.isNaN(validMax) || value > validMax) validMax = value;
                        }
                    } else {
                        float fval = dataArray.getFloat(index);
                        boolean isMissing = false;
                        if (!Float.isNaN(fillValueFloat)) {
                            isMissing = Float.compare(fval, fillValueFloat) == 0;
                        }
                        if (!isMissing && Float.isNaN(fval)) {
                            isMissing = true;
                        }
                        if (isMissing) {
                            missingCellCount++;
                            // Keep the real fill value so it can be registered as NoData
                            // (a single NaN would otherwise poison the whole zone's stats).
                            value = hasFill ? fillValueFloat : Float.NaN;
                        } else {
                            value = fval;
                            if (Float.isNaN(validMin) || value < validMin) validMin = value;
                            if (Float.isNaN(validMax) || value > validMax) validMax = value;
                        }
                    }
                    gridData[y][x] = value;
                }
            }

            // Determine the NoData value used for zonal statistics.
            // - If the NetCDF has a _FillValue, keep that real value (it is by design far
            //   outside the valid range) and register it as NoData.
            // - If missing is encoded as NaN (no _FillValue), substitute a sentinel value
            //   that is strictly below the valid minimum, so it can be cleanly excluded.
            // Either way, registering NoData lets GeoTools/JAI compute stats over VALID
            // pixels only, instead of turning an entire zone into NaN.
            double noDataForStats = Double.NaN;
            if (hasFill && !Float.isNaN(fillValueFloat)) {
                // A real _FillValue is present: missing cells already hold that real value
                // (NaN cells were also mapped to it in the loop above), so just exclude it.
                noDataForStats = (double) fillValueFloat;
            } else if (!Float.isNaN(validMin) && !Float.isNaN(validMax)) {
                // No usable _FillValue (absent, or defined as NaN): derive a sentinel value
                // strictly below the valid range and substitute it for any NaN cells, then
                // register the sentinel as NoData.
                float sentinel = validMin - (Math.abs(validMax - validMin) + 100.0f);
                for (int yy = 0; yy < height; yy++) {
                    for (int xx = 0; xx < width; xx++) {
                        if (Float.isNaN(gridData[yy][xx])) {
                            gridData[yy][xx] = sentinel;
                        }
                    }
                }
                noDataForStats = (double) sentinel;
            }
            // Build the NoData range via the PUBLIC RangeFactory. The concrete RangeDouble
            // constructor is package-private, so it cannot be called from here -- RangeFactory
            // is the supported public API. A single-valued range [v, v] tells JAI to skip those
            // pixels when computing stats, so one missing cell no longer zeroes out a whole zone.
            Range noDataRange = Double.isNaN(noDataForStats)
                    ? null
                    : RangeFactory.create(noDataForStats, true, noDataForStats, true);

            // >>> DIAGNOSTIC: report how missing values were handled for the whole raster
            int nanRemaining = 0;
            for (int yy = 0; yy < height; yy++) {
                for (int xx = 0; xx < width; xx++) {
                    if (Float.isNaN(gridData[yy][xx])) nanRemaining++;
                }
            }
            System.out.println("[NoData diagnostic] hasFill=" + hasFill
                    + " fillValue=" + (Float.isNaN(fillValueFloat) ? "NaN" : fillValueFloat)
                    + " missingCellsInRaster=" + missingCellCount
                    + " nanRemainingAfterFix=" + nanRemaining
                    + " validMin=" + validMin + " validMax=" + validMax
                    + " noDataForStats=" + (Double.isNaN(noDataForStats) ? "NONE" : noDataForStats)
                    + " noDataRange=" + (noDataRange == null ? "NULL (no masking!)" : "set"));
            if (nanRemaining > 0 && noDataRange == null) {
                System.out.println("[NoData diagnostic] WARNING: raster still holds " + nanRemaining
                        + " NaN cell(s) but no NoData range was set -> these will poison zone stats. "
                        + "Define a _FillValue or ensure validMin/validMax are non-NaN.");
            }

            // Create GridCoverage2D
            GridCoverageFactory factory = new GridCoverageFactory();
            GridSampleDimension[] sampleDims = new GridSampleDimension[1];
            sampleDims[0] = new GridSampleDimension(varName);

            BufferedImage image = floatArrayToImage(gridData);
            coverage = factory.create(varName, image, actualEnvelope, sampleDims, null, null);

            // Get coordinate systems for comparison
            CoordinateReferenceSystem rasterCRS = ncCRS;
            String rasterCRSName = rasterCRS.getName().toString();
            /* System.out.println("NetCDF CRS: " + rasterCRSName); */

            CoordinateReferenceSystem vectorCRS = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
            String vectorCRSName = vectorCRS.getName().toString();
            /* System.out.println("Shapefile CRS: " + vectorCRSName); */

            // Check if we need to reproject
            boolean needsReprojection = !CRS.equalsIgnoreMetadata(rasterCRS, vectorCRS);

            // Handle reprojection if needed
            if (needsReprojection) {
                System.out.println("Reprojecting shapefile from " + vectorCRSName + " to " + rasterCRSName);
                featureCollection = new ReprojectingFeatureCollection(featureCollection, rasterCRS);
            } else {
                System.out.println("Coordinate systems are compatible, no reprojection needed");
            }

            // >>> ADDED: reconcile 0-360 vs -180-180 longitude convention mismatch
            // Both datasets may be EPSG:4326 but one uses [0,360] and the other [-180,180];
            // the CRS is identical so reprojection is skipped, yet the geometries never overlap.
            ReferencedEnvelope reprojShpBounds = featureCollection.getBounds();
            if (isGeographic(rasterCRS)) {
                double rMin = actualEnvelope.getMinX();
                double rMax = actualEnvelope.getMaxX();
                double sMin = reprojShpBounds.getMinX();
                double sMax = reprojShpBounds.getMaxX();
                // Detect longitude-convention mismatch (0-360 vs -180-180).
                // The two conventions overlap in [0,180], so a plain "do the extents intersect?"
                // test is NOT enough -- the same geographic point has X values that differ by 360.
                boolean raster0360 = (rMin >= 0 && rMax > 180);
                boolean vec0360    = (sMin >= 0 && sMax > 180);
                if (raster0360 != vec0360) {
                    System.out.println("Longitude convention mismatch (raster is "
                            + (raster0360 ? "0-360" : "-180-180") + ", shapefile is "
                            + (vec0360 ? "0-360" : "-180-180")
                            + ") detected; aligning shapefile longitudes to the raster's convention.");
                    featureCollection = alignLongitudeConvention(featureCollection, raster0360);
                    reprojShpBounds = featureCollection.getBounds();
                }
            }

            // >>> overall extent overlap check (both envelopes now in rasterCRS)
            if (!actualEnvelope.intersects((org.locationtech.jts.geom.Envelope) reprojShpBounds)) {
                System.out.println("Warning: The shapefile extent does NOT overlap the NetCDF raster extent.");
                System.out.println("  Shapefile bounds: " + reprojShpBounds.toString());
                System.out.println("  NetCDF bounds:   " + actualEnvelope.toString());
                System.out.println("  No zone will contain valid raster pixels; zonal statistics will be empty.");
                System.out.println("  Please verify the CRS and the spatial coverage of both datasets.");
            }

            // >>> DIAGNOSTIC: report raster vs shapefile extents (both in rasterCRS) for overlap
            System.out.println("[Extent diagnostic] rasterEnvelope =" + actualEnvelope.toString());
            System.out.println("[Extent diagnostic] shapeEnvelope  =" + reprojShpBounds.toString());
            System.out.println("[Extent diagnostic] overallOverlap ="
                    + actualEnvelope.intersects((org.locationtech.jts.geom.Envelope) reprojShpBounds));


            // Materialize shapefile features for repeated use, keep only polygonal geometries
            int totalFeatureCount = 0;
            List<SimpleFeature> zoneFeatures = new ArrayList<>();
            Map<String, Integer> filteredGeometryTypes = new HashMap<>();
            int invalidPolygonCount = 0;
            int emptyPolygonCount = 0;
            try {
                featureIterator = featureCollection.features();
                while (featureIterator.hasNext()) {
                    SimpleFeature feature = featureIterator.next();
                    totalFeatureCount++;

                    Object geomObj = feature.getDefaultGeometry();
                    if (geomObj instanceof Geometry) {
                        Geometry geom = (Geometry) geomObj;
                        String geomType = geom.getGeometryType();
                        if (geom instanceof Polygon || geom instanceof MultiPolygon) {
                            if (geom.isEmpty()) {
                                emptyPolygonCount++;
                                filteredGeometryTypes.merge("Empty " + geomType, 1, Integer::sum);
                                continue;
                            }
                            if (!geom.isValid()) {
                                invalidPolygonCount++;
                                filteredGeometryTypes.merge("Invalid " + geomType, 1, Integer::sum);
                                System.out.println("Skipping invalid " + geomType + " geometry in feature " + feature.getID());
                                continue;
                            }
                            zoneFeatures.add(feature);
                        } else {
                            filteredGeometryTypes.merge(geomType, 1, Integer::sum);
                        }
                    } else {
                        String geomType = geomObj == null ? "null" : geomObj.getClass().getSimpleName();
                        filteredGeometryTypes.merge(geomType, 1, Integer::sum);
                    }
                }
            } finally {
                if (featureIterator != null) {
                    featureIterator.close();
                    featureIterator = null;
                }
            }

            int filteredCount = totalFeatureCount - zoneFeatures.size();
            if (filteredCount > 0) {
                System.out.println("Warning: Filtered out " + filteredCount + " non-polygon feature(s) from " + totalFeatureCount + " total features");
                if (!filteredGeometryTypes.isEmpty()) {
                    System.out.println("Filtered geometry types:");
                    for (Map.Entry<String, Integer> entry : filteredGeometryTypes.entrySet()) {
                        System.out.println("  - " + entry.getKey() + ": " + entry.getValue() + " feature(s)");
                    }
                }
                System.out.println("Only Polygon and MultiPolygon geometries are supported for zonal statistics.");
            }

            if (invalidPolygonCount > 0) {
                System.out.println("Skipped " + invalidPolygonCount + " invalid polygon feature(s); fix geometry or remove them to include their statistics.");
            }

            if (emptyPolygonCount > 0) {
                System.out.println("Skipped " + emptyPolygonCount + " empty polygon feature(s); ensure geometries contain area before rerunning.");
            }

            if (zoneFeatures.isEmpty()) {
                System.out.println("No valid polygon features found in the shapefile after filtering.");
                return;
            }

            // Build list of statistics required by the user
            List<StatsType> statsToRequest = new ArrayList<>();
            if (showMin) {
                statsToRequest.add(StatsType.MIN);
            }
            if (showMax) {
                statsToRequest.add(StatsType.MAX);
            }
            if (showSum) {
                statsToRequest.add(StatsType.SUM);
            }
            if (showAvg) {
                statsToRequest.add(StatsType.MEAN);
            }
            if (showStd) {
                statsToRequest.add(StatsType.DEV_STD);
            }
            if (statsToRequest.isEmpty()) {
                statsToRequest.add(StatsType.MEAN);
            }

            StatsType[] statsArray = statsToRequest.toArray(new StatsType[0]);
            int[] bands = new int[] {0};

            RasterZonalStatistics2 process = new RasterZonalStatistics2();
            List<ZoneGeometry> zoneGeometries = process.execute(
                    coverage,
                    bands,
                    zoneFeatures,
                    null,
                    noDataRange,
                    null,
                    false,
                    null,
                    statsArray,
                    null,
                    null,
                    null,
                    null,
                    false);

            if (zoneGeometries == null) {
                zoneGeometries = new ArrayList<>();
            }

            int totalFeatures = zoneFeatures.size();
            Data.setObsTotal(totalFeatures);
            // >>> ADDED: counter for zones that do not overlap the raster
            int noOverlapCount = 0;

            Map<String, Integer> attributeNameMap = new HashMap<>();
            List<String> idAttrNames = new ArrayList<>();
            Map<String, String> outputToSourceAttr = new HashMap<>();
            Map<String, Boolean> idAttrNumeric = new HashMap<>();
            Map<StatsType, Integer> statsIndexMap = new HashMap<>();
            for (int i = 0; i < statsToRequest.size(); i++) {
                statsIndexMap.put(statsToRequest.get(i), i);
            }

            SimpleFeature firstFeature = zoneFeatures.get(0);
            int varIndex = 1;
            for (int i = 0; i < firstFeature.getType().getAttributeCount(); i++) {
                AttributeDescriptor descriptor = firstFeature.getType().getDescriptor(i);
                if (descriptor instanceof GeometryDescriptor) {
                    continue;
                }

                String sourceAttrName = descriptor.getLocalName();
                String outputAttrName = "z_" + sourceAttrName;
                idAttrNames.add(outputAttrName);
                outputToSourceAttr.put(outputAttrName, sourceAttrName);

                Object sampleValue = firstFeature.getAttribute(sourceAttrName);
                if (sampleValue instanceof Number) {
                    Data.addVarDouble(outputAttrName);
                    idAttrNumeric.put(outputAttrName, true);
                } else {
                    int strLength = determineStringLength(sampleValue);
                    Data.addVarStr(outputAttrName, strLength);
                    idAttrNumeric.put(outputAttrName, false);
                }

                attributeNameMap.put(outputAttrName, varIndex++);
            }

            String countAttrName = null;
            String avgAttrName = null;
            String minAttrName = null;
            String maxAttrName = null;
            String stddevAttrName = null;
            String sumAttrName = null;

            if (showCount) {
                countAttrName = "count";
                Data.addVarDouble(countAttrName);
                attributeNameMap.put(countAttrName, varIndex++);
                System.out.println("Created numeric variable: count");
            }

            if (showAvg && statsIndexMap.containsKey(StatsType.MEAN)) {
                avgAttrName = "avg";
                Data.addVarDouble(avgAttrName);
                attributeNameMap.put(avgAttrName, varIndex++);
                System.out.println("Created numeric variable: avg");
            }

            if (showMin && statsIndexMap.containsKey(StatsType.MIN)) {
                minAttrName = "min";
                Data.addVarDouble(minAttrName);
                attributeNameMap.put(minAttrName, varIndex++);
                System.out.println("Created numeric variable: min");
            }

            if (showMax && statsIndexMap.containsKey(StatsType.MAX)) {
                maxAttrName = "max";
                Data.addVarDouble(maxAttrName);
                attributeNameMap.put(maxAttrName, varIndex++);
                System.out.println("Created numeric variable: max");
            }

            if (showStd && statsIndexMap.containsKey(StatsType.DEV_STD)) {
                stddevAttrName = "std";
                Data.addVarDouble(stddevAttrName);
                attributeNameMap.put(stddevAttrName, varIndex++);
                System.out.println("Created numeric variable: std");
            }

            if (showSum && statsIndexMap.containsKey(StatsType.SUM)) {
                sumAttrName = "sum";
                Data.addVarDouble(sumAttrName);
                attributeNameMap.put(sumAttrName, varIndex++);
                System.out.println("Created numeric variable: sum");
            }

            for (int i = 0; i < totalFeatures; i++) {
                SimpleFeature feature = zoneFeatures.get(i);
                int stataObs = i + 1;

                for (String outputAttrName : idAttrNames) {
                    String sourceAttrName = outputToSourceAttr.get(outputAttrName);
                    Object value = feature.getAttribute(sourceAttrName);
                    int stataVar = attributeNameMap.get(outputAttrName);

                    if (value == null) {
                        continue;
                    }

                    if (Boolean.TRUE.equals(idAttrNumeric.get(outputAttrName))) {
                        Data.storeNumFast(stataVar, stataObs, ((Number) value).doubleValue());
                    } else {
                        Data.storeStr(stataVar, stataObs, value.toString());
                    }
                }

                ZoneGeometry zoneGeometry = i < zoneGeometries.size() ? zoneGeometries.get(i) : null;
                Statistics[] stats = extractStatisticsForZone(zoneGeometry, 0);
                if (stats == null || stats.length == 0) {
                    // >>> ADDED: zone has no overlapping raster pixels at all
                    noOverlapCount++;
                    System.out.println("Warning: Zone " + (i + 1) + " (" + feature.getID() + ") has no overlapping raster pixels; statistics skipped.");
                    continue;
                }

                // >>> ADDED: detect zones whose valid sample count is 0
                Number sampleCountObj = stats[0].getNumSamples();
                int sampleCountVal = (sampleCountObj != null) ? sampleCountObj.intValue() : 0;
                if (sampleCountVal == 0) {
                    noOverlapCount++;
                    System.out.println("Warning: Zone " + (i + 1) + " (" + feature.getID() + ") has 0 valid raster pixels; statistics set to missing.");
                }

                if (countAttrName != null) {
                    Data.storeNumFast(attributeNameMap.get(countAttrName), stataObs, (double) sampleCountVal);
                }

                Double zoneProbe = null;
                if (avgAttrName != null) {
                    zoneProbe = getStatValue(stats, statsIndexMap, StatsType.MEAN);
                    if (zoneProbe != null) {
                        Data.storeNumFast(attributeNameMap.get(avgAttrName), stataObs, zoneProbe);
                    }
                } else if (minAttrName != null) {
                    zoneProbe = getStatValue(stats, statsIndexMap, StatsType.MIN);
                }

                if (minAttrName != null) {
                    Double minValue = getStatValue(stats, statsIndexMap, StatsType.MIN);
                    if (minValue != null) {
                        Data.storeNumFast(attributeNameMap.get(minAttrName), stataObs, minValue);
                    }
                }

                if (maxAttrName != null) {
                    Double maxValue = getStatValue(stats, statsIndexMap, StatsType.MAX);
                    if (maxValue != null) {
                        Data.storeNumFast(attributeNameMap.get(maxAttrName), stataObs, maxValue);
                    }
                }

                if (stddevAttrName != null) {
                    Double stdValue = getStatValue(stats, statsIndexMap, StatsType.DEV_STD);
                    if (stdValue != null) {
                        Data.storeNumFast(attributeNameMap.get(stddevAttrName), stataObs, stdValue);
                    }
                }

                if (sumAttrName != null) {
                    Double sumValue = getStatValue(stats, statsIndexMap, StatsType.SUM);
                    if (sumValue != null) {
                        Data.storeNumFast(attributeNameMap.get(sumAttrName), stataObs, sumValue);
                    }
                }

                // >>> DIAGNOSTIC: explain why a zone's statistics are missing
                boolean zoneMissing = (zoneProbe == null || zoneProbe.isNaN());
                if (zoneMissing) {
                    String reason;
                    if (sampleCountVal == 0) {
                        reason = "0 valid pixels overlap this zone -> geometry/CRS or 0-360 vs -180-180 "
                                + "longitude-convention mismatch, or the zone lies outside the raster extent. "
                                + "Check the [Extent diagnostic] lines above.";
                    } else {
                        reason = "zone HAS " + sampleCountVal + " valid pixels but avg/min is still NaN/missing -> "
                                + "NoData masking is NOT taking effect (missing values leaked into the stat). "
                                + "Check the [NoData diagnostic] line above: noDataRange must read 'set', not 'NULL'.";
                    }
                    System.out.println("Missing zone #" + (i + 1) + " (" + feature.getID() + "): " + reason);
                }
            }

            // >>> ADDED: summary of non-overlapping zones
            if (noOverlapCount > 0) {
                System.out.println("Warning: " + noOverlapCount + " of " + totalFeatures + " zone(s) did not overlap the raster or had 0 valid pixels.");
                System.out.println("  These zones have no statistics (or count = 0). Check their location against the raster extent.");
            }

            Data.updateModified();
            System.out.println("Data successfully exported to Stata dataset.");

        } catch (Exception e) {
            System.out.println("Error in nzonalstatics: " + e.getMessage());
            e.printStackTrace();
        } finally {
            // Clean up all resources even if an exception occurs
            try {
                if (featureIterator != null) {
                    featureIterator.close();
                }
                if (ncFile != null) {
                    ncFile.close();
                }
                if (shapefileDataStore != null) {
                    shapefileDataStore.dispose();
                }
                if (coverage != null) {
                    coverage.dispose(true);
                }
                // Force JVM garbage collection to help release file locks
                System.gc();
            } catch (Exception e) {
                System.out.println("Error closing resources: " + e.getMessage());
                e.printStackTrace();
            }
        }
    }

    /**
     * Extract CRS from NetCDF file
     */
    private static CoordinateReferenceSystem extractCRSFromNetCDF(NetcdfDataset ncFile, Variable var) {
        try {
            // Try to find CRS in global attributes
            Attribute crsAttr = ncFile.findGlobalAttribute("crs_wkt");
            if (crsAttr != null) {
                return CRS.parseWKT(crsAttr.getStringValue());
            }

            crsAttr = ncFile.findGlobalAttribute("spatial_ref");
            if (crsAttr != null) {
                return CRS.parseWKT(crsAttr.getStringValue());
            }

            // Try EPSG code
            Attribute epsgAttr = ncFile.findGlobalAttribute("epsg_code");
            if (epsgAttr != null) {
                return CRS.decode("EPSG:" + epsgAttr.getNumericValue().intValue(), true);
            }

            // Check variable attributes
            crsAttr = var.findAttribute("crs_wkt");
            if (crsAttr != null) {
                return CRS.parseWKT(crsAttr.getStringValue());
            }

            crsAttr = var.findAttribute("spatial_ref");
            if (crsAttr != null) {
                return CRS.parseWKT(crsAttr.getStringValue());
            }

            epsgAttr = var.findAttribute("epsg_code");
            if (epsgAttr != null) {
                return CRS.decode("EPSG:" + epsgAttr.getNumericValue().intValue(), true);
            }

        } catch (Exception e) {
            System.out.println("Warning: Could not parse CRS from NetCDF: " + e.getMessage());
        }

        return null;
    }

    /**
     * Get spatial bounds from coordinate variables
     */
    private static double[] getSpatialBounds(NetcdfDataset ncFile, List<ucar.nc2.Dimension> dimensions) {
        // Default bounds (global)
        double minLon = -180, maxLon = 180, minLat = -90, maxLat = 90;

        try {
            // Find coordinate variables (typically named lon/latitude or x/y)
            Variable lonVar = ncFile.findVariable("lon");
            if (lonVar == null) lonVar = ncFile.findVariable("longitude");
            if (lonVar == null) lonVar = ncFile.findVariable("x");

            Variable latVar = ncFile.findVariable("lat");
            if (latVar == null) latVar = ncFile.findVariable("latitude");
            if (latVar == null) latVar = ncFile.findVariable("y");

            if (lonVar != null && latVar != null) {
                // Read coordinate values
                Array lonArray = lonVar.read();
                Array latArray = latVar.read();

                minLon = MAMath.getMinimum(lonArray);
                maxLon = MAMath.getMaximum(lonArray);
                minLat = MAMath.getMinimum(latArray);
                maxLat = MAMath.getMaximum(latArray);
            }
        } catch (Exception e) {
            System.out.println("Warning: Could not read coordinate bounds: " + e.getMessage());
        }

        return new double[]{minLon, minLat, maxLon, maxLat};
    }

    private static Double attributeToDouble(Attribute attr) {
        if (attr == null) {
            return null;
        }

        Number numericValue = attr.getNumericValue();
        if (numericValue != null) {
            return numericValue.doubleValue();
        }

        String stringValue = attr.getStringValue();
        if (stringValue == null) {
            return null;
        }

        String trimmed = stringValue.trim();
        if (trimmed.isEmpty() || trimmed.equalsIgnoreCase("null")) {
            return null;
        }

        if (trimmed.equalsIgnoreCase("nan")) {
            return Double.NaN;
        }

        try {
            return Double.parseDouble(trimmed);
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private static int determineStringLength(Object value) {
        if (value == null) {
            return 32;
        }

        int length = value.toString().length();
        if (length <= 16) {
            return 16;
        } else if (length <= 32) {
            return 32;
        } else if (length <= 48) {
            return 48;
        }
        return 80;
    }

    private static Statistics[] extractStatisticsForZone(ZoneGeometry zoneGeometry, int bandIndex) {
        if (zoneGeometry == null) {
            return null;
        }

        Map<Integer, Map<Range, Statistics[]>> statsPerBand = zoneGeometry.getStatsPerBand(bandIndex);
        if (statsPerBand == null || statsPerBand.isEmpty()) {
            return null;
        }

        for (Map<Range, Statistics[]> rangeMap : statsPerBand.values()) {
            if (rangeMap == null || rangeMap.isEmpty()) {
                continue;
            }
            for (Statistics[] statsArray : rangeMap.values()) {
                if (statsArray != null && statsArray.length > 0) {
                    return statsArray;
                }
            }
        }
        return null;
    }

    private static Double getStatValue(Statistics[] stats, Map<StatsType, Integer> indexMap, StatsType statType) {
        if (stats == null || indexMap == null || statType == null) {
            return null;
        }

        Integer idx = indexMap.get(statType);
        if (idx == null || idx < 0 || idx >= stats.length) {
            return null;
        }

        Statistics statistic = stats[idx];
        if (statistic == null) {
            return null;
        }

        Object result = statistic.getResult();
        if (result instanceof Number) {
            return ((Number) result).doubleValue();
        }
        return null;
    }

    /**
     * Returns true if the CRS is geographic (longitude/latitude, degrees).
     * Used to decide whether the 0-360 vs -180-180 longitude convention fix applies.
     */
    private static boolean isGeographic(CoordinateReferenceSystem crs) {
        return crs instanceof GeographicCRS;
    }

    /**
     * Shift all geometries in the collection by a constant longitude offset (degrees).
     * Resolves the 0-360 vs -180-180 longitude convention mismatch when both datasets
     * share the same geographic CRS but different longitude ranges.
     */
    private static SimpleFeatureCollection alignLongitudeConvention(SimpleFeatureCollection fc, final boolean raster0360) {
        try {
            ListFeatureCollection result = new ListFeatureCollection(fc.getSchema());
            SimpleFeatureIterator it = fc.features();
            try {
                while (it.hasNext()) {
                    SimpleFeature f = it.next();
                    SimpleFeature f2 = SimpleFeatureBuilder.copy(f);
                    Object geomObj = f2.getDefaultGeometry();
                    if (geomObj instanceof Geometry) {
                        Geometry g = (Geometry) ((Geometry) geomObj).clone();
                        g.apply(new CoordinateFilter() {
                            @Override
                            public void filter(Coordinate coord) {
                                // Bring the coordinate into the raster's longitude convention.
                                if (raster0360) {
                                    // raster uses 0-360: map negatives into [0,360)
                                    if (coord.x < 0) {
                                        coord.x += 360.0;
                                    } else if (coord.x >= 360.0) {
                                        coord.x -= 360.0;
                                    }
                                } else {
                                    // raster uses -180-180: map values >180 into (-180,180]
                                    if (coord.x > 180.0) {
                                        coord.x -= 360.0;
                                    } else if (coord.x <= -180.0) {
                                        coord.x += 360.0;
                                    }
                                }
                            }
                        });
                        g.geometryChanged();
                        f2.setDefaultGeometry(g);
                    }
                    result.add(f2);
                }
            } finally {
                it.close();
            }
            return result;
        } catch (Exception e) {
            System.out.println("Warning: failed to align shapefile longitudes: " + e.getMessage());
            return fc;
        }
    }
}

end
