{smcl}
{* *! version 1.2.0  10oct2025}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "Install readraster" "ssc install readraster"}{...}
{viewerjumpto "Syntax" "readraster##syntax"}{...}
{viewerjumpto "Description" "readraster##description"}{...}
{viewerjumpto "Commands" "readraster##commands"}{...}
{viewerjumpto "Setup" "readraster##setup"}{...}
{viewerjumpto "Examples" "readraster##examples"}{...}
{viewerjumpto "Author" "readraster##author"}{...}
{title:Title}

{phang}
{bf:readraster} {hline 2} A package for reading and processing geospatial raster data in Stata


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
This package provides multiple commands for different geospatial data operations


{marker description}{...}
{title:Description}

{pstd}
{cmd:readraster} is an advanced Stata package designed for importing, processing, and analyzing geospatial raster data directly within Stata. 
The package supports multiple raster formats including GeoTIFF files and NetCDF files, making it invaluable for researchers working with 
satellite imagery, climate data, digital elevation models, nighttime lights, and other gridded spatial datasets.

{pstd}
The package bridges the gap between Geographic Information Systems (GIS) and statistical analysis by enabling users to:
import raster data with coordinate information, perform zonal statistics calculations, convert between coordinate reference systems,
match geographic datasets, and process multi-dimensional climate/environmental data.

{pstd}
{cmd:readraster} leverages Java libraries (GeoTools and NetCDF) to provide robust geospatial data processing capabilities,
automatically handling coordinate system transformations and spatial operations.


{marker requirements}{...}
{title:Requirement}

{dlgtab:System Requirements}

{phang}
{bf:Stata Version}: Stata 17 or later version is required
{p_end}

{marker installization}{...}
{title:Installization}


{phang}
Installing the package from SSC:
{p_end}

{phang2}{cmd:. ssc install readraster}{p_end}


{phang}
Installing the latest developed version from Github:
{p_end}

{phang2}{cmd:. net install readraster, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/develop/)}{p_end}


{phang}
Downloading demo code and data from Github:
{p_end}

{phang2}{cmd:. net get readraster, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/develop/)}{p_end}


{marker commands}{...}
{title:Available Commands}

{pstd}
The {cmd:readraster} package includes the following commands organized by functionality:

{dlgtab:GeoTIFF Operations}

{phang2}
{help gtiffdisp:gtiffdisp} - Display metadata information from GeoTIFF files

{phang2}
{help gtiffread:gtiffread} - Read pixel values and coordinates from GeoTIFF files

{dlgtab:NetCDF Operations}

{phang2}
{help ncdisp:ncdisp} - Display structure and metadata of NetCDF files

{phang2}
{help ncread:ncread} - Read variables from NetCDF files with support for multi-dimensional data

{dlgtab:Spatial Analysis}


{phang2}
{help zonalstats:zonalstats} - Calculate zonal statistics from raster data in Stata for areas of interest

{phang2}
{help matchgeop:matchgeop} - Match datasets based on geographic proximity and location

{phang2}
{help crsconvert:crsconvert} - Convert coordinates between different coordinate reference systems

{dlgtab:Setup Commands}

{phang2}
{help geotools_init:geotools_init} - Configurate GeoTools Java library for GeoTIFF operations

{phang2}
{help netcdf_init:netcdf_init} - Configurate NetCDF Java library for NetCDF operations

{marker setup}{...}
{title:Setup Java dependencies}

{dlgtab:Overview}

{pstd}
The {cmd:readraster} package requires Java runtime environment and specific Java libraries to handle geospatial raster data processing.
{p_end}

{pstd}
{bf:We offer two distinct methods to use the package:}
{p_end}

{phang2}1) Via our precompiled JARs{p_end}
{phang2}2) Via JShell with Java source code{p_end}

{pstd}
{bf:For method 1) via precompiled JARs (Recommended):}
{p_end}

{pstd}
Java JDK 17 or JDK 21 is required and the precompiled jars can be downloaded by:
{p_end}

{phang2}{cmd:. geotools_init, compiled}{p_end}
{phang2}{cmd:. netcdf_init, compiled}{p_end}

{pstd}
Note: Stata 17 is bundled with JDK 11, so users are required to manually install and configure JDK 17. See the following instruction for the configuration of JDK 17 in Stata 17.
{p_end}

{pstd}
{bf:For method 2) via JShell with Java source code:}
{p_end}

{pstd}
JDK 17 and specific Java libraries are required. See the following instruction for GeoTools and NetCDF library setup.
{p_end}

{dlgtab:Configure Java JDK 17}

{pstd}
If you are using Stata 17 or Stata 19, you need to download and install Java JDK 17, then configure it in Stata. Stata 18 includes a compatible Java runtime environment. No additional Java JDK installation or configuration is required.
{p_end}

{dlgtab:Step 1: Download and Install Java JDK 17}

{pstd}
Download and install Java JDK 17 from the official Oracle website or OpenJDK distributions:
{p_end}

{phang2}• Oracle JDK: {browse "https://www.oracle.com/java/technologies/downloads/"}{p_end}
{phang2}• OpenJDK: {browse "https://openjdk.org/"}{p_end}

{dlgtab:Step 2: Configure Java}

{pstd}
After installing Java JDK, configure the Java home directory in Stata by running:
{p_end}

{phang2}{cmd:. java set home "path_to_java_home_dir"}{p_end}

{pstd}
Replace {it:path_to_java_home_dir} with the actual path to your Java JDK installation directory (e.g., {cmd:"C:\Program Files\Java\jdk-17"} on Windows or {cmd:"/usr/lib/jvm/java-17-openjdk-amd64"} on Linux).
{p_end}

