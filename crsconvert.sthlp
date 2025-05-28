{smcl}
{* *! version 1.0  07sep2024}{...}
{vieweralsosee "[D] import" "mansection D import"}{...}
{viewerjumpto "Syntax" "crsconvert##syntax"}{...}
{viewerjumpto "Description" "crsconvert##description"}{...}
{viewerjumpto "Options" "crsconvert##options"}{...}
{viewerjumpto "Examples" "crsconvert##examples"}{...}
{title:Title}

{phang}
{bf:crsconvert} {hline 2} Convert coordinates between different coordinate reference systems in the GeoTIFF file

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
The {cmd:crsconvert} command requires Java libraries from GeoTools. Use geotools_init for setting up.


{marker options}{...}
{title:Options}


{phang}
{opt gen(prefix_)} specifies the prefix for the two new variables that will contain the transformed coordinates. The new variables will be named {it:prefix_}x and {it:prefix_}y.

{phang}
{opt from(string, tif shp)} specifies the source coordinate reference system. It might be provided in EPSG format(e.g. "EPSG:4326"). The coordinate reference system can be provided in EPSG format (e.g., "EPSG:4326"). 
Alternatively, users have the option to specify a GeoTIFF file (SHP file) using the {opt tif} ({opt shp}) option to denote the source of the coordinate reference system.
This approach is highly practical, considering that the coordinate reference system sometimes may not conform to a standard EPSG format and instead contains detailed projection parameters.
If a file is specified, the command automatically identify its coordinate reference system.

{phang}
{opt to(string, tif shp)}  specifies the source coordinate reference system. It might be provided in EPSG format(e.g. "EPSG:4326"). 
Alternatively, users have the option to specify a GeoTIFF file (SHP file) using the {opt tif} ({opt shp}) option to denote the source of the coordinate reference system. 

{marker examples}{...}
{title:Examples}

{pstd}convert the coordinate system of the hunan.shp to the coordinate system of the DMSP-like2020.tif:{p_end}
{phang2}{cmd:. shp2dta using "hunan.shp", database(hunan_db) coordinates(hunan_coord) genid(id)}{p_end}

{phang2}{cmd:. use "hunan_coord.dta",clear}{p_end}

{phang2}{cmd:. drop if missing(_X, _Y)}{p_end}

{phang2}{cmd:. crsconvert _X _Y, gen(alber_) from(hunan.shp) to(DMSP-like2020.tif)}{p_end}


{title:Author}

{pstd}Kerry Du{p_end}
{pstd}School of Managemnet, Xiamen University, China{p_end}
{pstd}Email: kerrydu@xmu.edu.cn{p_end}

{pstd}Chunxia Chen{p_end}
{pstd}School of Managemnet, Xiamen University, China{p_end}
{pstd}Email: 35720241151353@stu.xmu.edu.cn

{pstd}Shuo Hu{p_end}
{pstd}School of Economics, Southwestern University of Finance and Economics, China{p_end}
{pstd}advancehs@163.com{p_end}

{pstd}Yang Song{p_end}
{pstd}School of Economics, Hefei University of Technology, China{p_end}
{pstd}Email: ss0706082021@163.com

{pstd}Ruipeng Tan{p_end}
{pstd}School of Economics, Hefei University of Technology, China{p_end}
{pstd}Email: tanruipeng@hfut.edu.cn


