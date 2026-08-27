package org.readraster;

// Consolidated single-file Java implementation extracted from Stata ADO java: blocks
// This class is placed in a named package to avoid classloader issues with default package in some environments.
// Public entry points remain the same; call with fully-qualified class name from Stata: org.readraster.ReadRasterAll

import java.awt.Transparency;
import java.awt.color.ColorSpace;
import java.awt.image.BufferedImage;
import java.awt.image.ColorModel;
import java.awt.image.ComponentColorModel;
import java.awt.image.DataBuffer;
import java.awt.image.DataBufferFloat;
import java.awt.image.PixelInterleavedSampleModel;
import java.awt.image.Raster;
import java.awt.image.SampleModel;
import java.awt.image.WritableRaster;
import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.logging.ConsoleHandler;
import java.util.logging.Handler;
import java.util.logging.Level;
import java.util.logging.Logger;

import javax.imageio.ImageIO;
import javax.imageio.spi.IIORegistry;
import javax.imageio.spi.ImageInputStreamSpi;

import org.geotools.api.feature.simple.SimpleFeature;
import org.geotools.api.parameter.GeneralParameterValue;
import org.geotools.api.referencing.crs.CoordinateReferenceSystem;
import org.geotools.api.referencing.operation.MathTransform;
import org.geotools.api.referencing.operation.TransformException;
import org.geotools.coverage.GridSampleDimension;
import org.geotools.coverage.grid.GridCoordinates2D;
import org.geotools.coverage.grid.GridCoverage2D;
import org.geotools.coverage.grid.GridCoverageFactory;
import org.geotools.coverage.grid.GridGeometry2D;
import org.geotools.coverage.grid.io.AbstractGridCoverage2DReader;
import org.geotools.coverage.grid.io.GridCoverage2DReader;
import org.geotools.data.shapefile.ShapefileDataStore;
import org.geotools.data.shapefile.ShapefileDataStoreFactory;
import org.geotools.data.simple.SimpleFeatureCollection;
import org.geotools.data.simple.SimpleFeatureIterator;
import org.geotools.data.store.ContentFeatureSource;
import org.geotools.data.store.ReprojectingFeatureCollection;
import org.geotools.gce.geotiff.GeoTiffReader;
import org.geotools.geometry.Position2D;
import org.geotools.geometry.jts.ReferencedEnvelope;
import org.geotools.referencing.CRS;
import org.geotools.util.factory.Hints;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.MultiPolygon;
import org.locationtech.jts.geom.Polygon;

import com.stata.sfi.Data;
import com.stata.sfi.SFIToolkit;
import com.stata.sfi.Scalar;

