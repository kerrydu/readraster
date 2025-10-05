{smcl}
{* 14July2016}{...}
{hline}
help for {hi:geotools_init}
{hline}

{title:Title}

{phang}
{bf:geotools_init} {hline 2} Initialize the GeoTools Java library for Stata

{hline}

{title:Syntax}

{p 4 10 2}
{cmd:geotools_init }[{it:pathofjar}] [{cmd:,} {it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}

{synopt :{opt download}}specify downloading GeoTools 32.0 library from SourceForge{p_end}
{synopt :{opt dir(string)}}specify the directory where GeoTools should be downloaded (defaults to current directory){p_end}
{synopt :{opt plus(string)}}copy JAR files to the specified folder in sysdir_plus{p_end}

{synoptline}

{marker description}{...}
{title:Description}

{pstd}
The {cmd:geotools_init} command is used to downloads, installs, and configures the GeoTools 32.0 Java library for use with Stata.
GeoTools is an open source Java library that provides tools for geospatial data manipulation.
 
{marker examples}{...}
{title:Examples}

{phang}
1. Download and setup GeoTools in the current directory:

{p 12 16 2}
{cmd:.geotools_init, download}{break}

{phang}
2. manually download the GeoTools package from https://sourceforge.net/projects/geotools/files/GeoTools%2032%20Releases/32.0/ and set up the Java dependence:

{p 12 16 2}
{cmd:.geotools_init "C:/Users/17286/Documents/geotools-32.0/lib/"}{break}


{hline}


{title:Authors}
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

