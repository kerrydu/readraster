cap program drop gzonalstats_core
program define gzonalstats_core
version 18.0
syntax anything using/, [STATs(string) band(integer 1) clear]

// Check if clear option is provided when data is in memory
if "`clear'"=="" {
    qui describe
    if r(N) > 0 | r(k) > 0 {
        di as error "Data already in memory, use the clear option to overwrite"
        exit 198
    }
}

if `band'<1{
    di as error "Band index must be >= 1"
    exit 198
}

local band = `band' - 1

// Default value for stats if not provided
if missing("`stats'") {
    local stats "count avg min max"
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
local tifffile `"`using'"'

// Clear data in Stata directly if needed
if "`clear'" == "clear" {
    clear
}

java: zonalstatics.main("`shpfile'", "`tifffile'", `band', "`stats'")

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

// Java code for zonalstatics.

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

// Stata SFI imports
import com.stata.sfi.Data;
import com.stata.sfi.SFIToolkit;

public class zonalstatics {

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

    public static void main(String shpPath, String tiffPath, int bandIndex, String statsParam) throws Exception {
        // Declare resources outside the try block so we can close them in finally
        ShapefileDataStore shapefileDataStore = null;
        AbstractGridCoverage2DReader reader = null;
        SimpleFeatureIterator featureIterator = null;
        SimpleFeatureCollection featureCollection = null;
        
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

            // Check if raster data file exists
            File tiffFile = new File(tiffPath);
            if (!tiffFile.exists()) {
                System.out.println("GeoTIFF file does not exist: " + tiffPath);
                return;
            }

            // Create a GeoTiff reader
            reader = new GeoTiffReader(tiffFile);
            
            // Get coordinate systems for comparison
            CoordinateReferenceSystem rasterCRS = reader.getCoordinateReferenceSystem();
            String rasterCRSName = rasterCRS.getName().toString();
            System.out.println("Raster CRS: " + rasterCRSName);
            System.out.println("Raster CRS WKT: " + rasterCRS.toWKT());

            CoordinateReferenceSystem vectorCRS = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
            
            // Extract more readable CRS names for logging
            
            String vectorCRSName = vectorCRS.getName().toString();
            
            
            System.out.println("Shapefile CRS: " + vectorCRSName);
            System.out.println("Vector CRS WKT: " + vectorCRS.toWKT());
            
            
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
            System.out.println("Shapefile bounds for raster reading: " + shpBounds);

            // Create read parameters to limit reading to shapefile's bounds
            GeneralParameterValue[] readParams = null;

            if (shpBounds != null && !shpBounds.isEmpty()) {
                System.out.println("Optimizing raster read to only cover shapefile extent");
                
                try {
                    // Get the raster extent first to ensure we don't request outside its bounds
                    GridEnvelope gridRange = reader.getOriginalGridRange();
                    ReferencedEnvelope rasterEnvelope = new ReferencedEnvelope(
                        reader.getOriginalEnvelope());
                    
                    System.out.println("Raster envelope: " + rasterEnvelope);
                    
                    // Calculate the intersection of shapefile bounds and raster envelope
                    // to ensure we don't try to read outside the raster extent
                    ReferencedEnvelope intersection = new ReferencedEnvelope(
                        Math.max(shpBounds.getMinX(), rasterEnvelope.getMinX()),
                        Math.min(shpBounds.getMaxX(), rasterEnvelope.getMaxX()),
                        Math.max(shpBounds.getMinY(), rasterEnvelope.getMinY()),
                        Math.min(shpBounds.getMaxY(), rasterEnvelope.getMaxY()),
                        shpBounds.getCoordinateReferenceSystem()
                    );
                    
                    if (intersection.isEmpty()) {
                        System.out.println("Warning: Shapefile bounds do not overlap with raster extent!");
                        System.out.println("Using full raster extent instead.");
                        // Use null parameters to read the entire raster since there's no overlap
                    } else {
                        System.out.println("Using intersection bounds: " + intersection);
                        
                        // Read only the minimal area needed
                        GridCoverage2D fullGridCov = reader.read(null);
                        GridGeometry2D originalGeometry = fullGridCov.getGridGeometry();
                        
                        // Create the parameter for limiting the read area
                        final ParameterValue<GridGeometry2D> gg = AbstractGridFormat.READ_GRIDGEOMETRY2D.createValue();
                        
                        // Create a grid geometry using the intersection of bounds
                        GridGeometry2D simpleGeometry = new GridGeometry2D(
                            originalGeometry.getGridRange(),
                            originalGeometry.getGridToCRS(),
                            intersection.getCoordinateReferenceSystem()
                        );
                        
                        gg.setValue(simpleGeometry);
                        readParams = new GeneralParameterValue[] { gg };
                        
                        // Dispose of the temporary full coverage as we only needed its geometry
                        fullGridCov.dispose(true);
                        
                        System.out.println("Successfully created optimized read parameters");
                    }
                } catch (Exception e) {
                    System.out.println("Warning: Could not create optimized read parameters: " + e.getMessage());
                    e.printStackTrace();
                    System.out.println("Falling back to reading the entire raster");
                    readParams = null;
                }
            }

            // Read the raster data - either limited or full depending on whether readParams was set
            GridCoverage2D coverage = null;
            try {
                coverage = reader.read(readParams);
                System.out.println("Successfully read raster data" + 
                                   (readParams != null ? " with optimization" : " (full extent)"));
            } catch (Exception e) {
                System.out.println("Error reading raster with optimized parameters: " + e.getMessage());
                System.out.println("Falling back to reading the entire raster");
                coverage = reader.read(null); // Fall back to reading the entire raster
            }

            // Check if we got a valid coverage
            if (coverage == null) {
                System.out.println("Failed to read raster data. Aborting.");
                return;
            }
            
            // Check the number of bands in the GeoTIFF file
            int numBands = coverage.getNumSampleDimensions();
            //System.out.println("Number of bands in GeoTIFF: " + numBands);
            
            // Ensure band index is in valid range
            if (bandIndex >= numBands || bandIndex < 0) {
                System.out.println("Specified band index is out of range, current index: " + bandIndex + ", total bands: " + numBands);
                return;
            }

            RasterZonalStatistics process = new RasterZonalStatistics();
            SimpleFeatureCollection resultFeatures = process.execute(
                    coverage,      // raster data
                    bandIndex,     // use specified band
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
                    /* System.out.println("Feature attribute: " + attributeName); */
                    
                    Object value = firstFeature.getAttribute(attributeName);
                    
                    if (attributeName.equals("count")) {
                        if (showCount) {  // Only store if requested
                            countAttrName = attributeName;
                        }
                    } else if (attributeName.equals("avg")) {
                        if (showAvg) {  // Only store if requested
                            avgAttrName = attributeName;
                        }
                    } else if (attributeName.equals("min")) {
                        if (showMin) {  // Only store if requested
                            minAttrName = attributeName;
                        }
                    } else if (attributeName.equals("max")) {
                        if (showMax) {  // Only store if requested
                            maxAttrName = attributeName;
                        }
                    } else if (attributeName.equals("stddev")) {
                        if (showStd) {  // Only store if requested
                            stddevAttrName = attributeName;
                        }
                    } else if (attributeName.equals("sum")) {
                        if (showSum) {  // Only store if requested
                            sumAttrName = attributeName;
                        }
                    } else if (!attributeName.equals("the_geom") && !attributeName.equals("z_the_geom") &&
                              !attributeName.equals("sum_2")) {
                        // Exclude geometry attributes but keep all other attributes as IDs
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
            System.out.println("Error in zonalstatics: " + e.getMessage());
            e.printStackTrace();
        } finally {
            // Clean up all resources even if an exception occurs
            try {
                if (featureIterator != null) {
                    featureIterator.close();
                }
                if (reader != null) {
                    reader.dispose();
                }
                if (shapefileDataStore != null) {
                    shapefileDataStore.dispose();
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
     * Extract a more readable name from a CoordinateReferenceSystem
     * @param crs The coordinate reference system
     * @return A simplified name string
     */
    /* private static String extractCRSName(CoordinateReferenceSystem crs) {
        if (crs == null) {
            return "Unknown CRS";
        }
        
        // Get the WKT representation for analysis
        String wkt = crs.toWKT();
        
        // Try to get a descriptive name
        String name = crs.getName().toString();
        
        // Determine if this is a projected or geographic CRS
        boolean isProjected = wkt.startsWith("PROJCS");
        boolean isGeographic = wkt.contains("GEOGCS");
        
        if (isProjected) {
            // Handle projected coordinate systems
            if (wkt.contains("Albers")) {
                return "Albers Equal Area (" + name + ")"; 
            } else if (wkt.contains("UTM")) {
                // Try to extract the UTM zone
                if (wkt.contains("zone")) {
                    try {
                        int zoneIndex = wkt.toLowerCase().indexOf("zone") + 4;
                        String zoneText = wkt.substring(zoneIndex, zoneIndex + 3).trim();
                        // Extract just the digits
                        zoneText = zoneText.replaceAll("[^0-9]", "");
                        int zone = Integer.parseInt(zoneText);
                        return "UTM Zone " + zone + " (" + name + ")";
                    } catch (Exception e) {
                        // Just use a generic UTM name if extraction fails
                        return "UTM " + name;
                    }
                }
                return "UTM " + name;
            } else if (wkt.contains("Mercator")) {
                return "Mercator (" + name + ")";
            } else if (wkt.contains("Lambert")) {
                return "Lambert Conformal Conic (" + name + ")";
            }
            // Default for projected systems
            return name + " (Projected)";
        } else if (isGeographic) {
            // Handle geographic coordinate systems
            if (wkt.contains("WGS") && wkt.contains("84")) {
                return "WGS84 Geographic (lat/lon)";
            } else if (wkt.contains("NAD") && wkt.contains("83")) {
                return "NAD83 Geographic (lat/lon)";
            }
            // Default for geographic systems
            return name + " (Geographic lat/lon)";
        }
        
        // Default fallback
        return name;
    } */
}

end