{pstd}
You can verify the Java configuration by running:
{p_end}

{phang2}{cmd:. java query}{p_end}

{pstd}
You can restore the default JDK version by running:
{p_end}

{phang2}{cmd:. java set home default}{p_end}

{pstd}
More detailed instruction is available on {browse "https://github.com/kerrydu/readraster/blob/develop/javaenvconfig.md"}
{p_end}


{dlgtab:GeoTools Library Setup via JShell with Java source code}

{pstd}
The GeoTools library (Version 34.0) is required for GeoTIFF file operations including {cmd:gtiffdisp}, {cmd:gtiffread}, {cmd:gtiffwrite}, {cmd:gzonalstats}, and {cmd:crsconvert} commands.
{p_end}

{dlgtab:Automated Setup (Recommended)}

{pstd}
For simplified setup, use the dedicated initialization command:
{p_end}

{phang2}{cmd:. geotools_init, download plus(geotools)}{p_end}

{pstd}
Note: This process may take several minutes as Stata downloads files from the internet.
{p_end}

{dlgtab:Manual Setup (Faster Alternative)}

{pstd}
1. Manually download GeoTools 34.0 from {browse "https://master.dl.sourceforge.net/project/geotools/GeoTools%2034%20Releases/34.0/geotools-34.0-bin.zip"}
{p_end}

{pstd}
2. Unzip the downloaded file
{p_end}

{pstd}
3. Initialize the environment by running:
{p_end}

{phang2}{cmd:. geotools_init} {it:path_to_geotools-34.0/lib}{cmd:, plus(geotools)}{p_end}

{pstd}
Replace {it:path_to_geotools-34.0/lib} with the actual file path to your unzipped GeoTools 34.0 lib folder.
{p_end}

{dlgtab:NetCDF Library Setup via JShell with Java source code}

{pstd}
The NetCDF library (Version 5.9.1) is required for NetCDF file operations including {cmd:ncdisp} and {cmd:ncread} commands.
{p_end}

{pstd}
The NetCDF library can be downloaded from: {browse "https://downloads.unidata.ucar.edu/netcdf-java/5.9.1/netcdfAll-5.9.1.jar"}
{p_end}

{dlgtab:Automated Setup}

{pstd}
For simplified setup, use the dedicated initialization command:
{p_end}

{phang2}{cmd:. netcdf_init, download plus(netcdf)}{p_end}

{pstd}
Note: The configuration described above is only required the first time you use the package.
{p_end}

{marker examples}{...}
{title:Examples}


{dlgtab:update the package}

{phang2}{cmd:. readraster, update}{p_end}

{dlgtab:Basic GeoTIFF Operations}

{phang}
Display GeoTIFF metadata:
{p_end}
{phang2}{cmd:. gtiffdisp DMSP-like2020.tif}{p_end}

{phang}
Read entire GeoTIFF file:
{p_end}
{phang2}{cmd:. gtiffread DMSP-like2020.tif, clear}{p_end}

{phang}
Read subset of GeoTIFF:
{p_end}
{phang2}{cmd:. gtiffread DMSP-like2020.tif, origin(100 200) size(500 500) clear}{p_end}

{dlgtab:NetCDF Operations}

{phang}
Display NetCDF file structure:
{p_end}
{phang2}{cmd:. local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"}{p_end}
{phang2}{cmd:. ncdisp using `url'}{p_end}

{phang}
Read a the first day section:
{p_end}
{phang2}{cmd:. local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"}{p_end}
{phang2}{cmd:. ncread tas using `url', origin(1 1 1) size(1 -1 -1)}{p_end}

{dlgtab:Spatial Analysis}

{phang}
Calculate zonal statistics:
{p_end}
{phang2}{cmd:. zonalstats DMSP-like2020.tif, shpfile(hunan.shp) stats("sum avg") clear}{p_end}

{phang}
Convert the coordinate system of the hunan.shp to the coordinate system of the DMSP-like2020.tif:
{p_end}
{phang2}{cmd:. crsconvert _CX _CY, gen(alber) from(hunan.shp) to(DMSP-like2020.tif)}{p_end}

{phang}
Match geographic datasets:
{p_end}
{phang2}{cmd:. matchgeop ORIG_FID lat lon using light_china.dta, neighbors(n wsg84_y wsg84_x) within(80) gen(distance)}{p_end}


{title:Source Code and Documentation}

{pstd}
The complete source code, documentation, and examples are available on GitHub:
{p_end}
{phang2}{browse "https://github.com/kerrydu/readraster":https://github.com/kerrydu/readraster}{p_end}

{pstd}
For bug reports, feature requests, or contributions, please visit the GitHub repository.
{p_end}



{marker author}{...}
{title:Authors}

{pstd}Kerry Du{p_end}
{pstd}School of Management, Xiamen University, China{p_end}
{pstd}Email: kerrydu@xmu.edu.cn{p_end}

{pstd}Chunxia Chen{p_end}
{pstd}School of Management, Xiamen University, China{p_end}
{pstd}Email: 35720241151353@stu.xmu.edu.cn{p_end}

{pstd}Shuo Hu{p_end}
{pstd}School of Economics, Southwestern University of Finance and Economics, China{p_end}
{pstd}Email: advancehs@163.com{p_end}

{pstd}Yang Song{p_end}
{pstd}School of Economics, Hefei University of Technology, China{p_end}
{pstd}Email: ss0706082021@163.com{p_end}

{pstd}Ruipeng Tan{p_end}
{pstd}School of Economics, Hefei University of Technology, China{p_end}
{pstd}Email: tanruipeng@hfut.edu.cn{p_end}
