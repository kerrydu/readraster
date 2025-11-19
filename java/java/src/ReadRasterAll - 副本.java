package org.readraster;

// Consolidated single-file Java implementation extracted from Stata ADO java: blocks
// This class is placed in a named package to avoid classloader issues with default package in some environments.
// Public entry points remain the same; call with fully-qualified class name from Stata: org.readraster.ReadRasterAll

import java.awt.Transparency;
import java.awt.color.ColorSpace;
import java.awt.image.*;
import java.io.File;
import java.util.*;
import java.util.logging.ConsoleHandler;
import java.util.logging.Handler;
import java.util.logging.Level;
import java.util.logging.Logger;

// GeoTools API + Impl
import org.geotools.api.coverage.SampleDimension;
import org.geotools.api.coverage.grid.GridEnvelope;
import org.geotools.api.feature.simple.SimpleFeature;
import org.geotools.api.parameter.GeneralParameterValue;
import org.geotools.api.parameter.ParameterValue;
import org.geotools.api.referencing.crs.CoordinateReferenceSystem;
import org.geotools.coverage.GridSampleDimension;
import org.geotools.coverage.grid.GridCoverage2D;
import org.geotools.coverage.grid.GridGeometry2D;
import org.geotools.coverage.grid.GridCoverageFactory;
import org.geotools.coverage.grid.io.AbstractGridCoverage2DReader;
import org.geotools.coverage.grid.io.AbstractGridFormat;
import org.geotools.coverage.grid.io.GridCoverage2DReader;
import org.geotools.data.shapefile.ShapefileDataStore;
import org.geotools.data.shapefile.ShapefileDataStoreFactory;
import org.geotools.data.simple.SimpleFeatureCollection;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.store.ReprojectingFeatureCollection;
import org.geotools.gce.geotiff.GeoTiffReader;
import org.geotools.geometry.jts.ReferencedEnvelope;
import org.geotools.process.raster.RasterZonalStatistics;
import org.geotools.referencing.CRS;
import org.geotools.util.factory.Hints;

// (no Envelope imports needed; using ReferencedEnvelope from reader where necessary)

// NetCDF
import ucar.ma2.Array;
import ucar.ma2.Index;
import ucar.ma2.MAMath;
import ucar.nc2.Attribute;
import ucar.nc2.Variable;
import ucar.nc2.dataset.NetcdfDataset;
import ucar.nc2.dataset.NetcdfDatasets;

// Stata SFI
import com.stata.sfi.Data;
import com.stata.sfi.Scalar;
import com.stata.sfi.SFIToolkit;

// Referencing transform
import org.geotools.api.referencing.operation.MathTransform;
import org.geotools.api.referencing.operation.TransformException;
import org.geotools.geometry.Position2D;
import org.geotools.coverage.grid.GridCoordinates2D;

public class ReadRasterAll {
    // Global static initializer for GeoTools logging tweaks
    static {
        System.setProperty("org.geotools.referencing.forceXY", "true");
        // Do NOT hide legacy service implementations; some function providers (e.g., Length)
        // are registered via SPI that may be considered legacy. Keep them visible.
        System.setProperty("org.geotools.factory.hideLegacyServiceImplementations", "false");
        Logger logger = Logger.getLogger("org.geotools.util.factory");
        logger.setLevel(Level.SEVERE);
        Logger geoToolsLogger = Logger.getLogger("org.geotools");
        geoToolsLogger.setLevel(Level.WARNING);
        for (Handler handler : geoToolsLogger.getHandlers()) {
            if (handler instanceof ConsoleHandler) {
                handler.setLevel(Level.WARNING);
            }
        }
    }

