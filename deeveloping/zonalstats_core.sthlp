{smcl}
{* *! version 1.0  08oct2025}{...}
{vieweralsosee "[R] merge" "help merge"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] gzonalstats" "help gzonalstats"}{...}
{viewerjumpto "Syntax" "zonalstats_core##syntax"}{...}
{viewerjumpto "Description" "zonalstats_core##description"}{...}
{viewerjumpto "Options" "zonalstats_core##options"}{...}
{viewerjumpto "Remarks" "zonalstats_core##remarks"}{...}
{viewerjumpto "Examples" "zonalstats_core##examples"}{...}
{title:Title}

{phang}
{bf:zonalstats_core} {hline 2} Compute zonal statistics from vector data in memory


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:zonalstats_core} {cmd:using} {it:shpfile}{cmd:,} {opt xvar(varname)} {opt yvar(varname)} {opt valuevar(varname)} {opt frame(name)} {opt crs(string)} [{it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt xvar(varname)}}variable containing X coordinates (longitude){p_end}
{synopt:{opt yvar(varname)}}variable containing Y coordinates (latitude){p_end}
{synopt:{opt valuevar(varname)}}variable containing pixel/cell values{p_end}
{synopt:{opt frame(name)}}name of the frame to store results{p_end}
{synopt:{opt crs(string)}}coordinate reference system specification{p_end}

