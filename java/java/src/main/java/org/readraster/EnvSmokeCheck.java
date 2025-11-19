package org.readraster;

import org.geotools.referencing.CRS;

import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import java.util.Iterator;

public class EnvSmokeCheck {
    public static void main(String[] args) {
        boolean ok = true;

        ok &= check("CRS decode EPSG", () -> CRS.decode("EPSG:4326") != null);
        ok &= check("Shapefile factory present", () -> Class.forName("org.geotools.data.shapefile.ShapefileDataStoreFactory") != null);
        ok &= check("GeoTiff reader present", () -> Class.forName("org.geotools.gce.geotiff.GeoTiffReader") != null);
        ok &= check("ImageIO TIFF reader present", () -> {
            Iterator<ImageReader> it = ImageIO.getImageReadersByFormatName("tiff");
            return it != null && it.hasNext();
        });
        ok &= check("ZonalStats class present", () -> Class.forName("org.geotools.process.raster.RasterZonalStatistics") != null);
        ok &= check("NetCDF classes present", () -> Class.forName("ucar.nc2.dataset.NetcdfDatasets") != null);
        ok &= check("Units API present", () -> Class.forName("javax.measure.Unit") != null);
        ok &= check("Eclipse IMAGEN present", () -> Class.forName("org.eclipse.imagen.PropertySource") != null);

        if (!ok) {
            System.out.println("Smoke checks FAILED. See errors above.");
            System.exit(1);
        } else {
            System.out.println("Smoke checks PASSED. Core providers available.");
        }
    }

    private static boolean check(String name, Check c) {
        try {
            boolean res = c.run();
            if (res) {
                System.out.println("[OK] " + name);
                return true;
            } else {
                System.out.println("[FAIL] " + name);
                return false;
            }
        } catch (Throwable t) {
            System.out.println("[FAIL] " + name + ": " + t.getClass().getSimpleName() + ": " + t.getMessage());
            return false;
        }
    }

    @FunctionalInterface
    interface Check { boolean run() throws Exception; }
}