import ucar.ma2.Array;
import ucar.ma2.Index;
import ucar.nc2.Attribute;
import ucar.nc2.Variable;
import ucar.nc2.dataset.NetcdfDataset;
import ucar.nc2.dataset.NetcdfDatasets;

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

        // Avoid ImageIO disk cache side-effects; use direct streams
        try { ImageIO.setUseCache(false); } catch (Throwable ignore) {}

        // Ensure ImageIO uses standard file-backed streams for local files.
        // Deregister COG ImageInputStream providers that may incorrectly claim File inputs and return null.
        try {
            IIORegistry reg = IIORegistry.getDefaultInstance();
            Iterator<ImageInputStreamSpi> spis = reg.getServiceProviders(ImageInputStreamSpi.class, true);
            List<ImageInputStreamSpi> toRemove = new ArrayList<>();
            while (spis.hasNext()) {
                ImageInputStreamSpi spi = spis.next();
                String cn = spi.getClass().getName().toLowerCase(Locale.ROOT);
                if (cn.contains("imageioimpl") && cn.contains("cog")) {
                    toRemove.add(spi);
                }
            }
            for (ImageInputStreamSpi spi : toRemove) {
                reg.deregisterServiceProvider(spi);
            }
        } catch (Throwable ignore) {
            // Non-fatal; continue with default registry
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
                case "diag": {
                    try {
                        Class<?> c = Class.forName("org.geotools.coverage.grid.GridEnvelope2D");
                        java.net.URL loc = c.getProtectionDomain().getCodeSource() != null ? c.getProtectionDomain().getCodeSource().getLocation() : null;
                        SFIToolkit.displayln("Diag: Loaded GridEnvelope2D from: " + (loc != null ? loc.toString() : "<unknown>"));
                        SFIToolkit.displayln("Diag: GeoTiffReader present: " + (Class.forName("org.geotools.gce.geotiff.GeoTiffReader") != null));
                        SFIToolkit.displayln("Diag: ImageIO TIFF readers: ");
                        java.util.Iterator<javax.imageio.ImageReader> it = javax.imageio.ImageIO.getImageReadersByFormatName("tiff");
                        while (it != null && it.hasNext()) {
                            javax.imageio.ImageReader r = it.next();
                            SFIToolkit.displayln("  - " + r.getClass().getName());
                        }
                        if (args.length >= 2) {
                            String p = tokens.size() >= 2 ? tokens.get(1) : args[1];
                            java.io.File f = new java.io.File(p);
                            SFIToolkit.displayln("Diag: TIFF exists(" + f.getAbsolutePath() + "): " + f.exists());
                        }
                        return 0;
                    } catch (Throwable t) {
                        SFIToolkit.errorln("Diag error: " + t);
                        SFIToolkit.errorln(SFIToolkit.stackTraceToString(t));
                        return 98;
                    }
                }
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

        SFIToolkit.displayln("Converting coordinates from CRS:");
        SFIToolkit.displayln("Source CRS: " + source.toString());
        SFIToolkit.displayln("Target CRS: " + target.toString());
        if (transform.isIdentity()) SFIToolkit.displayln("Note: Source and target CRS are equivalent (identity transform)");

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
        SFIToolkit.displayln("crsconvert: processed " + total + " observations into '" + newXVar + "', '" + newYVar + "'");
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
        try {
            File f = new File(filePath);
            reader = new GeoTiffReader(f.toURI().toURL());
            return reader.getCoordinateReferenceSystem();
        } finally { if (reader != null) reader.dispose(); }
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
            SFIToolkit.errorln("Warning: Could not parse CRS from NetCDF: " + e.getMessage());
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
            String rasterCRSName = "Unknown CRS";
            try {
                Logger.getGlobal().setLevel(Level.SEVERE);

                // Parse requested statistics
                String[] requestedStats = statsParam == null ? new String[0] : statsParam.toLowerCase().split("\\s+");
                boolean showCount = false, showAvg = false, showMin = false, showMax = false, showStd = false, showSum = false;
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
                    SFIToolkit.errorln("Shapefile does not exist: " + shpPath);
                    return;
                }

                // Check for required components
                String basePath = shpPath.substring(0, shpPath.lastIndexOf('.'));
                File shxFile = new File(basePath + ".shx");
                File dbfFile = new File(basePath + ".dbf");
                File prjFile = new File(basePath + ".prj");
                if (!shxFile.exists() || !dbfFile.exists() || !prjFile.exists()) {
                    SFIToolkit.displayln("Warning: Missing required shapefile components:");
                    if (!shxFile.exists()) SFIToolkit.displayln(" - Missing .shx index file");
                    if (!dbfFile.exists()) SFIToolkit.displayln(" - Missing .dbf attribute file");
                    if (!prjFile.exists()) SFIToolkit.displayln(" - Missing .prj attribute file");
                    SFIToolkit.displayln("A complete shapefile requires .shp, .shx, .dbf and .prj files.");
                    return;
                }

                // Load vector data (shapefile)
                ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
                Map<String, Object> shpParams = new HashMap<>();
                shpParams.put("url", shpFile.toURI().toURL());
                shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);
                shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));

                ContentFeatureSource featureSource;
                try {
                    featureSource = shapefileDataStore.getFeatureSource();
                } catch (IndexOutOfBoundsException ioobe) {
                    SFIToolkit.errorln("Shapefile schema could not be read (likely empty DBF or corrupted .dbf/.shx). Please open the shapefile in a GIS/ogrinfo to ensure it has at least one attribute field and a valid index file.");
                    return;
                }

                if (featureSource.getSchema() == null || featureSource.getSchema().getAttributeCount() == 0) {
                    SFIToolkit.errorln("Shapefile has an empty/invalid DBF schema. Ensure the .dbf exists and contains at least one attribute column.");
                    return;
                }

                featureCollection = featureSource.getFeatures();

                if (featureCollection == null || featureCollection.size() == 0) {
                    SFIToolkit.errorln("Shapefile contains zero features. Nothing to aggregate.");
                    return;
                }

                // Check if raster data file exists
                File tiffFile = new File(tiffPath);
                if (!tiffFile.exists()) {
                    SFIToolkit.errorln("GeoTIFF file does not exist: " + tiffPath);
                    return;
                }

                // Create a GeoTiff reader
                reader = new GeoTiffReader(tiffFile);

                // Get coordinate systems for comparison
                CoordinateReferenceSystem rasterCRS = reader.getCoordinateReferenceSystem();
                if (rasterCRS != null) {
                    rasterCRSName = rasterCRS.getName().toString();
                    SFIToolkit.displayln("GeoTIFF CRS detected: " + rasterCRSName + ". User-provided CRS is ignored.");
                } else {
                    if (userCrs != null && !userCrs.trim().isEmpty()) {
                        SFIToolkit.displayln("GeoTIFF CRS not detected. Using user-provided CRS: " + userCrs);
                        rasterCRS = CRS.decode(userCrs, true);
                        rasterCRSName = rasterCRS.getName().toString();
                    } else {
                        SFIToolkit.errorln("GeoTIFF CRS not detected and no user CRS provided. Aborting.");
                        return;
                    }
                }

                CoordinateReferenceSystem vectorCRS = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
                String vectorCRSName = vectorCRS.getName().toString();
                SFIToolkit.displayln("Shapefile CRS: " + vectorCRSName);

                // Check if we need to reproject
                boolean needsReprojection = !CRS.equalsIgnoreMetadata(rasterCRS, vectorCRS);
                if (needsReprojection) {
                    SFIToolkit.displayln("Reprojecting shapefile from " + vectorCRSName + " to " + rasterCRSName);
                    featureCollection = new ReprojectingFeatureCollection(featureCollection, rasterCRS);
                } else {
                    SFIToolkit.displayln("Coordinate systems are compatible, no reprojection needed");
                }

                // Get shapefile bounds AFTER reprojection (if any)
                ReferencedEnvelope shpBounds = featureCollection.getBounds();
                SFIToolkit.displayln("Shapefile bounds for raster reading: " + shpBounds);

                // Create read parameters to limit reading to shapefile's bounds
                GeneralParameterValue[] readParams = null;
                if (shpBounds != null && !shpBounds.isEmpty()) {
                    // Optionally optimize raster read to only cover shapefile extent
                    // (left as a placeholder for future optimization)
                }

                // Read the raster data - either limited or full depending on whether readParams was set
                GridCoverage2D coverage = null;
                try {
                    coverage = reader.read(readParams);
                    SFIToolkit.displayln("Successfully read raster data" + (readParams != null ? " with optimization" : " (full extent)"));
                } catch (Exception e) {
                    SFIToolkit.errorln("Error reading raster with optimized parameters: " + e.getMessage());
                    SFIToolkit.displayln("Falling back to reading the entire raster");
                    coverage = reader.read((org.geotools.api.parameter.GeneralParameterValue[]) null);
                }

                if (coverage == null) {
                    SFIToolkit.errorln("Failed to read raster data. Aborting.");
                    return;
                }

                int numBands = coverage.getNumSampleDimensions();
                    // Defensive: Check raster band count and type
                    if (numBands <= 0) {
                        SFIToolkit.errorln("GeoTIFF contains no bands.");
                        return;
                    }
                    if (bandIndex < 0 || bandIndex >= numBands) {
                        SFIToolkit.errorln("Requested band index " + bandIndex + " is out of bounds. Available bands: " + numBands);
                        return;
                    }

                // Materialize feature collection into a list for processing and export
                List<SimpleFeature> allFeatures = new ArrayList<>();
                try {
                    featureIterator = featureCollection.features();
                    while (featureIterator.hasNext()) {
                        allFeatures.add(featureIterator.next());
                    }
                } finally {
                    if (featureIterator != null) featureIterator.close();
                }

                if (allFeatures.isEmpty()) {
                    SFIToolkit.errorln("No features found in the shapefile.");
                    return;
                }

                // Filter features to only include Polygon and MultiPolygon geometries
                int totalFeatureCount = allFeatures.size();
                List<SimpleFeature> zoneFeatures = new ArrayList<>();
                Map<String, Integer> filteredGeometryTypes = new HashMap<>();
                int invalidPolygonCount = 0;
                int emptyPolygonCount = 0;
                
                for (SimpleFeature feature : allFeatures) {
                    Object geomObj = feature.getDefaultGeometry();
                    if (geomObj != null && geomObj instanceof Geometry) {
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
                                SFIToolkit.displayln("Skipping invalid " + geomType + " geometry in feature " + feature.getID());
                                continue;
                            }
                            zoneFeatures.add(feature);
                        } else {
                            // Track filtered geometry types
                            filteredGeometryTypes.merge(geomType, 1, Integer::sum);
                        }
                    }
                }

                // Display filtering statistics if any features were filtered
                int filteredCount = totalFeatureCount - zoneFeatures.size();
                if (filteredCount > 0) {
                    SFIToolkit.displayln("Warning: Filtered out " + filteredCount + " non-polygon feature(s) from " + totalFeatureCount + " total features");
                    SFIToolkit.displayln("Filtered geometry types:");
                    for (Map.Entry<String, Integer> entry : filteredGeometryTypes.entrySet()) {
                        SFIToolkit.displayln("  - " + entry.getKey() + ": " + entry.getValue() + " feature(s)");
                    }
                    SFIToolkit.displayln("Only Polygon and MultiPolygon geometries are supported for zonal statistics");
                }

                if (invalidPolygonCount > 0) {
                    SFIToolkit.displayln("Skipped " + invalidPolygonCount + " invalid polygon feature(s); fix geometry or remove them to include their statistics.");
                }

                if (emptyPolygonCount > 0) {
                    SFIToolkit.displayln("Skipped " + emptyPolygonCount + " empty polygon feature(s); ensure geometries contain area before rerunning.");
                }

                if (zoneFeatures.isEmpty()) {
                    SFIToolkit.errorln("No valid polygon features found in the shapefile after filtering.");
                    return;
                }

                // Build list of statistics required by the user
                List<org.eclipse.imagen.media.stats.Statistics.StatsType> statsToRequest = new ArrayList<>();
                if (showMin && !statsToRequest.contains(org.eclipse.imagen.media.stats.Statistics.StatsType.MIN)) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.MIN);
                }
                if (showMax && !statsToRequest.contains(org.eclipse.imagen.media.stats.Statistics.StatsType.MAX)) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.MAX);
                }
                if (showSum && !statsToRequest.contains(org.eclipse.imagen.media.stats.Statistics.StatsType.SUM)) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.SUM);
                }
                if (showAvg && !statsToRequest.contains(org.eclipse.imagen.media.stats.Statistics.StatsType.MEAN)) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.MEAN);
                }
                if (showStd && !statsToRequest.contains(org.eclipse.imagen.media.stats.Statistics.StatsType.DEV_STD)) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.DEV_STD);
                }
                // Ensure at least one statistic is calculated so count can be derived
                if (statsToRequest.isEmpty()) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.MEAN);
                }

                org.eclipse.imagen.media.stats.Statistics.StatsType[] statsArray = statsToRequest.toArray(new org.eclipse.imagen.media.stats.Statistics.StatsType[0]);
                int[] bands = new int[] {bandIndex};

                org.geotools.process.raster.RasterZonalStatistics2 process = new org.geotools.process.raster.RasterZonalStatistics2();
                List<org.eclipse.imagen.media.zonal.ZoneGeometry> zoneGeometries = process.execute(
                        coverage,
                        bands,
                        zoneFeatures,
                        null,
                        null,
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

                // Prepare for exporting results back to Stata
                int totalFeatures = zoneFeatures.size();
                SFIToolkit.displayln("Total features: " + totalFeatures);
                Data.setObsTotal(totalFeatures);

                Map<String, Integer> attributeNameMap = new HashMap<>();
                List<String> idAttrNames = new ArrayList<>();
                Map<String, String> outputToSourceAttr = new HashMap<>();
                Map<String, Boolean> idAttrNumeric = new HashMap<>();
                Map<org.eclipse.imagen.media.stats.Statistics.StatsType, Integer> statsIndexMap = new HashMap<>();
                for (int i = 0; i < statsToRequest.size(); i++) {
                    statsIndexMap.put(statsToRequest.get(i), i);
                }

                // Inspect the first feature to decide which ID attributes to include
                SimpleFeature firstFeature = zoneFeatures.get(0);
                int varIndex = 1;
                for (int i = 0; i < firstFeature.getType().getAttributeCount(); i++) {
                    org.geotools.api.feature.type.AttributeDescriptor descriptor = firstFeature.getType().getDescriptor(i);
                    if (descriptor instanceof org.geotools.api.feature.type.GeometryDescriptor) {
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
                        SFIToolkit.displayln("Created numeric variable: " + outputAttrName);
                    } else {
                        Data.addVarStr(outputAttrName, determineStringLength(sampleValue));
                        idAttrNumeric.put(outputAttrName, false);
                        SFIToolkit.displayln("Created string variable: " + outputAttrName);
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
                    SFIToolkit.displayln("Created numeric variable: count");
                }
                if (showAvg && statsIndexMap.containsKey(org.eclipse.imagen.media.stats.Statistics.StatsType.MEAN)) {
                    avgAttrName = "avg";
                    Data.addVarDouble(avgAttrName);
                    attributeNameMap.put(avgAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: avg");
                }
                if (showMin && statsIndexMap.containsKey(org.eclipse.imagen.media.stats.Statistics.StatsType.MIN)) {
                    minAttrName = "min";
                    Data.addVarDouble(minAttrName);
                    attributeNameMap.put(minAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: min");
                }
                if (showMax && statsIndexMap.containsKey(org.eclipse.imagen.media.stats.Statistics.StatsType.MAX)) {
                    maxAttrName = "max";
                    Data.addVarDouble(maxAttrName);
                    attributeNameMap.put(maxAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: max");
                }
                if (showStd && statsIndexMap.containsKey(org.eclipse.imagen.media.stats.Statistics.StatsType.DEV_STD)) {
                    stddevAttrName = "std";
                    Data.addVarDouble(stddevAttrName);
                    attributeNameMap.put(stddevAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: std");
                }
                if (showSum && statsIndexMap.containsKey(org.eclipse.imagen.media.stats.Statistics.StatsType.SUM)) {
                    sumAttrName = "sum";
                    Data.addVarDouble(sumAttrName);
                    attributeNameMap.put(sumAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: sum");
                }

                // Populate the Stata dataset row by row
                for (int i = 0; i < totalFeatures; i++) {
                    SimpleFeature feature = zoneFeatures.get(i);
                    int stataObs = i + 1;
                    // Store ID attributes
                    for (String outputAttrName : idAttrNames) {
                        String sourceAttrName = outputToSourceAttr.get(outputAttrName);
                        Object value = feature.getAttribute(sourceAttrName);
                        if (idAttrNumeric.get(outputAttrName)) {
                            Data.storeNumFast(attributeNameMap.get(outputAttrName), stataObs, value == null ? Double.NaN : ((Number) value).doubleValue());
                        } else {
                            Data.storeStr(attributeNameMap.get(outputAttrName), stataObs, value == null ? "" : value.toString());
                        }
                    }
                    org.eclipse.imagen.media.zonal.ZoneGeometry zoneGeometry = i < zoneGeometries.size() ? zoneGeometries.get(i) : null;
                    org.eclipse.imagen.media.stats.Statistics[] stats = extractStatisticsForZone(zoneGeometry, bandIndex);
                    if (stats == null || stats.length == 0) {
                        if (countAttrName != null) Data.storeNumFast(attributeNameMap.get(countAttrName), stataObs, 0);
                        if (avgAttrName != null) Data.storeNumFast(attributeNameMap.get(avgAttrName), stataObs, Double.NaN);
                        if (minAttrName != null) Data.storeNumFast(attributeNameMap.get(minAttrName), stataObs, Double.NaN);
                        if (maxAttrName != null) Data.storeNumFast(attributeNameMap.get(maxAttrName), stataObs, Double.NaN);
                        if (stddevAttrName != null) Data.storeNumFast(attributeNameMap.get(stddevAttrName), stataObs, Double.NaN);
                        if (sumAttrName != null) Data.storeNumFast(attributeNameMap.get(sumAttrName), stataObs, Double.NaN);
                        continue;
                    }
                    if (countAttrName != null) {
                        double count = stats[0] != null && stats[0].getNumSamples() >= 0 ? stats[0].getNumSamples() : 0;
                        Data.storeNumFast(attributeNameMap.get(countAttrName), stataObs, count);
                    }
                    if (avgAttrName != null) {
                        Double v = getStatValue(stats, statsIndexMap, org.eclipse.imagen.media.stats.Statistics.StatsType.MEAN);
                        Data.storeNumFast(attributeNameMap.get(avgAttrName), stataObs, v == null ? Double.NaN : v);
                    }
                    if (minAttrName != null) {
                        Double v = getStatValue(stats, statsIndexMap, org.eclipse.imagen.media.stats.Statistics.StatsType.MIN);
                        Data.storeNumFast(attributeNameMap.get(minAttrName), stataObs, v == null ? Double.NaN : v);
                    }
                    if (maxAttrName != null) {
                        Double v = getStatValue(stats, statsIndexMap, org.eclipse.imagen.media.stats.Statistics.StatsType.MAX);
                        Data.storeNumFast(attributeNameMap.get(maxAttrName), stataObs, v == null ? Double.NaN : v);
                    }
                    if (stddevAttrName != null) {
                        Double v = getStatValue(stats, statsIndexMap, org.eclipse.imagen.media.stats.Statistics.StatsType.DEV_STD);
                        Data.storeNumFast(attributeNameMap.get(stddevAttrName), stataObs, v == null ? Double.NaN : v);
                    }
                    if (sumAttrName != null) {
                        Double v = getStatValue(stats, statsIndexMap, org.eclipse.imagen.media.stats.Statistics.StatsType.SUM);
                        Data.storeNumFast(attributeNameMap.get(sumAttrName), stataObs, v == null ? Double.NaN : v);
                    }
                }
                Data.updateModified();
                SFIToolkit.displayln("Data successfully exported to Stata dataset.");
            } catch (Exception e) {
                SFIToolkit.errorln("Error in zonalstatics: " + e.getMessage());
                SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
            } finally {
                try {
                    if (featureIterator != null) featureIterator.close();
                    if (reader != null) reader.dispose();
                    if (shapefileDataStore != null) shapefileDataStore.dispose();
                    System.gc();
                } catch (Exception e) {
                    SFIToolkit.errorln("Error closing resources: " + e.getMessage());
                    SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
                }
            }
        }
        // Helper to determine string length for Data.addVarStr
        private int determineStringLength(Object value) {
            if (value == null) return 8;
            String s = value.toString();
            int len = s.length();
            if (len < 8) return 8;
            if (len > 255) return 255;
            return len;
        }

        // Helper to call Data.storeStrFast (for symmetry with Data.storeNumFast)
        private void storeStrFast(int varIndex, int obs, String value) {
            Data.storeStr(varIndex, obs, value);
        }

        // Helper to extract statistics for a zone
        private org.eclipse.imagen.media.stats.Statistics[] extractStatisticsForZone(org.eclipse.imagen.media.zonal.ZoneGeometry zoneGeometry, int bandIndex) {
            if (zoneGeometry == null) return null;
            Map<Integer, Map<org.eclipse.imagen.media.range.Range, org.eclipse.imagen.media.stats.Statistics[]>> statsPerBand = zoneGeometry.getStatsPerBand(bandIndex);
            if (statsPerBand == null || statsPerBand.isEmpty()) return null;
            for (Map<org.eclipse.imagen.media.range.Range, org.eclipse.imagen.media.stats.Statistics[]> rangeMap : statsPerBand.values()) {
                if (rangeMap == null || rangeMap.isEmpty()) continue;
                for (org.eclipse.imagen.media.stats.Statistics[] statsArray : rangeMap.values()) {
                    if (statsArray != null && statsArray.length > 0) return statsArray;
                }
            }
            return null;
        }

        // Helper to get a specific stat value
        private Double getStatValue(org.eclipse.imagen.media.stats.Statistics[] stats,
                                   Map<org.eclipse.imagen.media.stats.Statistics.StatsType, Integer> statsIndexMap,
                                   org.eclipse.imagen.media.stats.Statistics.StatsType type) {
            if (stats == null || statsIndexMap == null || type == null) return null;
            Integer idx = statsIndexMap.get(type);
            if (idx == null || idx < 0 || idx >= stats.length) return null;
            org.eclipse.imagen.media.stats.Statistics statistic = stats[idx];
            if (statistic == null) return null;
            Object result = statistic.getResult();
            if (result instanceof Number) return ((Number) result).doubleValue();
            return null;
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
            String rasterCRSName = "Unknown CRS";
            try {
                Logger.getGlobal().setLevel(Level.SEVERE);

                // Parse requested statistics
                String[] requestedStats = statsParam == null ? new String[0] : statsParam.toLowerCase().split("\\s+");
                boolean showCount = false, showAvg = false, showMin = false, showMax = false, showStd = false, showSum = false;
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
                    SFIToolkit.errorln("Shapefile does not exist: " + shpPath);
                    return;
                }
                String basePath = shpPath.substring(0, shpPath.lastIndexOf('.'));
                File shxFile = new File(basePath + ".shx");
                File dbfFile = new File(basePath + ".dbf");
                File prjFile = new File(basePath + ".prj");
                if (!shxFile.exists() || !dbfFile.exists() || !prjFile.exists()) {
                    SFIToolkit.displayln("Warning: Missing required shapefile components:");
                    if (!shxFile.exists()) SFIToolkit.displayln(" - Missing .shx index file");
                    if (!dbfFile.exists()) SFIToolkit.displayln(" - Missing .dbf attribute file");
                    if (!prjFile.exists()) SFIToolkit.displayln(" - Missing .prj attribute file");
                    SFIToolkit.displayln("A complete shapefile requires .shp, .shx, .dbf and .prj files.");
                    return;
                }

                // Load vector data (shapefile)
                ShapefileDataStoreFactory dataStoreFactory = new ShapefileDataStoreFactory();
                Map<String, Object> shpParams = new HashMap<>();
                shpParams.put("url", shpFile.toURI().toURL());
                shapefileDataStore = (ShapefileDataStore) dataStoreFactory.createDataStore(shpParams);
                shapefileDataStore.setCharset(java.nio.charset.Charset.forName("UTF-8"));
                featureCollection = shapefileDataStore.getFeatureSource().getFeatures();

                // Check if NetCDF file exists and open
                try { ncFile = NetcdfDatasets.openDataset(ncPath); }
                catch (Exception e) { SFIToolkit.errorln("NetCDF file cannot be opened: " + ncPath); SFIToolkit.errorln(SFIToolkit.stackTraceToString(e)); return; }

                Variable ncVar = ncFile.findVariable(varName);
                if (ncVar == null) { SFIToolkit.errorln("Variable '" + varName + "' not found in NetCDF file"); return; }

                    // Defensive: Check NetCDF variable type and shape
                    if (!ncVar.getDataType().isNumeric()) {
                        SFIToolkit.errorln("NetCDF variable '" + varName + "' is not numeric. Type: " + ncVar.getDataType());
                        return;
                    }
                    int[] varShape = ncVar.getShape();
                    if (varShape == null || varShape.length < 2) {
                        SFIToolkit.errorln("NetCDF variable '" + varName + "' has invalid shape: " + (varShape == null ? "null" : java.util.Arrays.toString(varShape)));
                        return;
                    }
                    for (int dim : varShape) {
                        if (dim <= 0) {
                            SFIToolkit.errorln("NetCDF variable '" + varName + "' has non-positive dimension size: " + dim);
                            return;
                        }
                    }
                List<ucar.nc2.Dimension> dimensions = ncVar.getDimensions();
                int numDims = dimensions.size();
                if (numDims < 2) { SFIToolkit.errorln("Variable '" + varName + "' has " + numDims + " dimensions. Must have at least 2 dimensions."); return; }

                SFIToolkit.displayln("NetCDF variable '" + varName + "' type: " + ncVar.getDataType().toString());

                Attribute fillAttr = ncVar.findAttribute("_FillValue");
                if (fillAttr == null) fillAttr = ncVar.findAttribute("missing_value");
                if (fillAttr != null) SFIToolkit.displayln("NetCDF variable '" + varName + "' missing value attribute: " + fillAttr.getNumericValue() + " (type: " + fillAttr.getDataType() + ")");
                else SFIToolkit.displayln("NetCDF variable '" + varName + "' has no _FillValue or missing_value attribute.");

                    // Parse origin and size parameters
                    int[] origin = null;
                    int[] size = null;
                    if (originParam != null && !originParam.trim().isEmpty()) {
                        origin = parseIntArray(originParam);
                    }
                    if (sizeParam != null && !sizeParam.trim().isEmpty()) {
                        size = parseIntArray(sizeParam);
                    }
                    Array dataArray;
                    if (origin != null && size != null && origin.length == size.length && origin.length == dimensions.size()) {
                        dataArray = ncVar.read(origin, size);
                    } else {
                        dataArray = ncVar.read();
                    }

                int[] actualShape = dataArray.getShape();
                int actualDims = actualShape.length;
                int yDim = -1, xDim = -1;
                List<Integer> spatialDims = new ArrayList<>();
                for (int i = 0; i < actualDims; i++) if (actualShape[i] > 1) spatialDims.add(i);
                if (spatialDims.size() < 2) { SFIToolkit.errorln("Error: Need at least 2 spatial dimensions with size > 1"); return; }
                yDim = spatialDims.get(spatialDims.size() - 2);
                xDim = spatialDims.get(spatialDims.size() - 1);

                CoordinateReferenceSystem ncCRS = extractCRSFromNetCDF(ncFile, ncVar);
                if (ncCRS != null) {
                    rasterCRSName = ncCRS.getName().toString();
                    SFIToolkit.displayln("NetCDF CRS detected: " + rasterCRSName + ". User-provided CRS is ignored.");
                } else {
                    if (userCrs != null && !userCrs.trim().isEmpty()) {
                        SFIToolkit.displayln("NetCDF CRS not detected. Using user-provided CRS: " + userCrs);
                        ncCRS = CRS.decode(userCrs, true);
                        rasterCRSName = ncCRS.getName().toString();
                    } else {
                        SFIToolkit.errorln("Error: NetCDF file does not contain CRS information and no CRS was provided. Please specify a CRS using the crs() option.");
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
                if (lonVar == null || latVar == null) { SFIToolkit.errorln("Unable to automatically identify longitude/latitude variables, please check the NetCDF file!"); return; }

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
                if (spatialDims2.size() < 2) { SFIToolkit.errorln("Error: Need at least 2 spatial dimensions with size > 1"); return; }
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

                CoordinateReferenceSystem rasterCRS = ncCRS;
                CoordinateReferenceSystem vectorCRS = shapefileDataStore.getSchema().getCoordinateReferenceSystem();
                String vectorCRSName = vectorCRS.getName().toString();
                boolean needsReprojection = !CRS.equalsIgnoreMetadata(rasterCRS, vectorCRS);
                if (needsReprojection) {
                    SFIToolkit.displayln("Reprojecting shapefile from " + vectorCRSName + " to " + rasterCRSName);
                    featureCollection = new ReprojectingFeatureCollection(featureCollection, rasterCRS);
                } else {
                    SFIToolkit.displayln("Coordinate systems are compatible, no reprojection needed");
                }

                // ----------- 新API调用部分 -----------
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
                                    SFIToolkit.displayln("Skipping invalid " + geomType + " geometry in feature " + feature.getID());
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
                    if (featureIterator != null) featureIterator.close();
                }

                int filteredCount = totalFeatureCount - zoneFeatures.size();
                if (filteredCount > 0) {
                    SFIToolkit.displayln("Warning: Filtered out " + filteredCount + " non-polygon feature(s) from " + totalFeatureCount + " total features");
                    if (!filteredGeometryTypes.isEmpty()) {
                        SFIToolkit.displayln("Filtered geometry types:");
                        for (Map.Entry<String, Integer> entry : filteredGeometryTypes.entrySet()) {
                            SFIToolkit.displayln("  - " + entry.getKey() + ": " + entry.getValue() + " feature(s)");
                        }
                    }
                    SFIToolkit.displayln("Only Polygon and MultiPolygon geometries are supported for zonal statistics.");
                }

                if (invalidPolygonCount > 0) {
                    SFIToolkit.displayln("Skipped " + invalidPolygonCount + " invalid polygon feature(s); fix geometry or remove them to include their statistics.");
                }

                if (emptyPolygonCount > 0) {
                    SFIToolkit.displayln("Skipped " + emptyPolygonCount + " empty polygon feature(s); ensure geometries contain area before rerunning.");
                }

                if (zoneFeatures.isEmpty()) {
                    SFIToolkit.errorln("No valid polygon features found in the shapefile after filtering.");
                    return;
                }

                // 构建统计类型列表
                List<org.eclipse.imagen.media.stats.Statistics.StatsType> statsToRequest = new ArrayList<>();
                if (showMin && !statsToRequest.contains(org.eclipse.imagen.media.stats.Statistics.StatsType.MIN)) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.MIN);
                }
                if (showMax && !statsToRequest.contains(org.eclipse.imagen.media.stats.Statistics.StatsType.MAX)) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.MAX);
                }
                if (showSum && !statsToRequest.contains(org.eclipse.imagen.media.stats.Statistics.StatsType.SUM)) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.SUM);
                }
                if (showAvg && !statsToRequest.contains(org.eclipse.imagen.media.stats.Statistics.StatsType.MEAN)) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.MEAN);
                }
                if (showStd && !statsToRequest.contains(org.eclipse.imagen.media.stats.Statistics.StatsType.DEV_STD)) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.DEV_STD);
                }
                if (statsToRequest.isEmpty()) {
                    statsToRequest.add(org.eclipse.imagen.media.stats.Statistics.StatsType.MEAN);
                }
                org.eclipse.imagen.media.stats.Statistics.StatsType[] statsArray = statsToRequest.toArray(new org.eclipse.imagen.media.stats.Statistics.StatsType[0]);
                int[] bandsArr = new int[] {0};

                org.geotools.process.raster.RasterZonalStatistics2 process = new org.geotools.process.raster.RasterZonalStatistics2();
                List<org.eclipse.imagen.media.zonal.ZoneGeometry> zoneGeometries = process.execute(
                        coverage,
                        bandsArr,
                        zoneFeatures,
                        null,
                        null,
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

                // ----------- 统一输出结构 -----------
                int totalFeatures = zoneFeatures.size();
                SFIToolkit.displayln("Total features: " + totalFeatures);
                Data.setObsTotal(totalFeatures);

                Map<String, Integer> attributeNameMap = new HashMap<>();
                List<String> idAttrNames = new ArrayList<>();
                Map<String, String> outputToSourceAttr = new HashMap<>();
                Map<String, Boolean> idAttrNumeric = new HashMap<>();
                Map<org.eclipse.imagen.media.stats.Statistics.StatsType, Integer> statsIndexMap = new HashMap<>();
                for (int i = 0; i < statsToRequest.size(); i++) {
                    statsIndexMap.put(statsToRequest.get(i), i);
                }

                SimpleFeature firstFeature = zoneFeatures.get(0);
                int varIndex = 1;
                for (int i = 0; i < firstFeature.getType().getAttributeCount(); i++) {
                    org.geotools.api.feature.type.AttributeDescriptor descriptor = firstFeature.getType().getDescriptor(i);
                    if (descriptor instanceof org.geotools.api.feature.type.GeometryDescriptor) {
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
                        SFIToolkit.displayln("Created numeric variable: " + outputAttrName);
                    } else {
                        Data.addVarStr(outputAttrName, determineStringLength(sampleValue));
                        idAttrNumeric.put(outputAttrName, false);
                        SFIToolkit.displayln("Created string variable: " + outputAttrName);
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
                    SFIToolkit.displayln("Created numeric variable: count");
                }
                if (showAvg && statsIndexMap.containsKey(org.eclipse.imagen.media.stats.Statistics.StatsType.MEAN)) {
                    avgAttrName = "avg";
                    Data.addVarDouble(avgAttrName);
                    attributeNameMap.put(avgAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: avg");
                }
                if (showMin && statsIndexMap.containsKey(org.eclipse.imagen.media.stats.Statistics.StatsType.MIN)) {
                    minAttrName = "min";
                    Data.addVarDouble(minAttrName);
                    attributeNameMap.put(minAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: min");
                }
                if (showMax && statsIndexMap.containsKey(org.eclipse.imagen.media.stats.Statistics.StatsType.MAX)) {
                    maxAttrName = "max";
                    Data.addVarDouble(maxAttrName);
                    attributeNameMap.put(maxAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: max");
                }
                if (showStd && statsIndexMap.containsKey(org.eclipse.imagen.media.stats.Statistics.StatsType.DEV_STD)) {
                    stddevAttrName = "std";
                    Data.addVarDouble(stddevAttrName);
                    attributeNameMap.put(stddevAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: std");
                }
                if (showSum && statsIndexMap.containsKey(org.eclipse.imagen.media.stats.Statistics.StatsType.SUM)) {
                    sumAttrName = "sum";
                    Data.addVarDouble(sumAttrName);
                    attributeNameMap.put(sumAttrName, varIndex++);
                    SFIToolkit.displayln("Created numeric variable: sum");
                }

                for (int i = 0; i < totalFeatures; i++) {
                    SimpleFeature feature = zoneFeatures.get(i);
                    int stataObs = i + 1;
                    for (String outputAttrName : idAttrNames) {
                        String sourceAttrName = outputToSourceAttr.get(outputAttrName);
                        Object value = feature.getAttribute(sourceAttrName);
                        if (idAttrNumeric.get(outputAttrName)) {
                            Data.storeNumFast(attributeNameMap.get(outputAttrName), stataObs, value == null ? Double.NaN : ((Number) value).doubleValue());
                        } else {
                            Data.storeStr(attributeNameMap.get(outputAttrName), stataObs, value == null ? "" : value.toString());
                        }
                    }
                    org.eclipse.imagen.media.zonal.ZoneGeometry zoneGeometry = i < zoneGeometries.size() ? zoneGeometries.get(i) : null;
                    org.eclipse.imagen.media.stats.Statistics[] stats = extractStatisticsForZone(zoneGeometry, 0);
                    if (stats == null || stats.length == 0) {
                        if (countAttrName != null) Data.storeNumFast(attributeNameMap.get(countAttrName), stataObs, 0);
                        if (avgAttrName != null) Data.storeNumFast(attributeNameMap.get(avgAttrName), stataObs, Double.NaN);
                        if (minAttrName != null) Data.storeNumFast(attributeNameMap.get(minAttrName), stataObs, Double.NaN);
                        if (maxAttrName != null) Data.storeNumFast(attributeNameMap.get(maxAttrName), stataObs, Double.NaN);
                        if (stddevAttrName != null) Data.storeNumFast(attributeNameMap.get(stddevAttrName), stataObs, Double.NaN);
                        if (sumAttrName != null) Data.storeNumFast(attributeNameMap.get(sumAttrName), stataObs, Double.NaN);
                        continue;
                    }
                    if (countAttrName != null) {
                        double count = stats[0] != null && stats[0].getNumSamples() >= 0 ? stats[0].getNumSamples() : 0;
                        Data.storeNumFast(attributeNameMap.get(countAttrName), stataObs, count);
                    }
                    if (avgAttrName != null) {
                        Double v = getStatValue(stats, statsIndexMap, org.eclipse.imagen.media.stats.Statistics.StatsType.MEAN);
                        Data.storeNumFast(attributeNameMap.get(avgAttrName), stataObs, v == null ? Double.NaN : v);
                    }
                    if (minAttrName != null) {
                        Double v = getStatValue(stats, statsIndexMap, org.eclipse.imagen.media.stats.Statistics.StatsType.MIN);
                        Data.storeNumFast(attributeNameMap.get(minAttrName), stataObs, v == null ? Double.NaN : v);
                    }
                    if (maxAttrName != null) {
                        Double v = getStatValue(stats, statsIndexMap, org.eclipse.imagen.media.stats.Statistics.StatsType.MAX);
                        Data.storeNumFast(attributeNameMap.get(maxAttrName), stataObs, v == null ? Double.NaN : v);
                    }
                    if (stddevAttrName != null) {
                        Double v = getStatValue(stats, statsIndexMap, org.eclipse.imagen.media.stats.Statistics.StatsType.DEV_STD);
                        Data.storeNumFast(attributeNameMap.get(stddevAttrName), stataObs, v == null ? Double.NaN : v);
                    }
                    if (sumAttrName != null) {
                        Double v = getStatValue(stats, statsIndexMap, org.eclipse.imagen.media.stats.Statistics.StatsType.SUM);
                        Data.storeNumFast(attributeNameMap.get(sumAttrName), stataObs, v == null ? Double.NaN : v);
                    }
                }
                Data.updateModified();
                SFIToolkit.displayln("Data successfully exported to Stata dataset.");
            } catch (Exception e) {
                SFIToolkit.errorln("Error in nzonalstatics: " + e.getMessage()); SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
            } finally {
                try {
                    if (featureIterator != null) featureIterator.close();
                    if (ncFile != null) ncFile.close();
                    if (shapefileDataStore != null) shapefileDataStore.dispose();
                    if (coverage != null) coverage.dispose(true);
                    System.gc();
                } catch (Exception e) {
                    SFIToolkit.errorln("Error closing resources: " + e.getMessage()); SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
                }
            }
        }

            // Helper to parse comma/space separated int array string
            private int[] parseIntArray(String param) {
                String[] tokens = param.trim().split("[ ,]+");
                int[] arr = new int[tokens.length];
                for (int i = 0; i < tokens.length; i++) {
                    arr[i] = Integer.parseInt(tokens[i]);
                }
                return arr;
            }

            // Helper to determine string length for Data.addVarStr
            private int determineStringLength(Object value) {
                if (value == null) return 8;
                String s = value.toString();
                int len = s.length();
                if (len < 8) return 8;
                if (len > 255) return 255;
                return len;
            }

            // Helper to call Data.storeStrFast (for symmetry with Data.storeNumFast)
            private void storeStrFast(int varIndex, int obs, String value) {
                Data.storeStr(varIndex, obs, value);
            }

            // Helper to extract statistics for a zone
            private org.eclipse.imagen.media.stats.Statistics[] extractStatisticsForZone(org.eclipse.imagen.media.zonal.ZoneGeometry zoneGeometry, int bandIndex) {
                if (zoneGeometry == null) return null;
                Map<Integer, Map<org.eclipse.imagen.media.range.Range, org.eclipse.imagen.media.stats.Statistics[]>> statsPerBand = zoneGeometry.getStatsPerBand(bandIndex);
                if (statsPerBand == null || statsPerBand.isEmpty()) return null;
                for (Map<org.eclipse.imagen.media.range.Range, org.eclipse.imagen.media.stats.Statistics[]> rangeMap : statsPerBand.values()) {
                    if (rangeMap == null || rangeMap.isEmpty()) continue;
                    for (org.eclipse.imagen.media.stats.Statistics[] statsArray : rangeMap.values()) {
                        if (statsArray != null && statsArray.length > 0) return statsArray;
                    }
                }
                return null;
            }

            // Helper to get a specific stat value
            private Double getStatValue(org.eclipse.imagen.media.stats.Statistics[] stats,
                                       Map<org.eclipse.imagen.media.stats.Statistics.StatsType, Integer> statsIndexMap,
                                       org.eclipse.imagen.media.stats.Statistics.StatsType type) {
                if (stats == null || statsIndexMap == null || type == null) return null;
                Integer idx = statsIndexMap.get(type);
                if (idx == null || idx < 0 || idx >= stats.length) return null;
                org.eclipse.imagen.media.stats.Statistics statistic = stats[idx];
                if (statistic == null) return null;
                Object result = statistic.getResult();
                if (result instanceof Number) return ((Number) result).doubleValue();
                return null;
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
                int subsetWidth = endCol - startCol + 1;
                int subsetHeight = endRow - startRow + 1;
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
            if (endRow < startRow || endCol < startCol) {
                throw new IllegalArgumentException(String.format("Invalid subset bounds: endRow (%d) must be >= startRow (%d), and endCol (%d) must be >= startCol (%d).", endRow, startRow, endCol, startCol));
            }
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
            try { reader = new GeoTiffReader(new File(filePath).toURI().toURL()); return reader.getCoordinateReferenceSystem(); }
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
            if (!file.exists()) { SFIToolkit.errorln("File does not exist: " + filePath); return; }
            GridCoverage2DReader reader = null;
            try {
                reader = new GeoTiffReader(file.toURI().toURL(), new Hints(Hints.FORCE_LONGITUDE_FIRST_AXIS_ORDER, Boolean.TRUE));
                GridCoverage2D coverage = (GridCoverage2D) reader.read((GeneralParameterValue[]) null);
                GridSampleDimension[] bands = coverage.getSampleDimensions();
                SFIToolkit.displayln("\n=== Band Information ===");
                SFIToolkit.displayln("Number of bands: " + bands.length);
                Scalar.setValue("bands", bands.length);
                for (int i = 0; i < bands.length; i++) {
                    double[] noDataValues = bands[i].getNoDataValues();
                    String noDataInfo = "NoData: ";
                    if (noDataValues != null && noDataValues.length > 0) {
                        if (noDataValues.length > 1) noDataInfo += Arrays.toString(noDataValues);
                        else noDataInfo += (noDataValues[0] == (int) noDataValues[0]) ? String.format("%d", (int) noDataValues[0]) : String.format("%.4f", noDataValues[0]);
                    } else noDataInfo += "Not defined";
                    String cleanDescription = bands[i].getDescription().toString().replaceAll("[\\[\\]]", "").replaceAll("^\\s+", "");
                    SFIToolkit.displayln(String.format("Band %-2d: %-20s | %s", i + 1, (cleanDescription.length() > 20 ? cleanDescription.substring(0, 17) + "..." : cleanDescription), noDataInfo));
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
                SFIToolkit.displayln("\n=== Spatial Characteristics ===");
                SFIToolkit.displayln(String.format("X range: [%.4f ~ %.4f]", minX, maxX));
                SFIToolkit.displayln(String.format("Y range: [%.4f ~ %.4f]", minY, maxY));
                SFIToolkit.displayln(String.format("Resolution: X=%.4f units/pixel, Y=%.4f units/pixel", xRes, yRes));
                Scalar.setValue("width", width);
                Scalar.setValue("height", height);
                Scalar.setValue("xRes", xRes);
                Scalar.setValue("yRes", yRes);
                Scalar.setValue("minX", minX);
                Scalar.setValue("minY", minY);
                Scalar.setValue("maxX", maxX);
                Scalar.setValue("maxY", maxY);
                CoordinateReferenceSystem crs = coverage.getCoordinateReferenceSystem();
                SFIToolkit.displayln("\n=== Coordinate System ===");
                SFIToolkit.displayln("CRS Name: " + CRS.toSRS(crs));
                SFIToolkit.displayln("CRS WKT: " + crs.toWKT());
                SFIToolkit.displayln("\n=== Units ===");
                SFIToolkit.displayln("X unit: " + crs.getCoordinateSystem().getAxis(0).getUnit());
                SFIToolkit.displayln("Y unit: " + crs.getCoordinateSystem().getAxis(1).getUnit());
                SFIToolkit.displayln("\n=== Filtered Metadata ===");
                Set<String> excludeKeys = new HashSet<>(Arrays.asList("tile_cache_key", "tile_cache", "JAI.ImageReader", "JAI.ImageReadParam", "PamDataset"));
                for (String key : coverage.getPropertyNames()) {
                    if (!excludeKeys.contains(key)) {
                        Object value = coverage.getProperty(key);
                        if (value != null) {
                            String valStr = value.toString();
                            valStr = valStr.length() > 50 ? valStr.substring(0, 47) + "..." : valStr;
                            SFIToolkit.displayln(String.format("%-28s: %s", key, valStr));
                        }
                    }
                }
            } catch (Exception e) {
                SFIToolkit.errorln("File read error: " + e.getMessage());
            } finally {
                if (reader != null) {
                    try { reader.dispose(); } catch (Exception e) { SFIToolkit.errorln("Error closing reader: " + e.getMessage()); }
                }
            }
        }
    }
}
