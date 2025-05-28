{smcl}
{*}
{hline}
{title:Title}

{phang}
{bf:gtiffdisp} {hline 2} Display metadata from GeoTIFF files

{hline}

{title:Syntax}

{phang}
{cmd:gtiffdisp} {it:file(string)}

{title:Description}

{pstd}
{cmd:gtiffdisp} is used to display the information from GeoTIFF files including dimensions, bands, spatial characteristics, coordinate systems, and other metadata.

{title:Dependencies}

{pstd}
The {cmd:gtiffdisp} command requires Java libraries from GeoTools. Use {cmd:geotools_init} for setting up.


{title:Options}
{phang}
{opt file(string)} specifies the path to the GeoTIFF file.

{title:Stored results}

{phang}
gtiffdisp stores the following in r():

{phang}
scalar

{phang}
{opt r(nband)} returns the number of bands.

{phang}
{opt r(ncol)} returns the number of columns (width).

{phang}
{opt r(nrow)} returns the number of rows (height).

{phang}
{opt r(minX)} returns the minimum X coordinate.

{phang}
{opt r(minY)} returns the minimum Y coordinate.

{phang}
{opt r(maxX)} returns the maximum X coordinate.

{phang}
{opt r(maxY)} returns the maximum Y coordinate.

{phang}
{opt r(Xcellsize)} returns the X resolution (pixel size).

{phang}
{opt r(Ycellsize)} returns the Y resolution (pixel size).



{title:Examples}

{phang}
Display the Metadata of a GeoTIFF File:

{p 12 16 2}
{cmd:.gtiffdisp DMSP-like2020.tif}{break}


{hline}

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