    // Stata javacall-compatible entry point (dispatcher)
    // Usage examples:
    //   javacall ReadRasterAll mymethod zonalstatics shp.shp raster.tif 0 "avg sum" ""
    //   javacall ReadRasterAll mymethod nzonalstatics zones.shp data.nc var "avg" "" "" "EPSG:4326"
    //   javacall ReadRasterAll mymethod geotiffExport raster.tif 1 None 0 -1 0 -1
    //   javacall ReadRasterAll mymethod gtiffInfo raster.tif
    public static int mymethod(String[] args) {
        try {
            if (args == null || args.length < 1) {
                SFIToolkit.errorln("ReadRasterAll.mymethod: missing command. Supported: zonalstatics | nzonalstatics | geotiffExport | gtiffInfo");
                return 1;
            }
            // Support both styles:
            // 1) args array with tokens already split by Stata
            // 2) single string arg containing the whole command line (we split here, honoring quotes)
            List<String> tokens;
            if (args.length == 1) {
                tokens = splitArgsRespectQuotes(args[0]);
            } else {
                tokens = new ArrayList<>();
                for (String a : args) if (a != null) tokens.add(a);
            }

            // normalize tokens: trim and strip surrounding quotes
            if (!tokens.isEmpty()) {
                List<String> norm = new ArrayList<>(tokens.size());
                for (String t : tokens) {
                    if (t == null) continue;
                    String s = t.trim();
                    // strip surrounding or stray leading/trailing quotes
                    if (s.startsWith("\"")) s = s.substring(1);
                    if (s.endsWith("\"")) s = s.substring(0, s.length() - 1);
                    norm.add(s);
                }
                tokens = norm;
            }

            if (tokens.isEmpty()) {
                SFIToolkit.errorln("ReadRasterAll.mymethod: empty args");
                return 1;
            }

            String cmd = tokens.get(0).toLowerCase(Locale.ROOT);
            switch (cmd) {
                case "crsconvert": {
                    if (tokens.size() < 7) {
                        SFIToolkit.errorln("Usage: crsconvert <xVar> <yVar> <newXVar> <newYVar> <fromCRS> <toCRS>");
                        return 10;
                    }
                    String xVar = tokens.get(1);
                    String yVar = tokens.get(2);
                    String newXVar = tokens.get(3);
                    String newYVar = tokens.get(4);
                    String fromCRS = tokens.get(5);
                    String toCRS = tokens.get(6);
                    crsconvert(xVar, yVar, newXVar, newYVar, fromCRS, toCRS);
                    return 0;
                }
                case "zonalstatics": {
                    if (tokens.size() < 5) {
                        SFIToolkit.errorln("Usage: zonalstatics <shpPath> <tiffPath> <bandIndex> <stats> <userCrs>");
                        return 2;
                    }
                    String shpPath = tokens.get(1);
                    String tiffPath = tokens.get(2);
                    int bandIndex = Integer.parseInt(tokens.get(3));
                    String stats = tokens.get(4);
                    String userCrs = tokens.size() >= 6 ? tokens.get(5) : "";
                    zonalstatics(shpPath, tiffPath, bandIndex, stats, userCrs);
                    return 0;
                }
                case "nzonalstatics": {
                    if (tokens.size() < 5) {
                        SFIToolkit.errorln("Usage: nzonalstatics <shpPath> <ncPath> <varName> <stats> [origin] [size] [userCrs]");
                        return 3;
                    }
                    String shpPath = tokens.get(1);
                    String ncPath = tokens.get(2);
                    String varName = tokens.get(3);
                    String stats = tokens.get(4);
                    String origin = tokens.size() >= 6 ? tokens.get(5) : "";
                    String size = tokens.size() >= 7 ? tokens.get(6) : "";
                    String userCrs = tokens.size() >= 8 ? tokens.get(7) : "";
                    nzonalstatics(shpPath, ncPath, varName, stats, origin, size, userCrs);
                    return 0;
                }
                case "geotiffexport": {
                    if (tokens.size() < 8) {
                        SFIToolkit.errorln("Usage: geotiffExport <tiffPath> <bandIndex> <targetCrs|None> <startRow> <endRow> <startCol> <endCol>");
                        return 4;
                    }
                    String tiffPath = tokens.get(1);
                    int bandIndex = Integer.parseInt(tokens.get(2));
                    String targetCrs = tokens.get(3);
                    int startRow = Integer.parseInt(tokens.get(4));
                    int endRow = Integer.parseInt(tokens.get(5));
                    int startCol = Integer.parseInt(tokens.get(6));
                    int endCol = Integer.parseInt(tokens.get(7));
                    geotiffExport(tiffPath, bandIndex, targetCrs, startRow, endRow, startCol, endCol);
                    return 0;
                }
                case "gtiffinfo": {
                    if (tokens.size() < 2) {
                        SFIToolkit.errorln("Usage: gtiffInfo <tiffPath>");
                        return 5;
                    }
                    String tiffPath = tokens.get(1);
                    gtiffInfo(tiffPath);
                    return 0;
                }
                default:
                    SFIToolkit.errorln("Unknown command: " + tokens.get(0) + ". Supported: zonalstatics | nzonalstatics | geotiffExport | gtiffInfo");
                    return 6;
            }
        } catch (NumberFormatException nfe) {
            SFIToolkit.errorln("Invalid numeric argument: " + nfe.getMessage());
            return 7;
        } catch (Throwable t) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(t));
            return 99;
        }
    }

    // Alias to satisfy alternative naming expectations in examples
    public static int method1(String[] args) {
        return mymethod(args);
    }

    // Split a single raw argument string into tokens, keeping quoted segments intact
    private static List<String> splitArgsRespectQuotes(String raw) {
        List<String> out = new ArrayList<>();
        if (raw == null) return out;
        StringBuilder cur = new StringBuilder();
        boolean inQuotes = false;
        for (int i = 0; i < raw.length(); i++) {
            char c = raw.charAt(i);
            if (c == '"') {
                inQuotes = !inQuotes;
            } else if (Character.isWhitespace(c) && !inQuotes) {
                if (cur.length() > 0) { out.add(cur.toString()); cur.setLength(0); }
            } else {
                cur.append(c);
            }
        }
        if (cur.length() > 0) out.add(cur.toString());
        return out;
    }

    // ----------------------- Public entry points (to match original calls) -----------------------

    // From gzonalstats_core.ado: zonalstatics.main(String shp, String tiff, int band, String stats, String userCrs)
    public static void zonalstatics(String shpPath, String tiffPath, int bandIndex, String statsParam, String userCrs) throws Exception {
        new ZonalStaticsImpl().run(shpPath, tiffPath, bandIndex, statsParam, userCrs);
    }

    // From nzonalstats_core.ado: nzonalstatics.main(String shp, String nc, String var, String stats, String origin, String size, String userCrs)
    public static void nzonalstatics(String shpPath, String ncPath, String varName, String statsParam,
                                     String originParam, String sizeParam, String userCrs) throws Exception {
        new NZonalStaticsImpl().run(shpPath, ncPath, varName, statsParam, originParam, sizeParam, userCrs);
    }

    // From gtiffread_core.ado: GeoTiff.exportToStata(...)
    public static void geotiffExport(String geotiffPath, int bandIndex, String targetCrs,
                                     int startRow, int endRow, int startCol, int endCol) throws Exception {
        new GeoTiffExportImpl().exportToStata(geotiffPath, bandIndex, targetCrs, startRow, endRow, startCol, endCol);
    }

    // From gtiffdisp_core.ado: GtiffReader.info(String path)
    public static void gtiffInfo(String filePath) {
        GtiffInfoImpl.info(filePath);
    }

    // ----------------------- Implementations (migrated from ADO java: blocks) -----------------------

    // crsconvert_core.ado implementation (transform Stata vars between CRSs)
    public static void crsconvert(String xVar, String yVar, String newXVar, String newYVar, String fromCRS, String toCRS) throws Exception {
        CRS.reset("all");
        CoordinateReferenceSystem source = parseCRSGeneral(fromCRS);
        CoordinateReferenceSystem target = parseCRSGeneral(toCRS);
        MathTransform transform = CRS.findMathTransform(source, target, true);

        int xIdx = Data.getVarIndex(xVar);
        int yIdx = Data.getVarIndex(yVar);
        int nxIdx = Data.getVarIndex(newXVar);
        int nyIdx = Data.getVarIndex(newYVar);
        long total = Data.getObsTotal();
        double[] src = new double[2];
        double[] dst = new double[2];
        for (int i = 1; i <= total; i++) {
            try {
                src[0] = Data.getNum(xIdx, i);
                src[1] = Data.getNum(yIdx, i);
                transform.transform(src, 0, dst, 0, 1);
                Data.storeNumFast(nxIdx, i, dst[0]);
                Data.storeNumFast(nyIdx, i, dst[1]);
            } catch (Exception ex) {
                SFIToolkit.error("crsconvert error at obs " + i + ": " + ex.getMessage());
            }
        }
        Data.updateModified();
    }

    // Helper: parse CRS from EPSG, file (.tif/.tiff/.shp/.nc), or WKT
    private static CoordinateReferenceSystem parseCRSGeneral(String input) throws Exception {
        if (input == null) throw new IllegalArgumentException("CRS input is null");
        String s = input.trim();
        String lower = s.toLowerCase(Locale.ROOT);
        if (lower.startsWith("epsg:")) return CRS.decode(s, true);
        if (lower.endsWith(".tif") || lower.endsWith(".tiff")) return readCRSFromGeoTIFFFile(s);
        if (lower.endsWith(".shp")) return readCRSFromShapefileFile(s);
        if (lower.endsWith(".nc")) {
            CoordinateReferenceSystem crs = readCRSFromNetCDFFile(s);
            if (crs != null) return crs;
            throw new IllegalArgumentException("No CRS found in NetCDF: " + s);
        }
        // Fallback to WKT
        return CRS.parseWKT(s);
    }

    private static CoordinateReferenceSystem readCRSFromGeoTIFFFile(String filePath) throws Exception {
        GeoTiffReader reader = null;
        try { reader = new GeoTiffReader(new File(filePath)); return reader.getCoordinateReferenceSystem(); }
        finally { if (reader != null) reader.dispose(); }
    }

    private static CoordinateReferenceSystem readCRSFromShapefileFile(String filePath) throws Exception {
        ShapefileDataStore shapefileDataStore = null;
        try {
            File shpFile = new File(filePath);
            if (!shpFile.exists()) throw new Exception("Shapefile does not exist: " + filePath);
            String basePath = filePath.substring(0, filePath.lastIndexOf('.'));
            if (!new File(basePath + ".shx").exists() || !new File(basePath + ".dbf").exists())
                throw new Exception("Incomplete shapefile: " + filePath);
            ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
            Map<String, Object> shpParams = new HashMap<>();
            shpParams.put("url", shpFile.toURI().toURL());
            shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);
            shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));
            CoordinateReferenceSystem crs = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
            if (crs == null) throw new Exception("CRS is null for Shapefile: " + filePath);
            return crs;
        } finally { if (shapefileDataStore != null) shapefileDataStore.dispose(); }
    }

    private static CoordinateReferenceSystem readCRSFromNetCDFFile(String filePath) {
        ucar.nc2.dataset.NetcdfDataset ncFile = null;
        try {
            File nc = new File(filePath);
            if (!nc.exists()) return null;
            ncFile = NetcdfDatasets.openDataset(filePath);
            Attribute crsAttr = ncFile.findGlobalAttribute("crs_wkt");
            if (crsAttr != null) return CRS.parseWKT(crsAttr.getStringValue());
            crsAttr = ncFile.findGlobalAttribute("spatial_ref");
            if (crsAttr != null) return CRS.parseWKT(crsAttr.getStringValue());
            Attribute epsgAttr = ncFile.findGlobalAttribute("epsg_code");
            if (epsgAttr != null) return CRS.decode("EPSG:" + epsgAttr.getNumericValue().intValue(), true);
            for (ucar.nc2.Variable var : ncFile.getVariables()) {
                crsAttr = var.findAttribute("crs_wkt"); if (crsAttr != null) return CRS.parseWKT(crsAttr.getStringValue());
                crsAttr = var.findAttribute("spatial_ref"); if (crsAttr != null) return CRS.parseWKT(crsAttr.getStringValue());
                epsgAttr = var.findAttribute("epsg_code"); if (epsgAttr != null) return CRS.decode("EPSG:" + epsgAttr.getNumericValue().intValue(), true);
            }
        } catch (Exception e) {
            System.out.println("Warning: Could not parse CRS from NetCDF: " + e.getMessage());
        } finally {
            if (ncFile != null) try { ncFile.close(); } catch (Exception ignore) {}
        }
        return null;
    }

    // gzonalstats_core.ado implementation
    static class ZonalStaticsImpl {
        public void run(String shpPath, String tiffPath, int bandIndex, String statsParam, String userCrs) throws Exception {
            ShapefileDataStore shapefileDataStore = null;
            AbstractGridCoverage2DReader reader = null;
            SimpleFeatureIterator featureIterator = null;
            SimpleFeatureCollection featureCollection = null;

            try {
                Logger.getGlobal().setLevel(Level.SEVERE);

                String[] requestedStats = statsParam == null ? new String[0] : statsParam.toLowerCase().split("\\s+");
                boolean showCount = false, showAvg = false, showMin = false, showMax = false, showStd = false, showSum = false;
                for (String stat : requestedStats) {
                    switch (stat.trim()) {
                        case "count": showCount = true; break;
                        case "avg": showAvg = true; break;
                        case "min": showMin = true; break;
                        case "max": showMax = true; break;
                        case "std": showStd = true; break;
                        case "sum": showSum = true; break;
                    }
                }

                File shpFile = new File(shpPath);
                if (!shpFile.exists()) { System.out.println("Shapefile does not exist: " + shpPath); return; }
                String basePath = shpPath.substring(0, shpPath.lastIndexOf('.'));
                if (!new File(basePath + ".shx").exists() || !new File(basePath + ".dbf").exists() || !new File(basePath + ".prj").exists()) {
                    System.out.println("Warning: Missing required shapefile components. .shx/.dbf/.prj are required.");
                    return;
                }

                ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
                Map<String, Object> shpParams = new HashMap<>();
                shpParams.put("url", shpFile.toURI().toURL());
                shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);
                shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));
                featureCollection = shapefileDataStore.getFeatureSource().getFeatures();

                File tiffFile = new File(tiffPath);
                if (!tiffFile.exists()) { System.out.println("GeoTIFF file does not exist: " + tiffPath); return; }

                reader = new GeoTiffReader(tiffFile);

                CoordinateReferenceSystem rasterCRS = reader.getCoordinateReferenceSystem();
                String rasterCRSName;
                if (rasterCRS != null) {
                    rasterCRSName = rasterCRS.getName().toString();
                    System.out.println("GeoTIFF CRS detected: " + rasterCRSName + ". User-provided CRS is ignored.");
                } else {
                    if (userCrs != null && !userCrs.trim().isEmpty()) {
                        System.out.println("GeoTIFF CRS not detected. Using user-provided CRS: " + userCrs);
                        rasterCRS = CRS.decode(userCrs, true);
                        rasterCRSName = rasterCRS.getName().toString();
                    } else {
                        System.out.println("Error: GeoTIFF file has no CRS and no CRS provided.");
                        return;
                    }
                }

                CoordinateReferenceSystem vectorCRS = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
                String vectorCRSName = vectorCRS.getName().toString();
                System.out.println("Shapefile CRS: " + vectorCRSName);

                boolean needsReprojection = !CRS.equalsIgnoreMetadata(rasterCRS, vectorCRS);
                if (needsReprojection) {
                    System.out.println("Reprojecting shapefile from " + vectorCRSName + " to " + rasterCRSName);
                    featureCollection = new ReprojectingFeatureCollection(featureCollection, rasterCRS);
                } else {
                    System.out.println("Coordinate systems are compatible, no reprojection needed");
                }

                ReferencedEnvelope shpBounds = featureCollection.getBounds();
                System.out.println("Shapefile bounds for raster reading: " + shpBounds);

                GeneralParameterValue[] readParams = null;
                if (shpBounds != null && !shpBounds.isEmpty()) {
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

                        if (intersection.isEmpty()) {
                            System.out.println("Warning: Shapefile bounds do not overlap with raster extent! Using full raster extent.");
                        } else {
                            GridCoverage2D fullGridCov = reader.read((GeneralParameterValue[]) null);
                            GridGeometry2D originalGeometry = fullGridCov.getGridGeometry();
                            final ParameterValue<GridGeometry2D> gg = AbstractGridFormat.READ_GRIDGEOMETRY2D.createValue();
                            GridGeometry2D simpleGeometry = new GridGeometry2D(
                                    originalGeometry.getGridRange(),
                                    originalGeometry.getGridToCRS(),
                                    intersection.getCoordinateReferenceSystem()
                            );
                            gg.setValue(simpleGeometry);
                            readParams = new GeneralParameterValue[]{gg};
                            fullGridCov.dispose(true);
                            System.out.println("Successfully created optimized read parameters");
                        }
                    } catch (Exception e) {
                        System.out.println("Warning: Could not create optimized read parameters: " + e.getMessage());
                        e.printStackTrace();
                        readParams = null;
                    }
                }

                GridCoverage2D coverage;
                try {
                    coverage = reader.read(readParams);
                    System.out.println("Successfully read raster data" + (readParams != null ? " with optimization" : " (full extent)"));
                } catch (Exception e) {
                    System.out.println("Error reading raster with optimized parameters: " + e.getMessage());
                    System.out.println("Falling back to reading the entire raster");
                    coverage = reader.read((GeneralParameterValue[]) null);
                }

                if (coverage == null) { System.out.println("Failed to read raster data. Aborting."); return; }

                int numBands = coverage.getNumSampleDimensions();
                if (bandIndex >= numBands || bandIndex < 0) {
                    System.out.println("Specified band index is out of range, current index: " + bandIndex + ", total bands: " + numBands);
                    return;
                }

                RasterZonalStatistics process = new RasterZonalStatistics();
                SimpleFeatureCollection resultFeatures = process.execute(coverage, bandIndex, featureCollection, null);

                List<SimpleFeature> allFeatures = new ArrayList<>();
                featureIterator = resultFeatures.features();
                try { while (featureIterator.hasNext()) allFeatures.add(featureIterator.next()); }
                finally { if (featureIterator != null) featureIterator.close(); }

                int totalFeatures = allFeatures.size();
                System.out.println("Total features: " + totalFeatures);
                if (totalFeatures <= 0) { System.out.println("No features found in the result set."); return; }

                Map<String, Integer> attributeNameMap = new HashMap<>();
                List<String> idAttrNames = new ArrayList<>();
                String countAttrName = null, avgAttrName = null, minAttrName = null, maxAttrName = null, stddevAttrName = null, sumAttrName = null;

                SimpleFeature firstFeature = allFeatures.get(0);
                for (int i = 0; i < firstFeature.getType().getAttributeCount(); i++) {
                    String attributeName = firstFeature.getType().getDescriptor(i).getLocalName();
                    if ("count".equals(attributeName)) { if (showCount) countAttrName = attributeName; }
                    else if ("avg".equals(attributeName)) { if (showAvg) avgAttrName = attributeName; }
                    else if ("min".equals(attributeName)) { if (showMin) minAttrName = attributeName; }
                    else if ("max".equals(attributeName)) { if (showMax) maxAttrName = attributeName; }
                    else if ("stddev".equals(attributeName)) { if (showStd) stddevAttrName = attributeName; }
                    else if ("sum".equals(attributeName)) { if (showSum) sumAttrName = attributeName; }
                    else if (!"the_geom".equals(attributeName) && !"z_the_geom".equals(attributeName) && !"sum_2".equals(attributeName)) {
                        idAttrNames.add(attributeName);
                    }
                }

                Data.setObsTotal(totalFeatures);
                int varIndex = 1;
                for (String idAttr : idAttrNames) {
                    Object value = firstFeature.getAttribute(idAttr);
                    if (value instanceof Number) { Data.addVarDouble(idAttr); }
                    else {
                        int strLength = 32;
                        if (value != null) {
                            String strValue = value.toString();
                            if (strValue.length() <= 16) strLength = 16;
                            else if (strValue.length() <= 32) strLength = 32;
                            else if (strValue.length() <= 48) strLength = 48;
                        }
                        Data.addVarStr(idAttr, strLength);
                    }
                    attributeNameMap.put(idAttr, varIndex++);
                }

                if (showCount && countAttrName != null) { Data.addVarDouble("count"); attributeNameMap.put(countAttrName, varIndex++); }
                if (showAvg && avgAttrName != null) { Data.addVarDouble("avg"); attributeNameMap.put(avgAttrName, varIndex++); }
                if (showMin && minAttrName != null) { Data.addVarDouble("min"); attributeNameMap.put(minAttrName, varIndex++); }
                if (showMax && maxAttrName != null) { Data.addVarDouble("max"); attributeNameMap.put(maxAttrName, varIndex++); }
                if (showStd && stddevAttrName != null) { Data.addVarDouble("std"); attributeNameMap.put(stddevAttrName, varIndex++); }
                if (showSum && sumAttrName != null) { Data.addVarDouble("sum"); attributeNameMap.put(sumAttrName, varIndex++); }

                for (int i = 0; i < totalFeatures; i++) {
                    SimpleFeature feature = allFeatures.get(i);
                    int stataObs = i + 1;
                    for (String idAttr : idAttrNames) {
                        Object value = feature.getAttribute(idAttr);
                        int stataVar = attributeNameMap.get(idAttr);
                        if (value != null) {
                            if (value instanceof Number) Data.storeNumFast(stataVar, stataObs, ((Number) value).doubleValue());
                            else Data.storeStr(stataVar, stataObs, value.toString());
                        }
                    }
                    if (showCount && countAttrName != null) { Object v = feature.getAttribute(countAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(countAttrName), stataObs, ((Number) v).doubleValue()); }
                    if (showAvg && avgAttrName != null) { Object v = feature.getAttribute(avgAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(avgAttrName), stataObs, ((Number) v).doubleValue()); }
                    if (showMin && minAttrName != null) { Object v = feature.getAttribute(minAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(minAttrName), stataObs, ((Number) v).doubleValue()); }
                    if (showMax && maxAttrName != null) { Object v = feature.getAttribute(maxAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(maxAttrName), stataObs, ((Number) v).doubleValue()); }
                    if (showStd && stddevAttrName != null) { Object v = feature.getAttribute(stddevAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(stddevAttrName), stataObs, ((Number) v).doubleValue()); }
                    if (showSum && sumAttrName != null) { Object v = feature.getAttribute(sumAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(sumAttrName), stataObs, ((Number) v).doubleValue()); }
                }

                Data.updateModified();
                System.out.println("Data successfully exported to Stata dataset.");

            } catch (Exception e) {
                System.out.println("Error in zonalstatics: " + e.getMessage());
                e.printStackTrace();
            } finally {
                try {
                    if (featureIterator != null) featureIterator.close();
                    if (reader != null) reader.dispose();
                    if (shapefileDataStore != null) shapefileDataStore.dispose();
                    System.gc();
                } catch (Exception e) {
                    System.out.println("Error closing resources: " + e.getMessage());
                    e.printStackTrace();
                }
            }
        }
    }

    // nzonalstats_core.ado implementation
    static class NZonalStaticsImpl {
        private BufferedImage floatArrayToImage(float[][] data) {
            int height = data.length;
            int width = data[0].length;
            float[] flat = new float[width * height];
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    flat[y * width + x] = data[height - 1 - y][x];
                }
            }
            DataBuffer db = new DataBufferFloat(flat, flat.length);
            int bands = 1;
            int[] bandOffsets = {0};
            SampleModel sm = new PixelInterleavedSampleModel(DataBuffer.TYPE_FLOAT, width, height, bands, width * bands, bandOffsets);
            WritableRaster raster = Raster.createWritableRaster(sm, db, null);
            ColorSpace cs = ColorSpace.getInstance(ColorSpace.CS_GRAY);
            boolean hasAlpha = false;
            boolean isAlphaPremultiplied = false;
            int transparency = Transparency.OPAQUE;
            int transferType = DataBuffer.TYPE_FLOAT;
            int[] nBits = {32};
            ColorModel cm = new ComponentColorModel(cs, nBits, hasAlpha, isAlphaPremultiplied, transparency, transferType);
            return new BufferedImage(cm, raster, false, null);
        }

        public void run(String shpPath, String ncPath, String varName, String statsParam,
                        String originParam, String sizeParam, String userCrs) throws Exception {
            ShapefileDataStore shapefileDataStore = null;
            NetcdfDataset ncFile = null;
            SimpleFeatureIterator featureIterator = null;
            SimpleFeatureCollection featureCollection = null;
            GridCoverage2D coverage = null;

            int[] origin = null; int[] size = null;
            if (originParam != null && !originParam.isEmpty()) {
                String[] originStrings = originParam.split("[,\\s]+");
                origin = new int[originStrings.length];
                for (int i = 0; i < originStrings.length; i++) origin[i] = Integer.parseInt(originStrings[i]);
            }
            if (sizeParam != null && !sizeParam.isEmpty()) {
                String[] sizeStrings = sizeParam.split("[,\\s]+");
                size = new int[sizeStrings.length];
                for (int i = 0; i < sizeStrings.length; i++) size[i] = Integer.parseInt(sizeStrings[i]);
            }

            try {
                Logger.getGlobal().setLevel(Level.SEVERE);

                String[] requestedStats = statsParam == null ? new String[0] : statsParam.toLowerCase().split("\\s+");
                boolean showCount = false, showAvg = false, showMin = false, showMax = false, showStd = false, showSum = false;
                for (String stat : requestedStats) {
                    switch (stat.trim()) {
                        case "count": showCount = true; break;
                        case "avg": showAvg = true; break;
                        case "min": showMin = true; break;
                        case "max": showMax = true; break;
                        case "std": showStd = true; break;
                        case "sum": showSum = true; break;
                    }
                }

                File shpFile = new File(shpPath);
                if (!shpFile.exists()) { System.out.println("Shapefile does not exist: " + shpPath); return; }
                String basePath = shpPath.substring(0, shpPath.lastIndexOf('.'));
                if (!new File(basePath + ".shx").exists() || !new File(basePath + ".dbf").exists() || !new File(basePath + ".prj").exists()) {
                    System.out.println("Warning: Missing required shapefile components. .shx/.dbf/.prj are required.");
                    return;
                }

                ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
                Map<String, Object> shpParams = new HashMap<>();
                shpParams.put("url", shpFile.toURI().toURL());
                shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);
                shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));
                featureCollection = shapefileDataStore.getFeatureSource().getFeatures();

                try { ncFile = NetcdfDatasets.openDataset(ncPath); }
                catch (Exception e) { System.out.println("NetCDF file cannot be opened: " + ncPath); e.printStackTrace(); return; }

                Variable ncVar = ncFile.findVariable(varName);
                if (ncVar == null) { System.out.println("Variable '" + varName + "' not found in NetCDF file"); return; }

                List<ucar.nc2.Dimension> dimensions = ncVar.getDimensions();
                int numDims = dimensions.size();
                if (numDims < 2) { System.out.println("Variable '" + varName + "' has " + numDims + " dimensions. Must have at least 2 dimensions."); return; }

                System.out.println("NetCDF variable '" + varName + "' type: " + ncVar.getDataType().toString());

                Attribute fillAttr = ncVar.findAttribute("_FillValue");
                if (fillAttr == null) fillAttr = ncVar.findAttribute("missing_value");
                if (fillAttr != null) System.out.println("NetCDF variable '" + varName + "' missing value attribute: " + fillAttr.getNumericValue() + " (type: " + fillAttr.getDataType() + ")");
                else System.out.println("NetCDF variable '" + varName + "' has no _FillValue or missing_value attribute.");

                Array dataArray;
                if (origin != null && size != null && origin.length == size.length && origin.length == dimensions.size()) dataArray = ncVar.read(origin, size);
                else dataArray = ncVar.read();

                int[] actualShape = dataArray.getShape();
                int actualDims = actualShape.length;
                int yDim = -1, xDim = -1;
                List<Integer> spatialDims = new ArrayList<>();
                for (int i = 0; i < actualDims; i++) if (actualShape[i] > 1) spatialDims.add(i);
                if (spatialDims.size() < 2) { System.out.println("Error: Need at least 2 spatial dimensions with size > 1"); return; }
                yDim = spatialDims.get(spatialDims.size() - 2);
                xDim = spatialDims.get(spatialDims.size() - 1);

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
                    if (lonVar == null && ("longitude".equals(stdName) || "X".equalsIgnoreCase(axis) || units.contains("degrees_east") || name.contains("lon") || name.equals("x") || name.contains("long"))) lonVar = v;
                    if (latVar == null && ("latitude".equals(stdName) || "Y".equalsIgnoreCase(axis) || units.contains("degrees_north") || name.contains("lat") || name.equals("y"))) latVar = v;
                }
                if (lonVar == null || latVar == null) { System.out.println("Unable to automatically identify longitude/latitude variables, please check the NetCDF file!"); return; }

                Array lonSlice, latSlice;
                if (origin != null && size != null) {
                    int[] lonStart = new int[]{origin[xDim]};
                    int[] lonSize = new int[]{size[xDim]};
                    lonSlice = lonVar.read(lonStart, lonSize);
                    int[] latStart = new int[]{origin[yDim]};
                    int[] latSize = new int[]{size[yDim]};
                    latSlice = latVar.read(latStart, latSize);
                } else {
                    lonSlice = lonVar.read();
                    latSlice = latVar.read();
                }

                double lonRes = (lonSlice.getSize() > 1) ? Math.abs(lonSlice.getDouble(1) - lonSlice.getDouble(0)) : 0.0;
                double latRes = (latSlice.getSize() > 1) ? Math.abs(latSlice.getDouble(1) - latSlice.getDouble(0)) : 0.0;
                double minLonEdge = lonSlice.getDouble(0) - lonRes / 2.0;
                double maxLonEdge = lonSlice.getDouble((int) lonSlice.getSize() - 1) + lonRes / 2.0;
                double minLatEdge = latSlice.getDouble(0) - latRes / 2.0;
                double maxLatEdge = latSlice.getDouble((int) latSlice.getSize() - 1) + latRes / 2.0;

                ReferencedEnvelope actualEnvelope = new ReferencedEnvelope(minLonEdge, maxLonEdge, minLatEdge, maxLatEdge, ncCRS);
                ReferencedEnvelope shpBounds = featureCollection.getBounds();

                int height = (int) latSlice.getSize();
                int width = (int) lonSlice.getSize();
                float[][] gridData = new float[height][width];
                Index index = dataArray.getIndex();

                boolean isDouble = ncVar.getDataType().isFloatingPoint() && ncVar.getDataType().toString().equalsIgnoreCase("double");
                double fillValueDouble = Double.NaN; float fillValueFloat = Float.NaN;
                if (fillAttr != null) {
                    if (isDouble) fillValueDouble = fillAttr.getNumericValue().doubleValue();
                    else fillValueFloat = fillAttr.getNumericValue().floatValue();
                }

                int[] actualShape2 = dataArray.getShape();
                int actualDims2 = actualShape2.length;
                List<Integer> spatialDims2 = new ArrayList<>();
                for (int i = 0; i < actualDims2; i++) if (actualShape2[i] > 1) spatialDims2.add(i);
                if (spatialDims2.size() < 2) { System.out.println("Error: Need at least 2 spatial dimensions with size > 1"); return; }
                int yDim2 = spatialDims2.get(spatialDims2.size() - 2);
                int xDim2 = spatialDims2.get(spatialDims2.size() - 1);
                int height2 = actualShape2[yDim2];
                int width2 = actualShape2[xDim2];
                int[] indices = new int[actualDims2];

                for (int y = 0; y < height2; y++) {
                    for (int x = 0; x < width2; x++) {
                        indices[yDim2] = y; indices[xDim2] = x;
                        for (int d = 0; d < actualDims2; d++) index.setDim(d, indices[d]);
                        float value;
                        if (isDouble) {
                            double dval = dataArray.getDouble(index);
                            boolean isMissing = !Double.isNaN(fillValueDouble) && Double.compare(dval, fillValueDouble) == 0;
                            if (!isMissing && fillAttr == null && Double.isNaN(dval)) isMissing = true;
                            value = isMissing ? Float.NaN : (float) dval;
                        } else {
                            float fval = dataArray.getFloat(index);
                            boolean isMissing = !Float.isNaN(fillValueFloat) && Float.compare(fval, fillValueFloat) == 0;
                            if (!isMissing && fillAttr == null && Float.isNaN(fval)) isMissing = true;
                            value = isMissing ? Float.NaN : fval;
                        }
                        gridData[y][x] = value;
                    }
                }

                GridCoverageFactory factory = new GridCoverageFactory();
                GridSampleDimension[] bands = new GridSampleDimension[]{new GridSampleDimension(varName)};
                BufferedImage image = floatArrayToImage(gridData);
                coverage = factory.create(varName, image, actualEnvelope, bands, null, null);

                CoordinateReferenceSystem rasterCRS = ncCRS; String rasterCRSName = rasterCRS.getName().toString();
                CoordinateReferenceSystem vectorCRS = shapefileDataStore.getSchema().getCoordinateReferenceSystem(); String vectorCRSName = vectorCRS.getName().toString();
                boolean needsReprojection = !CRS.equalsIgnoreMetadata(rasterCRS, vectorCRS);
                if (needsReprojection) {
                    System.out.println("Reprojecting shapefile from " + vectorCRSName + " to " + rasterCRSName);
                    featureCollection = new ReprojectingFeatureCollection(featureCollection, rasterCRS);
                } else { System.out.println("Coordinate systems are compatible, no reprojection needed"); }

                RasterZonalStatistics process = new RasterZonalStatistics();
                SimpleFeatureCollection resultFeatures = process.execute(coverage, 0, featureCollection, null);

                List<SimpleFeature> allFeatures = new ArrayList<>();
                featureIterator = resultFeatures.features();
                try { while (featureIterator.hasNext()) allFeatures.add(featureIterator.next()); }
                finally { if (featureIterator != null) featureIterator.close(); }

                int totalFeatures = allFeatures.size();
                if (totalFeatures <= 0) { System.out.println("No features found in the result set."); return; }

                Map<String, Integer> attributeNameMap = new HashMap<>();
                List<String> idAttrNames = new ArrayList<>();
                String countAttrName = null, avgAttrName = null, minAttrName = null, maxAttrName = null, stddevAttrName = null, sumAttrName = null;
                SimpleFeature firstFeature = allFeatures.get(0);
                for (int i = 0; i < firstFeature.getType().getAttributeCount(); i++) {
                    String attributeName = firstFeature.getType().getDescriptor(i).getLocalName();
                    if ("count".equals(attributeName)) { if (showCount) countAttrName = attributeName; }
                    else if ("avg".equals(attributeName)) { if (showAvg) avgAttrName = attributeName; }
                    else if ("min".equals(attributeName)) { if (showMin) minAttrName = attributeName; }
                    else if ("max".equals(attributeName)) { if (showMax) maxAttrName = attributeName; }
                    else if ("stddev".equals(attributeName)) { if (showStd) stddevAttrName = attributeName; }
                    else if ("sum".equals(attributeName)) { if (showSum) sumAttrName = attributeName; }
                    else if (!"the_geom".equals(attributeName) && !"z_the_geom".equals(attributeName) && !"sum_2".equals(attributeName)) { idAttrNames.add(attributeName); }
                }

                Data.setObsTotal(totalFeatures);
                int varIndex = 1;
                for (String idAttr : idAttrNames) {
                    Object value = firstFeature.getAttribute(idAttr);
                    if (value instanceof Number) { Data.addVarDouble(idAttr); }
                    else {
                        int strLength = 32;
                        if (value != null) {
                            String strValue = value.toString();
                            if (strValue.length() <= 16) strLength = 16; else if (strValue.length() <= 32) strLength = 32; else if (strValue.length() <= 48) strLength = 48;
                        }
                        Data.addVarStr(idAttr, strLength);
                    }
                    attributeNameMap.put(idAttr, varIndex++);
                }
                if (showCount && countAttrName != null) { Data.addVarDouble("count"); attributeNameMap.put(countAttrName, varIndex++); }
                if (showAvg && avgAttrName != null) { Data.addVarDouble("avg"); attributeNameMap.put(avgAttrName, varIndex++); }
                if (showMin && minAttrName != null) { Data.addVarDouble("min"); attributeNameMap.put(minAttrName, varIndex++); }
                if (showMax && maxAttrName != null) { Data.addVarDouble("max"); attributeNameMap.put(maxAttrName, varIndex++); }
                if (showStd && stddevAttrName != null) { Data.addVarDouble("std"); attributeNameMap.put(stddevAttrName, varIndex++); }
                if (showSum && sumAttrName != null) { Data.addVarDouble("sum"); attributeNameMap.put(sumAttrName, varIndex++); }

                for (int i = 0; i < totalFeatures; i++) {
                    SimpleFeature feature = allFeatures.get(i);
                    int stataObs = i + 1;
                    for (String idAttr : idAttrNames) {
                        Object value = feature.getAttribute(idAttr);
                        int stataVar = attributeNameMap.get(idAttr);
                        if (value != null) {
                            if (value instanceof Number) Data.storeNumFast(stataVar, stataObs, ((Number) value).doubleValue()); else Data.storeStr(stataVar, stataObs, value.toString());
                        }
                    }
                    if (showCount && countAttrName != null) { Object v = feature.getAttribute(countAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(countAttrName), stataObs, ((Number) v).doubleValue()); }
                    if (showAvg && avgAttrName != null) { Object v = feature.getAttribute(avgAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(avgAttrName), stataObs, ((Number) v).doubleValue()); }
                    if (showMin && minAttrName != null) { Object v = feature.getAttribute(minAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(minAttrName), stataObs, ((Number) v).doubleValue()); }
                    if (showMax && maxAttrName != null) { Object v = feature.getAttribute(maxAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(maxAttrName), stataObs, ((Number) v).doubleValue()); }
                    if (showStd && stddevAttrName != null) { Object v = feature.getAttribute(stddevAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(stddevAttrName), stataObs, ((Number) v).doubleValue()); }
                    if (showSum && sumAttrName != null) { Object v = feature.getAttribute(sumAttrName); if (v != null) Data.storeNumFast(attributeNameMap.get(sumAttrName), stataObs, ((Number) v).doubleValue()); }
                }

                Data.updateModified();
                System.out.println("Data successfully exported to Stata dataset.");

            } catch (Exception e) {
                System.out.println("Error in nzonalstatics: " + e.getMessage()); e.printStackTrace();
            } finally {
                try {
                    if (featureIterator != null) featureIterator.close();
                    if (ncFile != null) ncFile.close();
                    if (shapefileDataStore != null) shapefileDataStore.dispose();
                    if (coverage != null) coverage.dispose(true);
                    System.gc();
                } catch (Exception e) {
                    System.out.println("Error closing resources: " + e.getMessage()); e.printStackTrace();
                }
            }
        }

        private CoordinateReferenceSystem extractCRSFromNetCDF(NetcdfDataset ncFile, Variable var) {
            try {
                Attribute crsAttr = ncFile.findGlobalAttribute("crs_wkt");
                if (crsAttr != null) return CRS.parseWKT(crsAttr.getStringValue());
                crsAttr = ncFile.findGlobalAttribute("spatial_ref");
                if (crsAttr != null) return CRS.parseWKT(crsAttr.getStringValue());
                Attribute epsgAttr = ncFile.findGlobalAttribute("epsg_code");
                if (epsgAttr != null) return CRS.decode("EPSG:" + epsgAttr.getNumericValue().intValue(), true);
                crsAttr = var.findAttribute("crs_wkt"); if (crsAttr != null) return CRS.parseWKT(crsAttr.getStringValue());
                crsAttr = var.findAttribute("spatial_ref"); if (crsAttr != null) return CRS.parseWKT(crsAttr.getStringValue());
                epsgAttr = var.findAttribute("epsg_code"); if (epsgAttr != null) return CRS.decode("EPSG:" + epsgAttr.getNumericValue().intValue(), true);
            } catch (Exception e) { System.out.println("Warning: Could not parse CRS from NetCDF: " + e.getMessage()); }
            return null;
        }
    }

    // gtiffread_core.ado implementation (export pixels to Stata)
    static class GeoTiffExportImpl {
        private static final int MAX_OBS = 1_000_000_000; // safety cap

        public void exportToStata(String geotiffPath, int bandIndex, String targetEpsg,
                                  int startRow, int endRow, int startCol, int endCol) throws Exception {
            GeoTiffReader reader = null;
            try {
                reader = new GeoTiffReader(new File(geotiffPath));
                GridCoverage2D coverage = reader.read((GeneralParameterValue[]) null);
                Raster raster = coverage.getRenderedImage().getData();
                int rasterHeight = raster.getHeight();
                int rasterWidth = raster.getWidth();
                if (endRow == -1) endRow = rasterHeight - 1;
                if (endCol == -1) endCol = rasterWidth - 1;
                validateCoordinates(raster, startRow, endRow, startCol, endCol);
                validateBand(coverage, raster, bandIndex - 1);
                int subsetWidth = endCol - startCol;
                int subsetHeight = endRow - startRow;
                Raster subRaster = raster.createChild(startCol, startRow, subsetWidth, subsetHeight, 0, 0, null);
                long totalObs = calculateTotalObs(0, subsetHeight - 1, 0, subsetWidth - 1);
                if (totalObs > MAX_OBS) { SFIToolkit.errorln("Reading too many observations"); return; }
                Data.setObsTotal(totalObs);
                processBlocks(subRaster, bandIndex - 1, coverage.getGridGeometry(), getNoDataValue(coverage, bandIndex), createTransform(coverage, targetEpsg), 0, subsetHeight - 1, 0, subsetWidth - 1, startRow, startCol);
            } catch (Exception e) {
                SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
                throw new RuntimeException(e);
            } finally {
                if (reader != null) try { reader.dispose(); } catch (Exception e) { SFIToolkit.errorln(SFIToolkit.stackTraceToString(e)); }
            }
        }

        private void processBlocks(Raster raster, int bandIndex, GridGeometry2D gridGeometry, double noData, MathTransform transform, int startRow, int endRow, int startCol, int endCol, int originalStartRow, int originalStartCol) {
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
            } catch (Exception e) { throw new RuntimeException(e); }
        }

        private Position2D convertCoordinate(GridGeometry2D gridGeometry, int x, int y, MathTransform transform) throws TransformException {
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

        private void validateCoordinates(Raster raster, int startRow, int endRow, int startCol, int endCol) {
            int maxRow = raster.getHeight() - 1;
            int maxCol = raster.getWidth() - 1;
            if (startRow > maxRow) { SFIToolkit.errorln("Starting Coordinates are out of range: startRow>" + maxRow); }
            if (startCol > maxCol) { SFIToolkit.errorln("Starting Coordinates are out of range: startCol>" + maxCol); }
            if (endRow > maxRow || endCol > maxCol) {
                SFIToolkit.errorln("Ending Coordinates are out of range");
                SFIToolkit.errorln("Maximum range: " + raster.getHeight() + "x" + raster.getWidth());
                throw new IllegalArgumentException(String.format("Coordinates are out of range (maximum range: %dx%d)", raster.getHeight(), raster.getWidth()));
            }
        }

        private long calculateTotalObs(int startRow, int endRow, int startCol, int endCol) { return (long) (endRow - startRow + 1) * (endCol - startCol + 1); }

        private MathTransform createTransform(GridCoverage2D coverage, String crsInput) throws Exception {
            if (crsInput == null || "None".equalsIgnoreCase(crsInput)) return null;
            CoordinateReferenceSystem targetCRS;
            if (crsInput.toLowerCase().endsWith(".tif")) targetCRS = readCRSFromGeoTIFF(crsInput);
            else if (crsInput.toLowerCase().endsWith(".shp")) targetCRS = readCRSFromShapefile(crsInput);
            else if (crsInput.startsWith("EPSG:")) targetCRS = CRS.decode(crsInput, true);
            else throw new IllegalArgumentException("Invalid CRS input: " + crsInput + ". Must be an EPSG code, GeoTIFF, or Shapefile.");
            return CRS.findMathTransform(coverage.getCoordinateReferenceSystem(), targetCRS);
        }

        private double getNoDataValue(GridCoverage2D coverage, int bandIndex) {
            GridSampleDimension sampleDim = coverage.getSampleDimension(bandIndex - 1);
            double[] noDataValues = sampleDim.getNoDataValues();
            if (noDataValues == null || noDataValues.length == 0) return Double.NaN;
            return noDataValues[0];
        }

        private boolean isNoData(double value, double noData) {
            if (Double.isNaN(noData)) return Double.isNaN(value);
            return (Math.abs(value - noData) < 1e-9);
        }

        private void validateBand(GridCoverage2D coverage, Raster raster, int bandIndex) {
            if (bandIndex < 0 || bandIndex >= raster.getNumBands()) {
                throw new IllegalArgumentException("Invalid band index: " + bandIndex + " (Total bands: " + raster.getNumBands() + ")");
            }
        }

        private CoordinateReferenceSystem readCRSFromGeoTIFF(String filePath) throws Exception {
            GeoTiffReader reader = null;
            try { reader = new GeoTiffReader(new File(filePath)); return reader.getCoordinateReferenceSystem(); }
            finally { if (reader != null) reader.dispose(); }
        }

        private CoordinateReferenceSystem readCRSFromShapefile(String filePath) throws Exception {
            ShapefileDataStore shapefileDataStore = null;
            try {
                File shpFile = new File(filePath);
                if (!shpFile.exists()) throw new Exception("Shapefile does not exist: " + filePath);
                String basePath = filePath.substring(0, filePath.lastIndexOf('.'));
                if (!new File(basePath + ".shx").exists() || !new File(basePath + ".dbf").exists()) throw new Exception("Incomplete shapefile: " + filePath);
                ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
                Map<String, Object> shpParams = new HashMap<>();
                shpParams.put("url", shpFile.toURI().toURL());
                shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);
                shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));
                CoordinateReferenceSystem crs = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
                if (crs == null) throw new Exception("CRS is null for Shapefile: " + filePath);
                return crs;
            } finally { if (shapefileDataStore != null) shapefileDataStore.dispose(); }
        }
    }

    // gtiffdisp_core.ado implementation (metadata -> Stata scalars)
    static class GtiffInfoImpl {
        public static void info(String filePath) {
            readGeoTiffMetadata(filePath);
        }

        public static void readGeoTiffMetadata(String filePath) {
            File file = new File(filePath);
            if (!file.exists()) { System.err.println("File does not exist: " + filePath); return; }
            GridCoverage2DReader reader = null;
            try {
                reader = new GeoTiffReader(file, new Hints(Hints.FORCE_LONGITUDE_FIRST_AXIS_ORDER, Boolean.TRUE));
                GridCoverage2D coverage = (GridCoverage2D) reader.read((GeneralParameterValue[]) null);
                GridSampleDimension[] bands = coverage.getSampleDimensions();
                System.out.println("\n=== Band Information ===");
                System.out.println("Number of bands: " + bands.length);
                Scalar.setValue("bands", bands.length);
                for (int i = 0; i < bands.length; i++) {
                    double[] noDataValues = bands[i].getNoDataValues();
                    String noDataInfo = "NoData: ";
                    if (noDataValues != null && noDataValues.length > 0) {
                        if (noDataValues.length > 1) noDataInfo += Arrays.toString(noDataValues);
                        else noDataInfo += (noDataValues[0] == (int) noDataValues[0]) ? String.format("%d", (int) noDataValues[0]) : String.format("%.4f", noDataValues[0]);
                    } else noDataInfo += "Not defined";
                    String cleanDescription = bands[i].getDescription().toString().replaceAll("[\\[\\]]", "").replaceAll("^\\s+", "");
                    System.out.printf("Band %-2d: %-20s | %s%n", i + 1, (cleanDescription.length() > 20 ? cleanDescription.substring(0, 17) + "..." : cleanDescription), noDataInfo);
                }
                ReferencedEnvelope rasterEnv = new ReferencedEnvelope(reader.getOriginalEnvelope());
                double minX = rasterEnv.getMinX();
                double maxX = rasterEnv.getMaxX();
                double minY = rasterEnv.getMinY();
                double maxY = rasterEnv.getMaxY();
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
                CoordinateReferenceSystem crs = coverage.getCoordinateReferenceSystem();
                System.out.println("\n=== Coordinate System ===");
                System.out.println("CRS Name: " + CRS.toSRS(crs));
                System.out.println("CRS WKT: " + crs.toWKT());
                System.out.println("\n=== Units ===");
                System.out.println("X unit: " + crs.getCoordinateSystem().getAxis(0).getUnit());
                System.out.println("Y unit: " + crs.getCoordinateSystem().getAxis(1).getUnit());
                System.out.println("\n=== Filtered Metadata ===");
                Set<String> excludeKeys = new HashSet<>(Arrays.asList("tile_cache_key", "tile_cache", "JAI.ImageReader", "JAI.ImageReadParam", "PamDataset"));
                for (String key : coverage.getPropertyNames()) {
                    if (!excludeKeys.contains(key)) {
                        Object value = coverage.getProperty(key);
                        if (value != null) {
                            String valStr = value.toString();
                            valStr = valStr.length() > 50 ? valStr.substring(0, 47) + "..." : valStr;
                            System.out.printf("%-28s: %s%n", key, valStr);
                        }
                    }
                }
            } catch (Exception e) {
                System.err.println("File read error: " + e.getMessage());
            } finally {
                if (reader != null) {
                    try { reader.dispose(); } catch (Exception e) { System.err.println("Error closing reader: " + e.getMessage()); }
                }
            }
        }
    }
}
