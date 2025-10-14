{smcl}
{* *! version 1.0.0  2024-01-01}{...}
{vieweralsosee "[R] nzonalstats" "mansection R nzonalstats"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "gzonalstats" "help gzonalstats"}{...}
{vieweralsosee "gtiffread" "help gtiffread"}{...}
{vieweralsosee "ncread" "help ncread"}{...}
{viewerjumpto "Syntax" "nzonalstats##syntax"}{...}
{viewerjumpto "Description" "nzonalstats##description"}{...}
{viewerjumpto "Options" "nzonalstats##options"}{...}
{viewerjumpto "Examples" "nzonalstats##examples"}{...}
{viewerjumpto "Author" "nzonalstats##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col :{manlink R nzonalstats} {hline 2}}NetCDF zonal statistics{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:nzonalstats} {it:shapefile} {cmd:using} {it:netcdf_file}{cmd:,}
{opt var(varname)} [{opt stats(stats_list)} {opt clear}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt var(varname)}}NetCDF variable name to analyze (required){p_end}
{synopt :{opt stats(stats_list)}}statistics to compute; default is {cmd:avg}{p_end}
{synopt :{opt clear}}replace data in memory{p_end}
{synoptline}
{p2colreset}{...}

{p 4 6 2}
where {it:stats_list} is one or more of: {cmd:count}, {cmd:avg}, {cmd:min}, {cmd:max}, {cmd:std}, {cmd:sum}


{marker description}{...}
{title:Description}

{pstd}
{cmd:nzonalstats} computes zonal statistics for NetCDF raster data using polygon features from a shapefile.
It calculates statistics for each polygon zone by overlaying the shapefile polygons on the NetCDF variable data.

{pstd}
The command supports NetCDF variables with 2 or more dimensions, but only processes the spatial dimensions.
Variables with more than 2 non-singleton dimensions are not supported. For example, a variable with shape (1,1,5,6)
is treated as 2D spatial data since the first two dimensions have length 1.

{pstd}
The NetCDF file must contain coordinate information (longitude/latitude or x/y variables) for proper spatial referencing.
The command attempts to extract coordinate reference system (CRS) information from the NetCDF file attributes.


{marker options}{...}
{title:Options}

{phang}
{opt var(varname)} specifies the NetCDF variable name to analyze. This option is required.

{phang}
{opt stats(stats_list)} specifies which statistics to compute. Multiple statistics can be specified
separated by spaces. Available statistics are:

{p2colset 9 18 20 2}{...}
{p2col :{cmd:count}}number of valid pixels in each zone{p_end}
{p2col :{cmd:avg}}average pixel value in each zone{p_end}
{p2col :{cmd:min}}minimum pixel value in each zone{p_end}
{p2col :{cmd:max}}maximum pixel value in each zone{p_end}
{p2col :{cmd:std}}standard deviation of pixel values in each zone{p_end}
{p2col :{cmd:sum}}sum of pixel values in each zone{p_end}
{p2colreset}{...}

{pmore}
If not specified, only the average ({cmd:avg}) is computed.

{phang}
{opt clear} specifies that it is okay to replace the data in memory, even if the current dataset has not been saved to disk.


{marker examples}{...}
{title:Examples}

{phang}{cmd:. nzonalstats hunan.shp using temperature.nc, var(temp) stats(avg min max)}{p_end}
{pstd}Compute average, minimum, and maximum temperature for each polygon in hunan.shp using the "temp" variable from temperature.nc{p_end}

{phang}{cmd:. nzonalstats regions.shp using climate.nc, var(precipitation) stats(count sum) clear}{p_end}
{pstd}Compute pixel count and total precipitation sum for each region, replacing any existing data in memory{p_end}

{phang}{cmd:. nzonalstats zones.shp using data.nc, var(elevation)}{p_end}
{pstd}Compute average elevation for each zone (default statistic){p_end}


{marker author}{...}
{title:Author}

{pstd}
Kerry Du{p_end}
{pstd}
Department of Geography, Environment, and Spatial Sciences{p_end}
{pstd}
Michigan State University{p_end}
{pstd}
Email: {browse "mailto:kerrydu@msu.edu":kerrydu@msu.edu}{p_end}

{pstd}
This command is part of the GeoTools Stata package for geospatial data processing.{p_end}

{marker also_see}{...}
{title:Also see}

{psee}
Online:  {manhelp gzonalstats R}, {manhelp gtiffread R}, {manhelp ncread R}
{p_end}