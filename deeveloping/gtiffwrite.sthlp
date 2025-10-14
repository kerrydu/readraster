{smcl}
{* *! version 1.0  09oct2025}{...}
{vieweralsosee "[R] gtiffread" "help gtiffread"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] gzonalstats" "help gzonalstats"}{...}
{viewerjumpto "Syntax" "gtiffwrite##syntax"}{...}
{viewerjumpto "Description" "gtiffwrite##description"}{...}
{viewerjumpto "Options" "gtiffwrite##options"}{...}
{viewerjumpto "Examples" "gtiffwrite##examples"}{...}
{title:Title}

{phang}
{bf:gtiffwrite} {hline 2} Write Stata grid data to GeoTIFF raster file


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:gtiffwrite} {it:outfile}{cmd:,} [{opt xvar(varname)} {opt yvar(varname)} {opt valuevar(varname)} {opt crs(string)} {opt nodata(#)} {opt resolution(# #)} {opt replace}]

{pstd}
{it:outfile} is the path to the output GeoTIFF file. The current dataset must contain grid data with x, y coordinates and values.


{marker description}{...}
{title:Description}

{pstd}
{cmd:gtiffwrite} creates a GeoTIFF raster file from Stata data containing regular grid coordinates and values. This is the inverse operation of {help gtiffread}, which vectorizes a GeoTIFF into Stata variables.

{pstd}
The command assumes the data represents a regular rectangular grid. It infers grid dimensions and resolution from the data unless explicitly specified.


{marker options}{...}
{title:Options}

{dlgtab:Variable names}
{phang}
{opt xvar(varname)} specifies the variable containing x-coordinates (longitude or easting). Default is {cmd:x}.

{phang}
{opt yvar(varname)} specifies the variable containing y-coordinates (latitude or northing). Default is {cmd:y}.

{phang}
{opt valuevar(varname)} specifies the variable containing cell values. Default is {cmd:value}.

{dlgtab:Spatial parameters}
{phang}
{opt crs(string)} specifies the coordinate reference system for the output GeoTIFF. Default is {cmd:EPSG:4326} (WGS84 geographic).

{phang}
{opt nodata(#)} specifies the NoData value for the raster. Default is {cmd:-9999}.

{phang}
{opt resolution(# #)} specifies the x and y resolution (pixel size) in coordinate units. If not specified, resolution is inferred from the data assuming a regular grid.

{dlgtab:File options}
{phang}
{opt replace} allows overwriting an existing file.


{marker examples}{...}
{title:Examples}

{phang}Basic usage with default variable names:{p_end}
{phang2}{cmd:. gtiffwrite output.tif}

{phang}Specify custom variable names and CRS:{p_end}
{phang2}{cmd:. gtiffwrite myraster.tif, xvar(lon) yvar(lat) valuevar(temp) crs(EPSG:3857)}

{phang}Set custom NoData value and resolution:{p_end}
{phang2}{cmd:. gtiffwrite processed.tif, nodata(-999) resolution(1000 1000) replace}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:gtiffwrite} does not store results in {cmd:r()}.


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
Online: {help gtiffread}, {help geotools_init}{p_end}


