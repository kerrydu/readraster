{smcl}
{* *! version 3.0  10oct2025  (unified GeoTIFF/NetCDF)}{...}
{vieweralsosee "[R] merge" "help merge"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] matchgeop" "help matchgeop"}{...}
{viewerjumpto "Syntax" "zonalstats##syntax"}{...}
{viewerjumpto "Description" "zonalstats##description"}{...}
{viewerjumpto "Options" "zonalstats##rasteropts"}{...}
{viewerjumpto "Remarks" "zonalstats##remarks"}{...}
{viewerjumpto "Examples" "zonalstats##examples"}{...}
{viewerjumpto "Stored results" "zonalstats##results"}{...}
{title:Title}

{phang}
{bf:zonalstats} {hline 2} Zonal statistics command for GeoTIFF and NetCDF raster files


{marker syntax}{...}
{title:Syntax}

{pstd}For GeoTiff files:{p_end}
{p 8 17 2}{cmd:zonalstats} {it:rasterfilename} {cmd:using} {it:shapefile}{cmd:,} {opt stats(string)} [{opt band(#)} {opt clear} {opt crs(string)}]{p_end}

{pstd}For NetCDF files:{p_end}
{p 8 17 2}{cmd:zonalstats} {it:rasterfilename} {cmd:using} {it:shapefile}{cmd:,} {opt stats(string)} {opt var(string)} [{opt clear} {opt origin(numlist)} {opt size(numlist)} {opt crs(string)}]{p_end}

{pstd}{it:rasterfilename} can be a GeoTIFF (.tif or .tiff) or NetCDF (.nc) file. The command automatically detects the file type and uses the appropriate processing method.{p_end}

{pstd}{it:shapefile} must include accompanying .shx .dbf (and ideally .prj) files.{p_end}

{marker description}{...}
{title:Description}

{pstd}{cmd:zonalstats} computes statistics of raster cell values aggregated over polygon zones defined in a shapefile. It supports both GeoTIFF and NetCDF raster files:{p_end}

{p 6 10 2}• {bf:GeoTIFF files}: Direct reading of one band from GeoTIFF files on disk.{p_end}
{p 6 10 2}• {bf:NetCDF files}: Reading and processing of NetCDF variables with optional slicing.{p_end}

{pstd}The command automatically detects the file type based on the file extension and uses the appropriate processing method.{p_end}

{pstd}Features:{p_end}
{p 8 12 2}• Reprojects the shapefile to match the raster CRS if needed.{p_end}
{p 8 12 2}• Supports multiple statistics (count avg min max std sum).{p_end}
{p 8 12 2}• Uses GeoTools Java libraries for spatial processing.{p_end}
{p 8 12 2}• Automatic CRS detection with fallback to user-specified CRS.{p_end}
{p 8 12 2}• NetCDF slicing support with {cmd:origin()} and {cmd:size()} options.{p_end}

{title:Dependencies}

{pstd}
The {cmd:crsconvert} command requires Java libraries from GeoTools and netCDF-Java.

{phang}
Run {cmd:geotools_init} to configure the GeoTools library path.

{phang}
Run {cmd:netcdf_init} to configure the netCDF-Java library path (pointing to netcdfAll-5.9.1.jar).

{marker rasteropts}{...}
{title:Options}

{dlgtab:Common options}
{pstd}{opt stats(string)} Statistics to compute; default {cmd:avg}. Any space separated subset of {cmd:count avg min max std sum}. Invalid names produce an error.{p_end}
{pstd}{opt clear} Clear current data in memory before loading results (required if data present).{p_end}
{pstd}{opt crs(string)} Coordinate reference system for the raster data. If the raster file contains CRS information, this option is ignored and a message is displayed. {p_end}

{dlgtab:GeoTIFF-specific options}
{pstd}{opt band(#)} Band index (1-based) for multi-band GeoTIFF. Default 1; must be >=1.{p_end}

{dlgtab:NetCDF-specific options}
{pstd}{opt var(string)} Variable name in the NetCDF file to process (required for NetCDF files).{p_end}
{pstd}{opt origin(numlist)} Origin coordinates (1-based) for slicing the NetCDF variable. Must be integers >0.{p_end}
{pstd}{opt size(numlist)} Size of each dimension for slicing. At most 2 dimensions can have size >1 (2D grid requirement).{p_end}

{marker remarks}{...}
{title:Remarks}

{pstd}{bf:File type detection.} The command automatically detects whether the input file is a GeoTIFF (.tif/.tiff) or NetCDF (.nc) file based on the file extension and uses the appropriate processing method.{p_end}

{pstd}{bf:NetCDF processing.} For NetCDF files, the command supports multi-dimensional data with automatic detection of 2D spatial grids (allowing singleton dimensions). Use {cmd:origin()} and {cmd:size()} options for slicing large datasets. At most 2 dimensions can have size >1 to maintain 2D grid requirements.{p_end}

{pstd}{bf:CRS handling.} The command attempts to automatically detect CRS from raster files. If CRS is found, user-provided {cmd:crs()} is ignored with a notification. If no CRS is detected and {cmd:crs()} is not provided, an error occurs. Shapefile is reprojected to match raster CRS when needed.{p_end}

{pstd}{bf:Performance tips.}{p_end}
{p 8 12 2}• Limit requested statistics to those needed.{p_end}
{p 8 12 2}• Use appropriate CRS in projected meters for large area analyses.{p_end}
{p 8 12 2}• Pre-filter polygons to study region before running.{p_end}
{p 8 12 2}• For large NetCDF files, use slicing with {cmd:origin()} and {cmd:size()} to process subsets.{p_end}
{p 8 12 2}• For very large rasters consider tiling externally; current command reads full needed extent.{p_end}

{marker examples}{...}
{title:Examples}

{phang}Nighttime lights statistics by city (sum + average):{p_end}
{phang2}{cmd:. zonalstats DMSP-like2020.tif using hunan.shp, stats("sum avg") clear}{p_end}

{phang}NetCDF with slicing (subset of data):{p_end}
{phang2}{cmd:. local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"}{p_end}
{phang2}{cmd:. ncread lon using `url'}{p_end}
{phang2}{cmd:. gen n=_n}{p_end}
{phang2}{cmd:. qui sum n if lon>=108 & lon<=115}{p_end}
{phang2}{cmd:. local lon_start = r(min)}{p_end}
{phang2}{cmd:. local lon_count = r(N)}{p_end}
{phang2}{cmd:. ncread lat using `url', clear}{p_end}
{phang2}{cmd:. gen n=_n}{p_end}
{phang2}{cmd:. qui sum n if lat>=24 & lat<=31}{p_end}
{phang2}{cmd:. local lat_start = r(min)}{p_end}
{phang2}{cmd:. local lat_count = r(N)}{p_end}
{phang2}{cmd:. zonalstats `url' using "hunan.shp", var(tas) stats(avg) origin(1 `lat_start' `lon_start') size(1 `lat_count' `lon_count') crs(EPSG:4326) clear}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}Output dataset (or results frame in vector mode) contains:{p_end}
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

{pstd}Each observation = one polygon zone. Statistics will not include nodata pixels.{p_end}

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
Online: {help geotools_init}, {help netcdf_init}
{p_end}
