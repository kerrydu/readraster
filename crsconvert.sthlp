{smcl}
{* *! version 2.0  11oct2025}{...}
{vieweralsosee "[D] import" "mansection D import"}{...}
{viewerjumpto "Syntax" "crsconvert##syntax"}{...}
{viewerjumpto "Description" "crsconvert##description"}{...}
{viewerjumpto "Options" "crsconvert##options"}{...}
{viewerjumpto "Examples" "crsconvert##examples"}{...}
{title:Title}

{phang}
{bf:crsconvert} {hline 2} Convert coordinates between different coordinate reference systems

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:crsconvert} {it:varlist}, {cmd:gen({it:string})} {cmd:from({it:string})} {cmd:to({it:string})}

{p 8 17 2}
varlist must contain exactly two numeric variables representing x and y coordinates in the source coordinate reference system.


{marker description}{...}
{title:Description}

{pstd}
The {cmd:crsconvert} command converts coordinates from one coordinate reference system to another. It creates two new variables containing the transformed coordinates.

{marker Dependencies}{...}
{title:Dependencies}

{pstd}
The {cmd:crsconvert} command requires Java libraries from GeoTools. Use {cmd:geotools_init} for setting up.


{marker options}{...}
{title:Options}


{phang}
{opt gen(prefix_)} specifies the prefix for the two new variables that will contain the transformed coordinates. The new variables will be named {it:prefix_}x and {it:prefix_}y.

{phang}
{opt from(string)} specifies the source coordinate reference system. It can be provided in EPSG format (e.g., "EPSG:4326") or as a WKT string. 
Alternatively, users can specify a GeoTIFF (.tif/.tiff), Shapefile (.shp), or NetCDF (.nc) file to automatically extract the coordinate reference system from the file.

{phang}
{opt to(string)} specifies the target coordinate reference system. It can be provided in EPSG format (e.g., "EPSG:4326") or as a WKT string. 
Alternatively, users can specify a GeoTIFF (.tif/.tiff), Shapefile (.shp), or NetCDF (.nc) file to automatically extract the coordinate reference system from the file. 

{marker examples}{...}
{title:Examples}

{pstd}Convert coordinates using EPSG codes:{p_end}
{phang2}{cmd:. crsconvert lon lat, gen(utm_) from("EPSG:4326") to("EPSG:32633")}{p_end}

{pstd}Convert coordinates from GeoTIFF CRS to WGS84:{p_end}
{phang2}{cmd:. crsconvert x y, gen(wgs84_) from(dem.tif) to("EPSG:4326")}{p_end}

{pstd}Convert coordinates from NetCDF CRS to Shapefile CRS:{p_end}
{phang2}{cmd:. crsconvert lon lat, gen(projected_) from(climate_data.nc) to(boundary.shp)}{p_end}

{pstd}Convert coordinates between two NetCDF files:{p_end}
{phang2}{cmd:. crsconvert x y, gen(reproj_) from(input.nc) to(reference.nc)}{p_end}


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