{syntab:Optional}
{synopt:{opt stat:s(string)}}statistics to calculate; default is {cmd:avg}{p_end}
{synopt:{opt nodata(#)}}value to treat as missing data; default is -9999{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:zonalstats_core} calculates zonal statistics from vector data (points with coordinates and values) in Stata's memory using polygon zones defined in a shapefile. Unlike {cmd:gzonalstats}, which reads raster data from a GeoTIFF file, {cmd:zonalstats_core} converts vector data in memory into a temporary raster grid and then computes statistics for each polygon zone.

{pstd}
The command is particularly useful when you have:

{p 8 12 2}• Point data with coordinates and values already loaded in Stata{p_end}
{p 8 12 2}• Data from models or simulations that need spatial aggregation{p_end}
{p 8 12 2}• Regularly gridded data stored in vector format{p_end}

{pstd}
The program automatically:

{p 8 12 2}• Constructs a raster grid from your vector data{p_end}
{p 8 12 2}• Handles coordinate system transformations{p_end}
{p 8 12 2}• Reprojects the shapefile if necessary to match your data's CRS{p_end}
{p 8 12 2}• Stores results in a specified frame to preserve your original data{p_end}

{title:Dependencies}

{pstd}
The {cmd:zonalstats_core} command requires Java libraries from GeoTools. Use {cmd:geotools_init} to set up the required dependencies.


{marker options}{...}
{title:Options}

{dlgtab:Required Options}

{phang}
{opt xvar(varname)} specifies the variable containing X coordinates (typically longitude). The data should represent regularly spaced grid cells.

{phang}
{opt yvar(varname)} specifies the variable containing Y coordinates (typically latitude). The data should represent regularly spaced grid cells.

{phang}
{opt valuevar(varname)} specifies the variable containing the values to aggregate within each zone (e.g., temperature, precipitation, nighttime lights).

{phang}
{opt frame(name)} specifies the name of a new frame where results will be stored. The frame must not already exist. This preserves your original data while creating a new dataset with zonal statistics.

{phang}
{opt crs(string)} specifies the coordinate reference system (CRS) for your vector data. This is required to properly align your data with the shapefile. Three formats are supported:

{p 12 16 2}• EPSG code: {cmd:crs(EPSG:4326)}{break}
{p 12 16 2}• Reference TIF file: {cmd:crs("reference.tif", tif)}{break}
{p 12 16 2}• Reference shapefile: {cmd:crs("reference.shp", shp)}{break}
{p 12 16 2}• Reference NetCDF file: {cmd:crs("reference.nc", nc)}{p_end}

{dlgtab:Optional}

{phang}
{opt stat:s(string)} specifies which statistics to calculate. Default is {cmd:avg}. You can specify multiple statistics separated by spaces. Valid options are:

{p 12 16 2}{cmd:count} - the number of pixels in each zone{break}
{p 12 16 2}{cmd:avg} - the average pixel value{break}
{p 12 16 2}{cmd:min} - the minimum pixel value{break}
{p 12 16 2}{cmd:max} - the maximum pixel value{break}
{p 12 16 2}{cmd:std} - the standard deviation of pixel values{break}
{p 12 16 2}{cmd:sum} - the sum of pixel values{p_end}

{phang}
{opt nodata(#)} specifies the value to treat as missing/no data. Default is -9999. Cells with this value will be excluded from statistics calculations.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Data Requirements:}

{pstd}
Your data must represent a regular grid. The command automatically detects:

{p 8 12 2}• Grid resolution (spacing between points){p_end}
{p 8 12 2}• Grid dimensions (width and height){p_end}
{p 8 12 2}• Bounding box (extent){p_end}

{pstd}
While the data doesn't need to be sorted, having unique coordinates for each observation improves performance. If coordinates are duplicated, the last value is used.

{pstd}
{bf:Coordinate Reference Systems:}

{pstd}
Specifying the correct CRS is critical. Common CRS choices:

{p 8 12 2}• WGS84 (geographic): {cmd:EPSG:4326} - for global data in degrees{p_end}
{p 8 12 2}• Web Mercator: {cmd:EPSG:3857} - for web mapping applications{p_end}
{p 8 12 2}• UTM zones: {cmd:EPSG:32633}, etc. - for regional data in meters{p_end}

{pstd}
If your data CRS doesn't match the shapefile CRS, the command automatically reprojects the shapefile to match your data.

{pstd}
{bf:Working with Frames:}

{pstd}
Results are stored in a new frame, keeping your original data intact. After the command completes:

{p 8 12 2}• The current frame will be the results frame{p_end}
{p 8 12 2}• Use {cmd:frame change} to switch between frames{p_end}
{p 8 12 2}• Use {cmd:frame dir} to list all frames{p_end}

{pstd}
{bf:Performance Considerations:}

{pstd}
For large datasets:

{p 8 12 2}• Grid size affects memory usage (width × height × 8 bytes per cell){p_end}
{p 8 12 2}• Complex polygons with many vertices take longer to process{p_end}
{p 8 12 2}• Consider aggregating data before computing zonal statistics{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic usage with WGS84 coordinates}

{phang2}{cmd:. use temperature_grid, clear}{p_end}
{phang2}{cmd:. zonalstats_core using "admin_boundaries.shp", ///}{p_end}
{phang2}{cmd:     xvar(longitude) yvar(latitude) valuevar(temp) ///}{p_end}
{phang2}{cmd:     frame(zone_results) crs(EPSG:4326)}{p_end}

{pstd}
{bf:Example 2: Multiple statistics with custom no-data value}

{phang2}{cmd:. use precipitation_data, clear}{p_end}
{phang2}{cmd:. zonalstats_core using "watersheds.shp", ///}{p_end}
{phang2}{cmd:     xvar(x) yvar(y) valuevar(rainfall) ///}{p_end}
{phang2}{cmd:     frame(precip_stats) crs(EPSG:4326) ///}{p_end}
{phang2}{cmd:     stats("count avg sum min max std") nodata(-999)}{p_end}

{pstd}
{bf:Example 3: Using a reference file for CRS}

{phang2}{cmd:. use nightlight_grid, clear}{p_end}
{phang2}{cmd:. zonalstats_core using "cities.shp", ///}{p_end}
{phang2}{cmd:     xvar(lon) yvar(lat) valuevar(luminosity) ///}{p_end}
{phang2}{cmd:     frame(city_lights) crs("reference_raster.tif", tif) ///}{p_end}
{phang2}{cmd:     stats("avg sum")}{p_end}

{pstd}
{bf:Example 4: Switching between frames}

{phang2}{cmd:. use elevation_grid, clear}{p_end}
{phang2}{cmd:. pwf}{p_end}
{phang2}{it:(Shows current frame name, e.g., "default")}{p_end}

{phang2}{cmd:. zonalstats_core using "regions.shp", ///}{p_end}
{phang2}{cmd:     xvar(x) yvar(y) valuevar(elevation) ///}{p_end}
{phang2}{cmd:     frame(elevation_zones) crs(EPSG:32633) ///}{p_end}
{phang2}{cmd:     stats("avg min max")}{p_end}

{phang2}{cmd:. pwf}{p_end}
{phang2}{it:(Now shows "elevation_zones")}{p_end}

{phang2}{cmd:. list in 1/10}{p_end}
{phang2}{it:(Shows results with zone IDs and statistics)}{p_end}

{phang2}{cmd:. frame change default}{p_end}
{phang2}{it:(Returns to original data)}{p_end}

{pstd}
{bf:Example 5: Using NetCDF CRS reference}

{phang2}{cmd:. use climate_data, clear}{p_end}
{phang2}{cmd:. zonalstats_core using "countries.shp", ///}{p_end}
{phang2}{cmd:     xvar(longitude) yvar(latitude) valuevar(temperature) ///}{p_end}
{phang2}{cmd:     frame(country_climate) crs("climate.nc", nc) ///}{p_end}
{phang2}{cmd:     stats("avg min max std")}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:zonalstats_core} creates a new frame containing:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Variables}Description{p_end}
{synoptline}
{synopt:{it:zone_id_vars}}All non-geometry attributes from the shapefile{p_end}
{synopt:{cmd:count}}Number of pixels in zone (if requested){p_end}
{synopt:{cmd:avg}}Average pixel value in zone (if requested){p_end}
{synopt:{cmd:min}}Minimum pixel value in zone (if requested){p_end}
{synopt:{cmd:max}}Maximum pixel value in zone (if requested){p_end}
{synopt:{cmd:std}}Standard deviation of pixels in zone (if requested){p_end}
{synopt:{cmd:sum}}Sum of pixel values in zone (if requested){p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Each observation in the results frame represents one polygon zone from the shapefile.


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
Online:  {help gzonalstats}, {help geotools_init}, {help netcdf_init}
{p_end}
