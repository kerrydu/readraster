{smcl}
{* *! version 3.0  10oct2025  (unified GeoTIFF/NetCDF)}{...}
{vieweralsosee "[R] merge" "help merge"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] matchgeop" "help matchgeop"}{...}
{viewerjumpto "Syntax" "gzonalstats##syntax"}{...}
{viewerjumpto "Description" "gzonalstats##description"}{...}
{viewerjumpto "Options" "gzonalstats##rasteropts"}{...}
{viewerjumpto "Remarks" "gzonalstats##remarks"}{...}
{viewerjumpto "Examples" "gzonalstats##examples"}{...}
{viewerjumpto "Stored results" "gzonalstats##results"}{...}
{title:Title}

{phang}
{bf:gzonalstats} {hline 2} Zonal statistics command for GeoTIFF and NetCDF raster files


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}{cmd:gzonalstats} {it:rasterfilename} {cmd:using} {it:shapefile}{cmd:,} {opt stats(string)} [{opt band(#)} {opt clear} {opt crs(string)}]{p_end}

{pstd}For NetCDF files:
{p 8 17 2}{cmd:gzonalstats} {it:netcdffilename} {cmd:using} {it:shapefile}{cmd:,} {opt stats(string)} {opt var(string)} [{opt clear} {opt origin(numlist)} {opt size(numlist)} {opt crs(string)}]{p_end}

{pstd}{it:rasterfilename} can be a GeoTIFF (.tif or .tiff) or NetCDF (.nc) file. The command automatically detects the file type and uses the appropriate processing method.

{p 8 17 2}{cmd:shapefile} must include accompanying .shx .dbf (and ideally .prj) files.

{marker description}{...}
{title:Description}

{pstd}{cmd:gzonalstats} computes statistics of raster cell values aggregated over polygon zones defined in a shapefile. It supports both GeoTIFF and NetCDF raster files:

{p 6 10 2}• {bf:GeoTIFF files}: Direct reading of one band from GeoTIFF files on disk{p_end}
{p 6 10 2}• {bf:NetCDF files}: Reading and processing of NetCDF variables with optional slicing{p_end}

{pstd}The command automatically detects the file type based on the file extension and uses the appropriate processing method.

{pstd}Features:
{p 8 12 2}• Reprojects the shapefile to match the raster CRS if needed{p_end}
{p 8 12 2}• Supports multiple statistics (count avg min max std sum){p_end}
{p 8 12 2}• Uses GeoTools Java libraries for spatial processing{p_end}
{p 8 12 2}• Automatic CRS detection with fallback to user-specified CRS{p_end}
{p 8 12 2}• NetCDF slicing support with origin() and size() options{p_end}

{title:Dependencies}
{pstd}All modes require GeoTools Java dependencies; see {help geotools_init}. 

{marker rasteropts}{...}
{title:Options}

{dlgtab:Common options}
{phang}{opt stats(string)} Statistics to compute; default {cmd:avg}. Any space‑separated subset of {cmd:count avg min max std sum}. Invalid names produce an error.
{phang}{opt clear} Clear current data in memory before loading results (required if data present).
{phang}{opt crs(string)} Coordinate reference system for the raster data. If the raster file contains CRS information, this option is ignored and a message is displayed. If no CRS is detected in the file and this option is not provided, an error occurs.

{dlgtab:GeoTIFF-specific options}
{phang}{opt band(#)} Band index (1-based) for multi-band GeoTIFF. Default 1; must be >=1.

{dlgtab:NetCDF-specific options}
{phang}{opt var(string)} Variable name in the NetCDF file to process (required for NetCDF files).
{phang}{opt origin(numlist)} Origin coordinates (1-based) for slicing the NetCDF variable. Must be integers >0.
{phang}{opt size(numlist)} Size of each dimension for slicing. At most 2 dimensions can have size >1 (2D grid requirement).

{marker remarks}{...}
{title:Remarks}

{pstd}{bf:File type detection.} The command automatically detects whether the input file is a GeoTIFF (.tif/.tiff) or NetCDF (.nc) file based on the file extension and uses the appropriate processing method.

{pstd}{bf:NetCDF processing.} For NetCDF files, the command supports multi-dimensional data with automatic detection of 2D spatial grids (allowing singleton dimensions). Use {cmd:origin()} and {cmd:size()} options for slicing large datasets. At most 2 dimensions can have size >1 to maintain 2D grid requirements.

{pstd}{bf:CRS handling.} The command attempts to automatically detect CRS from raster files. If CRS is found, user-provided {cmd:crs()} is ignored with a notification. If no CRS is detected and {cmd:crs()} is not provided, an error occurs. Shapefile is reprojected to match raster CRS when needed.

{pstd}{bf:Performance tips.}
{p 8 12 2}• Limit requested statistics to those needed{p_end}
{p 8 12 2}• Use appropriate CRS in projected meters for large area analyses{p_end}
{p 8 12 2}• Pre-filter polygons to study region before running{p_end}
{p 8 12 2}• For large NetCDF files, use slicing with {cmd:origin()} and {cmd:size()} to process subsets{p_end}
{p 8 12 2}• For very large rasters consider tiling externally; current command reads full needed extent{p_end}

{marker examples}{...}
{title:Examples}

{bf:GeoTIFF examples}
{phang}Nighttime lights statistics by city (sum + average):
{phang2}{cmd:. gzonalstats DMSP-like2020.tif using hunan.shp, stats("sum avg") clear}

{phang}Single statistic (mean) default:
{phang2}{cmd:. gzonalstats nl2022.tif using provinces.shp, clear}

{phang}Specify band 3 of a multi-band GeoTIFF:
{phang2}{cmd:. gzonalstats multiband.tif using zones.shp, band(3) stats("avg std") clear}

{phang}GeoTIFF with user-specified CRS (if auto-detection fails):
{phang2}{cmd:. gzonalstats raster.tif using polygons.shp, stats("avg min max") crs(EPSG:4326) clear}

{bf:NetCDF examples}
{phang}Basic NetCDF zonal statistics:
{phang2}{cmd:. gzonalstats climate.nc using countries.shp, var(temperature) stats("avg min max") clear}

{phang}NetCDF with slicing (subset of data):
{phang2}{cmd:. gzonalstats large_dataset.nc using regions.shp, var(precipitation) origin(1 1 100 200) size(1 1 50 50) stats("sum avg") clear}

{phang}NetCDF with user-specified CRS:
{phang2}{cmd:. gzonalstats data.nc using boundaries.shp, var(elevation) stats("avg std") crs(EPSG:3857) clear}

{bf:Comparing modes}
{phang}If you have both point grid and corresponding GeoTIFF:
{phang2}{cmd:. gzonalstats grid.tif using regions.shp, stats("avg std") clear}
{phang2}{cmd:. use grid_points, clear}
{phang2}{cmd:. gzonalstats using regions.shp, xvar(x) yvar(y) valuevar(val) frame(vec_stats) crs(EPSG:3857) stats("avg std")}

{marker results}{...}
{title:Stored results}

{pstd}Output dataset (or results frame in vector mode) contains:
{synoptset 22 tabbed}{...}
{p2col 5 24 28 2: Variable}Description{p_end}
{synoptline}
{synopt:{it:zone_id_vars}}All non-geometry attributes from shapefile polygons{p_end}
{synopt:{cmd:count}}Pixel count in zone (if requested){p_end}
{synopt:{cmd:avg}}Mean cell value (if requested){p_end}
{synopt:{cmd:min}}Minimum cell value (if requested){p_end}
{synopt:{cmd:max}}Maximum cell value (if requested){p_end}
{synopt:{cmd:std}}Standard deviation (if requested){p_end}
{synopt:{cmd:sum}}Sum of cell values (if requested){p_end}
{synoptline}
{p2colreset}{...}

{pstd}Each observation = one polygon zone. Statistics only include non‑nodata pixels.

{hline}
{title:Author}
{pstd}Kerry Du{p_end}
{pstd}School of Management, Xiamen University, China{p_end}
{pstd}Email: kerrydu@xmu.edu.cn{p_end}
{pstd}Chunxia Chen{p_end}
{pstd}School of Management, Xiamen University, China{p_end}
{pstd}Email: 35720241151353@stu.xmu.edu.cn{p_end}
{pstd}Yang Song{p_end}
{pstd}School of Economics, Hefei University of Technology, China{p_end}
{pstd}Email: ss0706082021@163.com{p_end}
{pstd}Ruipeng Tan{p_end}
{pstd}School of Economics, Hefei University of Technology, China{p_end}
{pstd}Email: tanruipeng@hfut.edu.cn{p_end}

{title:Also see}
{psee}
Online: {help geotools_init}, {help matchgeop}, {help gtiffdisp}, {help gtiffread}{p_end}

