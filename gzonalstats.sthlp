{smcl}
{* *! version 1.0  29jul2024}{...}
{vieweralsosee "[R] merge" "help merge"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] geonear" "help geonear"}{...}
{viewerjumpto "Syntax" "gzonalstats##syntax"}{...}
{viewerjumpto "Description" "gzonalstats##description"}{...}
{viewerjumpto "Options" "gzonalstats##options"}{...}
{viewerjumpto "Examples" "gzonalstats##examples"}{...}
{title:Title}

{phang}
{bf:gzonalstats} {hline 2} Compute zonal statistics from raster data based on vector zones


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:gzonalstats} {it:rasterfilename} {cmd:, shpfile}({it:filename}) [{cmd:,} {it:option}]

{p 8 17 2}
{cmd:shpfile}({it:filename}) specifies the path to the shapefile (.shp) containing polygon zones.This option is required. The shapefile must have the associated files (.shx and .dbf) in the same directory.


{marker description}{...}
{title:Description}

{pstd}
{cmd:gzonalstats} calculates zonal statistics for raster data (GeoTIFF) using polygon zones defined in a shapefile. It computes statistics of pixel values within each polygon zone.The program uses Java and the GeoTools library to process spatial data, handling coordinate system reprojection automatically if the shapefile and raster have different coordinate reference systems.

{title:Dependencies}

{pstd}
The {cmd:gzonalstats} command requires Java libraries from GeoTools. Use {cmd:geotools_init} for setting up.

{marker options}{...}
{title:Options}

{phang}
{opt stat:s(string)} specifies which statistics to calculate. Default is "avg" if not specified. Valid options are:

{p 12 16 2}
{opt count}: the number of pixels in zone{break}

{p 12 16 2}
{opt avg}: the average pixel value{break}

{p 12 16 2}
{opt min}: the minimum pixel value{break}

{p 12 16 2}
{opt max}: the maximum pixel value{break}

{p 12 16 2}
{opt std}: the standard deviation of pixel values{break}

{p 12 16 2}
{opt sum}: the sum of pixel values{break}

{phang}
{opt band(#)} specifies  which raster band to use in multi-band raster files. Default is 1 (first band). Must be >= 1.

{phang}
{opt clear} clears the current dataset for importing data.



{marker examples}{...}
{title:Examples}

{phang}
Calculate sum and average nighttime light for each city in Hunan:

{p 12 16 2}
{cmd:. gzonalstats DMSP-like2020.tif using hunan.shp, stats("sum avg") clear}{break}


{hline}

{title:Author}

{pstd}Kerry Du{p_end}
{pstd}School of Managemnet, Xiamen University, China{p_end}
{pstd}Email: kerrydu@xmu.edu.cn{p_end}

{pstd}Chunxia Chen{p_end}
{pstd}School of Managemnet, Xiamen University, China{p_end}
{pstd}Email: 35720241151353@stu.xmu.edu.cn

{pstd}Yang Song{p_end}
{pstd}School of Economics, Hefei University of Technology, China{p_end}
{pstd}Email: ss0706082021@163.com

{pstd}Ruipeng Tan{p_end}
{pstd}School of Economics, Hefei University of Technology, China{p_end}
{pstd}Email: tanruipeng@hfut.edu.cn

{title:Also see}

{psee}
Online:  {help geotools_init}
{p_end}

