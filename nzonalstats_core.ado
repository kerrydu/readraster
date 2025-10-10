cap program drop nzonalstats_core
program define nzonalstats_core
version 17
syntax anything using/, [STATs(string) var(string) clear origin(numlist integer >0) size(numlist integer) crs(string)]

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
if !strmatch("`using'", "*:\\*") & !strmatch("`using'", "/*") {
    // 如果是相对路径，拼接当前工作目录
    local using = "`c(pwd)'/`using'"
}
removequotes, file(`shpfile')
local shpfile `r(file)'
// 判断路径是否为绝对路径
if !strmatch("`shpfile'", "*:\\*") & !strmatch("`shpfile'", "/*") {
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
} else {
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

// NetCDF libraries
/cp netcdfAll-5.9.1.jar

// External dependencies
/cp json-simple-1.1.1.jar
/cp commons-lang3-3.15.0.jar
/cp commons-io-2.16.1.jar
/cp jts-core-1.20.0.jar

// These are all the imports you need for the grid geometry handling
import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.List;
import java.util.ArrayList;
import java.util.logging.ConsoleHandler;
import java.util.logging.Handler;
import java.util.logging.Level;
import java.util.logging.Logger;

// GeoTools API imports
import org.geotools.api.parameter.GeneralParameterValue;
import org.geotools.api.parameter.ParameterValue;
import org.geotools.api.feature.simple.SimpleFeature;
import org.geotools.api.referencing.crs.CoordinateReferenceSystem;
import org.geotools.api.coverage.grid.GridEnvelope;

// GeoTools implementation imports
import org.geotools.coverage.grid.GridCoverage2D;
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
import com.stata.sfi.SFIToolkit;

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
            String[] originStrings = originParam.split(",");
            origin = new int[originStrings.length];
            for (int i = 0; i < originStrings.length; i++) {
                origin[i] = Integer.parseInt(originStrings[i]);
            }
        }

        if (sizeParam != null && !sizeParam.isEmpty()) {
            String[] sizeStrings = sizeParam.split(",");
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
            File ncFileObj = new File(ncPath);
            if (!ncFileObj.exists()) {
                System.out.println("NetCDF file does not exist: " + ncPath);
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

            // Check if it's more than 2D but with singleton dimensions
            int spatialDims = 0;
            for (ucar.nc2.Dimension dim : dimensions) {
                if (dim.getLength() > 1) {
                    spatialDims++;
                }
            }

            if (spatialDims > 2) {
                System.out.println("Variable '" + varName + "' has " + spatialDims + " non-singleton dimensions. Only 2D spatial data is supported.");
                return;
            }

            System.out.println("Variable '" + varName + "' has " + numDims + " dimensions, " + spatialDims + " spatial dimensions - proceeding with analysis");

            // Read the variable data
            Array dataArray = ncVar.read();

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

            // Get spatial bounds from coordinate variables
            double[] bounds = getSpatialBounds(ncFile, dimensions);
            ReferencedEnvelope ncEnvelope = new ReferencedEnvelope(
                bounds[0], bounds[2], bounds[1], bounds[3], ncCRS);

            // Convert NetCDF array to 2D grid
            int[] shape = dataArray.getShape();
            int height = shape[shape.length - 2]; // Last dimension is typically latitude/y
            int width = shape[shape.length - 1];  // Second to last is typically longitude/x

            // Create GridCoverage2D from NetCDF data
            float[][] gridData = new float[height][width];
            Index index = dataArray.getIndex();

            // Fill the grid data (assuming the last two dimensions are spatial)
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    // Set index for the last two dimensions
                    index.setDim(shape.length - 2, y);
                    index.setDim(shape.length - 1, x);
                    gridData[y][x] = dataArray.getFloat(index);
                }
            }

            // Create GridCoverage2D
            GridCoverageFactory factory = new GridCoverageFactory();
            SampleDimension[] bands = new SampleDimension[1];
            bands[0] = new GridSampleDimension(varName);

            coverage = factory.create(varName, gridData, ncEnvelope, bands, null, null);

            // Get coordinate systems for comparison
            CoordinateReferenceSystem rasterCRS = ncCRS;
            String rasterCRSName = rasterCRS.getName().toString();
            System.out.println("NetCDF CRS: " + rasterCRSName);

            CoordinateReferenceSystem vectorCRS = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
            String vectorCRSName = vectorCRS.getName().toString();
            System.out.println("Shapefile CRS: " + vectorCRSName);

            // Check if we need to reproject
            boolean needsReprojection = !CRS.equalsIgnoreMetadata(rasterCRS, vectorCRS);

            // Handle reprojection if needed
            if (needsReprojection) {
                System.out.println("Reprojecting shapefile from " + vectorCRSName + " to " + rasterCRSName);
                featureCollection = new ReprojectingFeatureCollection(featureCollection, rasterCRS);
            } else {
                System.out.println("Coordinate systems are compatible, no reprojection needed");
            }

            // Get shapefile bounds AFTER reprojection (if any)
            ReferencedEnvelope shpBounds = featureCollection.getBounds();
            System.out.println("Shapefile bounds: " + shpBounds);

            RasterZonalStatistics process = new RasterZonalStatistics();
            SimpleFeatureCollection resultFeatures = process.execute(
                    coverage,      // raster data
                    0,             // use first (only) band
                    featureCollection,  // vector regions
                    null           // classification image (optional, not needed here)
            );

            // Process results - safely with proper resource cleanup and store in a list
            List<SimpleFeature> allFeatures = new ArrayList<>();
            featureIterator = resultFeatures.features();
            try {
                while (featureIterator.hasNext()) {
                    SimpleFeature feature = featureIterator.next();
                    allFeatures.add(feature);
                }
            } finally {
                if (featureIterator != null) {
                    featureIterator.close();
                }
            }

            // Get total number of features
            int totalFeatures = allFeatures.size();
            System.out.println("Total features: " + totalFeatures);

            if (totalFeatures > 0) {
                // First, examine attributes to understand the data structure
                Map<String, Integer> attributeNameMap = new HashMap<>();
                List<String> idAttrNames = new ArrayList<>();
                String countAttrName = null;
                String avgAttrName = null;
                String minAttrName = null;
                String maxAttrName = null;
                String stddevAttrName = null;
                String sumAttrName = null;

                // Find attribute names and check which ones are available
                SimpleFeature firstFeature = allFeatures.get(0);
                for (int i = 0; i < firstFeature.getType().getAttributeCount(); i++) {
                    String attributeName = firstFeature.getType().getDescriptor(i).getLocalName();

                    Object value = firstFeature.getAttribute(attributeName);

                    if (attributeName.equals("count")) {
                        if (showCount) {
                            countAttrName = attributeName;
                        }
                    } else if (attributeName.equals("avg")) {
                        if (showAvg) {
                            avgAttrName = attributeName;
                        }
                    } else if (attributeName.equals("min")) {
                        if (showMin) {
                            minAttrName = attributeName;
                        }
                    } else if (attributeName.equals("max")) {
                        if (showMax) {
                            maxAttrName = attributeName;
                        }
                    } else if (attributeName.equals("stddev")) {
                        if (showStd) {
                            stddevAttrName = attributeName;
                        }
                    } else if (attributeName.equals("sum")) {
                        if (showSum) {
                            sumAttrName = attributeName;
                        }
                    } else if (!attributeName.equals("the_geom") && !attributeName.equals("z_the_geom") &&
                              !attributeName.equals("sum_2")) {
                        // Exclude geometry attributes but keep all other attributes as ID
                        idAttrNames.add(attributeName);
                    }
                }

                // Set Stata dataset size
                Data.setObsTotal(totalFeatures);

                // Create variables in Stata - first the ID attributes, then the stats
                int varIndex = 1;

                // Create ID attribute variables first
                for (String idAttr : idAttrNames) {
                    Object value = firstFeature.getAttribute(idAttr);

                    if (value instanceof Number) {
                        Data.addVarDouble(idAttr);
                        System.out.println("Created numeric variable: " + idAttr);
                    } else {
                        // Optimize string length based on content
                        int strLength = 32; // Default smaller length
                        if (value != null) {
                            String strValue = value.toString();
                            if (strValue.length() <= 16) {
                                strLength = 16;
                            } else if (strValue.length() <= 32) {
                                strLength = 32;
                            } else if (strValue.length() <= 48) {
                                strLength = 48;
                            }
                        }

                        Data.addVarStr(idAttr, strLength);
                        System.out.println("Created string variable: " + idAttr + " (length " + strLength + ")");
                    }

                    attributeNameMap.put(idAttr, varIndex++);
                }

                // Create statistics variables based on user request
                if (showCount && countAttrName != null) {
                    Data.addVarDouble("count");
                    attributeNameMap.put(countAttrName, varIndex++);
                    System.out.println("Created numeric variable: count");
                }

                if (showAvg && avgAttrName != null) {
                    Data.addVarDouble("avg");
                    attributeNameMap.put(avgAttrName, varIndex++);
                    System.out.println("Created numeric variable: avg");
                }

                if (showMin && minAttrName != null) {
                    Data.addVarDouble("min");
                    attributeNameMap.put(minAttrName, varIndex++);
                    System.out.println("Created numeric variable: min");
                }

                if (showMax && maxAttrName != null) {
                    Data.addVarDouble("max");
                    attributeNameMap.put(maxAttrName, varIndex++);
                    System.out.println("Created numeric variable: max");
                }

                if (showStd && stddevAttrName != null) {
                    Data.addVarDouble("std");
                    attributeNameMap.put(stddevAttrName, varIndex++);
                    System.out.println("Created numeric variable: std");
                }

                if (showSum && sumAttrName != null) {
                    Data.addVarDouble("sum");
                    attributeNameMap.put(sumAttrName, varIndex++);
                    System.out.println("Created numeric variable: sum");
                }

                // Fill Stata dataset with data - more efficiently by processing one observation at a time
                for (int i = 0; i < totalFeatures; i++) {
                    SimpleFeature feature = allFeatures.get(i);
                    int stataObs = i + 1; // Stata is 1-indexed

                    // First process ID attributes
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

                    // Then process all statistics for this feature at once
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

                // Force update of the Stata dataset
                Data.updateModified();

                System.out.println("Data successfully exported to Stata dataset.");
            } else {
                System.out.println("No features found in the result set.");
            }

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
}

end