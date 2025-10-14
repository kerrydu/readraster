{smcl}
{* *! version 1.0  07sep2024}{...}
{vieweralsosee "[D] import" "mansection D import"}{...}
{viewerjumpto "Syntax" "ncread##syntax"}{...}
{viewerjumpto "Description" "ncread##description"}{...}
{viewerjumpto "Options" "ncread##options"}{...}
{viewerjumpto "Examples" "ncread##examples"}{...}
{title:Title}

{phang}
{bf:gtiffread} {hline 2} Read data from GeoTIFF file

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:gtiffread} {it:filename} [{cmd:,} {it: option}]

{marker description}{...}
{title:Description}

{pstd}
The {cmd:gtiffread} command is used to extract pixel values with their corresponding coordinates.The command supports reading specific bands, subsetting 
by origin and size, and optional coordinate system conversion.

{marker Dependencies}{...}
{title:Dependencies}

{pstd}
The {cmd:gtiffread} command requires Java libraries from GeoTools. Use {cmd:geotools_init} for setting up.


{marker options}{...}
{title:Options}


{phang}
{opt clear} clears the current dataset for importing data. 

{phang}
{opt band(#)} specifies which band to read from the GeoTIFF, Default is 1.

{phang}
{opt origin(numlist)} specifies the starting position for reading ((row col)). Must be used together with the size option.By default, it starts from beginning (1,1)

{phang}
{opt size(numlist)} specifies the number of rows and columns to read. 

{phang}
{opt crs:code(string)} specifies the target coordinate reference system code. Can be an EPSG code (e.g., "EPSG:4326"), a path to a GeoTIFF file with the desired CRS, or a path to a shapefile with the desired CRS.
Defaults to the GeoTIFF's native CRS if not specified.
                        
{marker examples}{...}
{title:Examples}


{pstd}Read the entire values from a GeoTIFF file:{p_end}
{phang2}{cmd:. gtiffread DMSP-like2020.tif, clear}{p_end}

{pstd}Read values with a specific coordinate system:{p_end}
{phang2}{cmd:. gtiffread DMSP-like2020.tif, crscode("EPSG:4326") clear}{p_end}

{pstd}Read subset starting at row 100, column 200, with size 500x500 :{p_end}
{phang2}{cmd:. gtiffread DMSP-like2020.tif, origin(100 200) size(500 500) clear}{p_end}


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
Online:  {help geotools_init}, {help gtiffdisp}
{p_end}



