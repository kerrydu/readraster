cap program drop gtiffread3
program define gtiffread3
version 18.0
syntax anything using/, [CRScode(string) band(integer 1) IDfield(string) NAMEfield(string) clear]

gtiffread2_core `0'

end

////////////////////////////////////////

cap program drop gtiffread2_core
program define gtiffread2_core
version 18.0
syntax anything using/, [CRScode(string) band(integer 1) IDfield(string) NAMEfield(string) clear]

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

// Set default field names if not provided
if missing("`idfield'") {
    local idfield "ID"
}
if missing("`namefield'") {
    local namefield "NAME"
}

// Convert file paths to Unix-style paths
local shpfile `using'
local using `anything'

removequotes, file(`using')

local using = subinstr(`"`using'"',"\","/",.)
local shpfile = subinstr(`"`shpfile'"',"\","/",.)

// Handle relative paths
if !strmatch("`using'", "*:\\*") & !strmatch("`using'", "/*") {
    local using = "`c(pwd)'/`using'"
}

removequotes, file(`shpfile')
local shpfile `r(file)'

if !strmatch("`shpfile'", "*:\\*") & !strmatch("`shpfile'", "/*") {
    local shpfile = "`c(pwd)'/`shpfile'"
}

local using = subinstr(`"`using'"',"\","/",.)
local shpfile = subinstr(`"`shpfile'"',"\","/",.)

// Handle CRS code processing similar to gtiffread
if "`crscode'" == "" {
    local crscode "None"
}

if strpos(lower("`crscode'"), ".tif") | strpos(lower("`crscode'"), ".shp") {
    removequotes, file(`crscode')
    local crscode `r(file)'
    local crscode = subinstr("`crscode'", "\", "/", .)
    if !strmatch("`crscode'", "*:\\*") & !strmatch("`crscode'", "/*") {
        local crscode = "`c(pwd)'/`crscode'"
    }
    local crscode = subinstr("`crscode'", "\", "/", .)
}

local tifffile `"`using'"'

// Clear data in Stata directly if needed
if "`clear'" == "clear" {
    clear
}

// Call Java function for raster region identification
java: RasterRegionIdentifier.main("`shpfile'", "`tifffile'", `band', "`crscode'", "`idfield'", "`namefield'")

// Add variable labels after Java execution
cap confirm var x
if !_rc {
    label var x "GeoTiff X Coordinate"
}
cap confirm var y
if !_rc {
    label var y "GeoTiff Y Coordinate"
}
cap confirm var value
if !_rc {
    label var value "Pixel Value (Band `=`band'+1')"
}
cap confirm var region_id
if !_rc {
    label var region_id "Administrative Region ID"
}
cap confirm var region_name
if !_rc {
    label var region_name "Administrative Region Name"
}

// Add labels for any additional shapefile attributes
qui ds
local allvars `r(varlist)'
foreach var of local allvars {
    if !inlist("`var'", "x", "y", "value", "region_id", "region_name") {
        cap confirm var `var'
        if !_rc {
            label var `var' "Shapefile attribute: `var'"
        }
    }
}

end

// Remove quotes from file paths
cap program drop removequotes
program define removequotes,rclass
version 16
syntax, file(string) 
return local file `file'
end

////////////////////////////////////////

java:

// Core GeoTools libraries - same as gzonalstats
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
/cp jai_core-1.1.3.jar
/cp jai_imageio-1.1.jar

import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.List;
import java.util.ArrayList;
import java.util.logging.ConsoleHandler;
import java.util.logging.Handler;
import java.awt.image.Raster;

// GeoTools API imports
import org.geotools.api.parameter.GeneralParameterValue;
import org.geotools.api.parameter.ParameterValue;
import org.geotools.api.feature.simple.SimpleFeature;
import org.geotools.api.referencing.crs.CoordinateReferenceSystem;
import org.geotools.api.coverage.grid.GridEnvelope;
import org.geotools.api.referencing.operation.MathTransform;
import org.geotools.api.referencing.operation.TransformException;
import org.geotools.api.feature.type.AttributeDescriptor;

// GeoTools implementation imports
import org.geotools.coverage.grid.GridCoverage2D;
import org.geotools.coverage.grid.GridGeometry2D;
import org.geotools.coverage.grid.GridCoordinates2D;
import org.geotools.coverage.grid.GridEnvelope2D;
import org.geotools.coverage.grid.io.AbstractGridCoverage2DReader;
import org.geotools.coverage.grid.io.AbstractGridFormat;
import org.geotools.coverage.GridSampleDimension;
import org.geotools.data.shapefile.ShapefileDataStore;
import org.geotools.data.shapefile.ShapefileDataStoreFactory;
import org.geotools.data.simple.SimpleFeatureCollection;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.simple.SimpleFeatureSource;
import org.geotools.data.store.ReprojectingFeatureCollection;
import org.geotools.gce.geotiff.GeoTiffReader;
import org.geotools.geometry.jts.ReferencedEnvelope;
import org.geotools.geometry.jts.JTS;
import org.geotools.geometry.jts.JTSFactoryFinder;
import org.geotools.geometry.Position2D;
import org.geotools.referencing.CRS;

// JTS geometry imports
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Envelope;
import org.locationtech.jts.geom.prep.PreparedGeometry;
import org.locationtech.jts.geom.prep.PreparedGeometryFactory;

// Stata SFI imports
import com.stata.sfi.Data;
import com.stata.sfi.SFIToolkit;

public class RasterRegionIdentifier {

    static {
        // Disable the JSON-related service loading at startup - same as gzonalstats
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

    private static final int MAX_OBS = 1_000_000_000;

    public static void main(String shpPath, String tiffPath, int bandIndex, String targetEpsg, 
                           String idField, String nameField) throws Exception {
        
        // Declare resources outside the try block - same pattern as gzonalstats
        ShapefileDataStore shapefileDataStore = null;
        AbstractGridCoverage2DReader reader = null;
        SimpleFeatureIterator featureIterator = null;
        SimpleFeatureCollection featureCollection = null;
        
        try {
            // Disable excessive logging
            Logger.getGlobal().setLevel(Level.SEVERE);
            
            // Check if vector data file exists - same validation as gzonalstats
            File shpFile = new File(shpPath);
            if (!shpFile.exists()) {
                SFIToolkit.errorln("Shapefile does not exist: " + shpPath);
                return;
            }

            // Check for required components
            String basePath = shpPath.substring(0, shpPath.lastIndexOf("."));
            File shxFile = new File(basePath + ".shx");
            File dbfFile = new File(basePath + ".dbf");
            File prjFile = new File(basePath + ".prj");

            if (!shxFile.exists() || !dbfFile.exists()) {
                SFIToolkit.displayln("Warning: Missing required shapefile components:");
                if (!shxFile.exists()) SFIToolkit.displayln(" - Missing .shx index file");
                if (!dbfFile.exists()) SFIToolkit.displayln(" - Missing .dbf attribute file");
                if (!prjFile.exists()) SFIToolkit.displayln(" - Missing .prj projection file");
                SFIToolkit.errorln("A complete shapefile requires .shp, .shx, .dbf and .prj files.");
                return;
            }

            // Load vector data (shapefile) - same pattern as gzonalstats
            ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
            Map<String, Object> shpParams = new HashMap<>();
            shpParams.put("url", shpFile.toURI().toURL());
            shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);

            // Set UTF-8 encoding explicitly
            shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));

            // Get shapefile's FeatureCollection
            SimpleFeatureSource featureSource = shapefileDataStore.getFeatureSource();
            featureCollection = featureSource.getFeatures();

            // Check if raster data file exists
            File tiffFile = new File(tiffPath);
            if (!tiffFile.exists()) {
                SFIToolkit.errorln("GeoTIFF file does not exist: " + tiffPath);
                return;
            }

            // Create a GeoTiff reader
            reader = new GeoTiffReader(tiffFile);
            
            // Get coordinate systems for comparison - same CRS handling as gzonalstats
            CoordinateReferenceSystem rasterCRS = reader.getCoordinateReferenceSystem();
            SFIToolkit.displayln("Raster CRS: " + rasterCRS.getName().toString());

            CoordinateReferenceSystem vectorCRS = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
            SFIToolkit.displayln("Shapefile CRS: " + vectorCRS.getName().toString());
            
            // Check if we need to reproject
            boolean needsReprojection = !CRS.equalsIgnoreMetadata(rasterCRS, vectorCRS);
            
            // Handle reprojection if needed
            if (needsReprojection) {
                SFIToolkit.displayln("Reprojecting shapefile to match raster CRS");
                featureCollection = new ReprojectingFeatureCollection(featureCollection, rasterCRS);
            } else {
                SFIToolkit.displayln("Coordinate systems are compatible, no reprojection needed");
            }
            
            // Get shapefile bounds AFTER reprojection
            ReferencedEnvelope shpBounds = featureCollection.getBounds();
            SFIToolkit.displayln("Shapefile bounds: " + shpBounds);

            // Create read parameters to limit reading to shapefile's bounds - same optimization as gzonalstats
            GeneralParameterValue[] readParams = createOptimizedReadParams(reader, shpBounds);

            // Read the raster data
            GridCoverage2D coverage = null;
            try {
                coverage = reader.read(readParams);
                SFIToolkit.displayln("Successfully read raster data" + 
                                   (readParams != null ? " with optimization" : " (full extent)"));
            } catch (Exception e) {
                SFIToolkit.displayln("Error reading raster with optimized parameters, falling back to full read");
                coverage = reader.read(null);
            }

            if (coverage == null) {
                SFIToolkit.errorln("Failed to read raster data. Aborting.");
                return;
            }
            
            // Validate band index
            int numBands = coverage.getNumSampleDimensions();
            if (bandIndex >= numBands || bandIndex < 0) {
                SFIToolkit.errorln("Specified band index is out of range, current index: " + bandIndex + ", total bands: " + numBands);
                return;
            }

            // Create coordinate transform for output if needed
            MathTransform outputTransform = createOutputTransform(coverage, targetEpsg);

            // Check field availability - similar to gzonalstats attribute checking
            boolean hasIdField = hasAttribute(featureSource, idField);
            boolean hasNameField = hasAttribute(featureSource, nameField);
            
            if (!hasIdField) {
                SFIToolkit.displayln("Warning: ID field '" + idField + "' not found. Using FID instead.");
            }
            if (!hasNameField) {
                SFIToolkit.displayln("Warning: Name field '" + nameField + "' not found. Using empty string.");
            }

            // Get all additional attributes from shapefile
            List<String> additionalAttrs = getAdditionalAttributes(featureSource, idField, nameField);

            // Process regions and extract raster values
            processRegionsAndExtractValues(coverage, featureCollection, bandIndex, outputTransform,
                                         idField, nameField, hasIdField, hasNameField, additionalAttrs);

        } catch (Exception e) {
            SFIToolkit.errorln("Error in RasterRegionIdentifier: " + e.getMessage());
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
        } finally {
            // Clean up all resources - same cleanup pattern as gzonalstats
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
                System.gc();
            } catch (Exception e) {
                SFIToolkit.errorln("Error closing resources: " + e.getMessage());
            }
        }
    }

    private static GeneralParameterValue[] createOptimizedReadParams(AbstractGridCoverage2DReader reader, 
                                                                   ReferencedEnvelope shpBounds) {
        // Same optimization logic as gzonalstats
        GeneralParameterValue[] readParams = null;

        if (shpBounds != null && !shpBounds.isEmpty()) {
            SFIToolkit.displayln("Optimizing raster read to only cover shapefile extent");
            
            try {
                GridEnvelope gridRange = reader.getOriginalGridRange();
                ReferencedEnvelope rasterEnvelope = new ReferencedEnvelope(reader.getOriginalEnvelope());
                
                ReferencedEnvelope intersection = new ReferencedEnvelope(
                    Math.max(shpBounds.getMinX(), rasterEnvelope.getMinX()),
                    Math.min(shpBounds.getMaxX(), rasterEnvelope.getMaxX()),
                    Math.max(shpBounds.getMinY(), rasterEnvelope.getMinY()),
                    Math.min(shpBounds.getMaxY(), rasterEnvelope.getMaxY()),
                    shpBounds.getCoordinateReferenceSystem()
                );
                
                if (!intersection.isEmpty()) {
                    GridCoverage2D fullGridCov = reader.read(null);
                    GridGeometry2D originalGeometry = fullGridCov.getGridGeometry();
                    
                    final ParameterValue<GridGeometry2D> gg = AbstractGridFormat.READ_GRIDGEOMETRY2D.createValue();
                    
                    GridGeometry2D simpleGeometry = new GridGeometry2D(
                        originalGeometry.getGridRange(),
                        originalGeometry.getGridToCRS(),
                        intersection.getCoordinateReferenceSystem()
                    );
                    
                    gg.setValue(simpleGeometry);
                    readParams = new GeneralParameterValue[] { gg };
                    
                    fullGridCov.dispose(true);
                    SFIToolkit.displayln("Successfully created optimized read parameters");
                }
            } catch (Exception e) {
                SFIToolkit.displayln("Warning: Could not create optimized read parameters, using full extent");
                readParams = null;
            }
        }
        
        return readParams;
    }

    private static MathTransform createOutputTransform(GridCoverage2D coverage, String targetEpsg) 
        throws Exception {
        if ("None".equalsIgnoreCase(targetEpsg)) return null;

        CoordinateReferenceSystem targetCRS;
        if (targetEpsg.toLowerCase().endsWith(".tif")) {
            targetCRS = readCRSFromGeoTIFF(targetEpsg);
        } else if (targetEpsg.toLowerCase().endsWith(".shp")) {
            targetCRS = readCRSFromShapefile(targetEpsg);
        } else if (targetEpsg.startsWith("EPSG:")) {
            targetCRS = CRS.decode(targetEpsg, true);
        } else {
            throw new IllegalArgumentException("Invalid CRS input: " + targetEpsg);
        }

        return CRS.findMathTransform(coverage.getCoordinateReferenceSystem(), targetCRS);
    }

    private static void processRegionsAndExtractValues(GridCoverage2D coverage, 
                                                     SimpleFeatureCollection featureCollection,
                                                     int bandIndex, MathTransform outputTransform,
                                                     String idField, String nameField,
                                                     boolean hasIdField, boolean hasNameField,
                                                     List<String> additionalAttrs) throws Exception {
        
        // Collect all features first - same pattern as gzonalstats
        List<SimpleFeature> allFeatures = new ArrayList<>();
        SimpleFeatureIterator featureIterator = featureCollection.features();
        try {
            while (featureIterator.hasNext()) {
                allFeatures.add(featureIterator.next());
            }
        } finally {
            featureIterator.close();
        }

        // Estimate total observations
        long estimatedObs = estimateTotalObservations(coverage, allFeatures);
        if (estimatedObs > MAX_OBS) {
            SFIToolkit.errorln("Estimated observations exceed maximum limit: " + estimatedObs);
            return;
        }

        // Get raster properties
        Raster raster = coverage.getRenderedImage().getData();
        GridGeometry2D gridGeometry = coverage.getGridGeometry();
        double noData = getNoDataValue(coverage, bandIndex);
        GeometryFactory geometryFactory = JTSFactoryFinder.getGeometryFactory();

        // Collect all pixel data first
        List<PixelData> allPixelData = new ArrayList<>();
        
        // Process each region
        for (SimpleFeature feature : allFeatures) {
            Geometry geometry = (Geometry) feature.getDefaultGeometry();
            if (geometry == null) continue;

            // Get region attributes
            String regionId = hasIdField ? getAttributeAsString(feature, idField) : feature.getID();
            String regionName = hasNameField ? getAttributeAsString(feature, nameField) : "";
            
            // Get additional attributes
            Map<String, Object> additionalValues = new HashMap<>();
            for (String attr : additionalAttrs) {
                additionalValues.put(attr, feature.getAttribute(attr));
            }

            // Get bounding box for this region
            Envelope envelope = geometry.getEnvelopeInternal();
            
            // Convert to grid coordinates
            Position2D minPos = new Position2D(envelope.getMinX(), envelope.getMinY());
            Position2D maxPos = new Position2D(envelope.getMaxX(), envelope.getMaxY());
            
            GridCoordinates2D minGrid = gridGeometry.worldToGrid(minPos);
            GridCoordinates2D maxGrid = gridGeometry.worldToGrid(maxPos);
            
            // Adjust bounds to raster limits
            int startRow = Math.max(0, Math.min(minGrid.y, maxGrid.y));
            int endRow = Math.min(raster.getHeight() - 1, Math.max(minGrid.y, maxGrid.y));
            int startCol = Math.max(0, Math.min(minGrid.x, maxGrid.x));
            int endCol = Math.min(raster.getWidth() - 1, Math.max(minGrid.x, maxGrid.x));
            
            // Create prepared geometry for efficient spatial queries
            PreparedGeometry preparedGeometry = PreparedGeometryFactory.prepare(geometry);
            
            // Extract pixels within this region
            for (int row = startRow; row <= endRow; row++) {
                for (int col = startCol; col <= endCol; col++) {
                    double value = raster.getSampleDouble(col, row, bandIndex);
                    if (isNoData(value, noData)) continue;
                    
                    // Convert to world coordinates
                    Position2D pos = new Position2D();
                    pos.setLocation(gridGeometry.gridToWorld(new GridCoordinates2D(col, row)));
                    
                    // Check if point is within geometry
                    Point point = geometryFactory.createPoint(new Coordinate(pos.getX(), pos.getY()));
                    if (preparedGeometry.contains(point)) {
                        // Apply output coordinate transform if needed
                        if (outputTransform != null) {
                            double[] src = {pos.getX(), pos.getY()};
                            double[] dst = new double[2];
                            outputTransform.transform(src, 0, dst, 0, 1);
                            pos.setLocation(dst[0], dst[1]);
                        }
                        
                        // Store pixel data
                        PixelData pixelData = new PixelData();
                        pixelData.x = pos.getX();
                        pixelData.y = pos.getY();
                        pixelData.value = value;
                        pixelData.regionId = regionId;
                        pixelData.regionName = regionName;
                        pixelData.additionalValues = additionalValues;
                        
                        allPixelData.add(pixelData);
                    }
                }
            }
        }

        // Now create Stata dataset - similar to gzonalstats variable creation
        int totalObs = allPixelData.size();
        SFIToolkit.displayln("Total observations to export: " + totalObs);
        
        if (totalObs == 0) {
            SFIToolkit.displayln("No pixels found within any region boundaries.");
            return;
        }

        Data.setObsTotal(totalObs);

        // Create variables in specific order
        Data.addVarDouble("x");
        Data.addVarDouble("y");
        Data.addVarDouble("value");
        Data.addVarStr("region_id", 50);
        Data.addVarStr("region_name", 100);

        // Create additional attribute variables
        Map<String, Integer> additionalVarMap = new HashMap<>();
        int varIndex = 6; // Starting after the 5 core variables
        
        for (String attr : additionalAttrs) {
            // Determine variable type based on first non-null value
            Object sampleValue = null;
            for (PixelData pd : allPixelData) {
                if (pd.additionalValues.containsKey(attr) && pd.additionalValues.get(attr) != null) {
                    sampleValue = pd.additionalValues.get(attr);
                    break;
                }
            }
            
            if (sampleValue instanceof Number) {
                Data.addVarDouble(attr);
            } else {
                Data.addVarStr(attr, 100);
            }
            additionalVarMap.put(attr, varIndex++);
        }

        // Fill data
        for (int i = 0; i < totalObs; i++) {
            PixelData pd = allPixelData.get(i);
            int stataObs = i + 1;
            
            Data.storeNumFast(1, stataObs, pd.x);
            Data.storeNumFast(2, stataObs, pd.y);
            Data.storeNumFast(3, stataObs, pd.value);
            Data.storeStr(4, stataObs, pd.regionId);
            Data.storeStr(5, stataObs, pd.regionName);
            
            // Store additional attributes
            for (String attr : additionalAttrs) {
                Object value = pd.additionalValues.get(attr);
                int varIdx = additionalVarMap.get(attr);
                
                if (value != null) {
                    if (value instanceof Number) {
                        Data.storeNumFast(varIdx, stataObs, ((Number) value).doubleValue());
                    } else {
                        Data.storeStr(varIdx, stataObs, value.toString());
                    }
                }
            }
        }

        Data.updateModified();
        SFIToolkit.displayln("Data successfully exported to Stata dataset.");
    }

    // Helper classes and methods
    private static class PixelData {
        double x, y, value;
        String regionId, regionName;
        Map<String, Object> additionalValues;
    }

    private static long estimateTotalObservations(GridCoverage2D coverage, List<SimpleFeature> features) {
        // Simple estimation based on total bounding box area
        return Math.min(1000000, features.size() * 1000); // Conservative estimate
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

    private static List<String> getAdditionalAttributes(SimpleFeatureSource featureSource, 
                                                       String idField, String nameField) {
        List<String> additionalAttrs = new ArrayList<>();
        for (AttributeDescriptor descriptor : featureSource.getSchema().getAttributeDescriptors()) {
            String attrName = descriptor.getLocalName();
            if (!attrName.equalsIgnoreCase(idField) && 
                !attrName.equalsIgnoreCase(nameField) &&
                !attrName.equals("the_geom") && 
                !attrName.equals("z_the_geom")) {
                additionalAttrs.add(attrName);
            }
        }
        return additionalAttrs;
    }

    private static double getNoDataValue(GridCoverage2D coverage, int bandIndex) {
        GridSampleDimension sampleDim = coverage.getSampleDimension(bandIndex);
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

    // CRS reading methods - same as original gtiffread
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