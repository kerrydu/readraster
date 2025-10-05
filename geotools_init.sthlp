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

{pstd}
Before using the commands {cmd:gtiffdisp}, {cmd:gtiffread}, {cmd:crsconvert}, and {cmd:gzonalstats}, you first need to download the GeoTools Version 32.0 Java library. Once downloaded, place this library in Stata’s adopath — or add the library’s file path to Stata’s adopath. 

{pstd}
Users only need to initialize the Java dependencies upon their first use. And if the files in "geotools-32.0/lib" are moved, the setup process will need to be repeated.

{marker examples}{...}
{title:Examples}

{pstd}To configure the environment automatically, simply run the following line:{p_end}
{phang2}{cmd:. geotools_init, download plus(geotools)}{p_end}

{pstd}Note that this process may take dozens of minutes—Stata’s speed for copying large files from the internet is relatively slow. As a faster alternative, we recommend manually downloading the GeoTools 32.0 package from Sourceforge (https://sourceforge.net/projects/geotools/files/GeoTools\%2032\%20Releases/32.0/) and unzipping the downloaded file. After doing so, initialize the environment by running teh following command. And you should replace "C:/Users/17286/Documents/geotools-32.0/lib/" with the actual file path to your unzipped GeoTools 32.0 lib folder.{p_end}
{phang2}{cmd:. geotools_init "C:/Users/17286/Documents/geotools-32.0/lib/", plus(geotools)}{p_end}

{title:Authors}
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
Online:  {help gtiffdisp}, {help gtiffread}, {help gzonalstats}, {help crsconvert}
{p_end}



