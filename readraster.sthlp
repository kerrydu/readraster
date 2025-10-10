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

{phang2}{cmd:. net install readraster, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/main/)}{p_end}


{phang}
Downloading demo code and data from Github:
{p_end}

{phang2}{cmd:. net get readraster, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/main/)}{p_end}



{marker commands}{...}
{title:Available Commands}

{pstd}
The {cmd:readraster} package includes the following commands organized by functionality:

{dlgtab:GeoTIFF Operations}

{phang2}
{help gtiffread:gtiffread} - Read pixel values and coordinates from GeoTIFF files

{phang2}
{help gtiffdisp:gtiffdisp} - Display metadata information from GeoTIFF files

{phang2}
{help gtiffwrite:gtiffwrite} - Write Stata grid data to GeoTIFF raster file

{dlgtab:NetCDF Operations}

{phang2}
{help ncread:ncread} - Read variables from NetCDF files with support for multi-dimensional data

{phang2}
{help ncdisp:ncdisp} - Display structure and metadata of NetCDF files

{dlgtab:Spatial Analysis}

{phang2}
{help gzonalstats:gzonalstats} - Calculate zonal statistics from raster data in Geotiff file for areas of interest

{phang2}
{help zonalstats:gzonalstats} - Calculate zonal statistics from raster data in Stata for areas of interest


{phang2}
{help matchgeop:matchgeop} - Match datasets based on geographic proximity and location

{phang2}
{help crsconvert:crsconvert} - Convert coordinates between different coordinate reference systems

{dlgtab:Setup Commands}

{phang2}
{help geotools_init:geotools_init} - Configurate GeoTools Java library for GeoTIFF operations

{phang2}
{help netcdf_init:netcdf_init} - Configurate NetCDF Java library for GeoTIFF operations

{marker setup}{...}
{title:Setup Java dependencies}

{dlgtab:Java JDK Configuration}

{pstd}
{browse "Java JDK configuration requirements:"}
{p_end}

{phang2}• {bf:Stata 17}: Requires manual Java JDK 17+ installation and configuration{p_end}
{phang2}• {bf:Stata 18+}: Uses built-in Java runtime (no additional configuration needed){p_end}

{dlgtab:For Stata 17 Users: Configure Java JDK 17+}

{pstd}
If you are using Stata 17, you need to download and install Java JDK 17 or later, then configure it in Stata.
{p_end}

{dlgtab:Step 1: Download and Install Java JDK 17+}

{pstd}
Download and install Java JDK 17 or later from the official Oracle website or OpenJDK distributions:
{p_end}

{phang2}• Oracle JDK: {browse "https://www.oracle.com/java/technologies/downloads/"}{p_end}
{phang2}• OpenJDK: {browse "https://openjdk.org/"}{p_end}

{dlgtab:Step 2: Configure Java in Stata 17}

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

{dlgtab:For Stata 18+ Users}

{pstd}
Stata 18 and later versions include a compatible Java runtime environment. No additional Java JDK installation or configuration is required.
{p_end}

{dlgtab:GeoTools Library Setup}

{pstd}
Before using the commands {cmd:gtiffdisp}, {cmd:gtiffread}, {cmd:gtiffwrite}, {cmd:gzonalstats}, and {cmd:crsconvert}, you first need to download the GeoTools Version 32.0 Java library.
Once downloaded, place this library in Stata's adopath—or add the library's file path to Stata's adopath.
{p_end}

{pstd}
For a simplified setup, we provide a dedicated command: {cmd:geotools_init}.
To configure the environment automatically, simply run the following line in Stata:
{p_end}

{phang2}{cmd:. geotools_init, download plus(geotools)}{p_end}

{pstd}
Note that this process may take dozens of minutes—Stata’s speed for copying large files from the internet is relatively slow.
{p_end}

{pstd}
As a faster alternative, we recommend manually downloading the GeoTools library from {browse "https://master.dl.sourceforge.net/project/geotools/GeoTools%2032%20Releases/32.0/geotools-32.0-bin.zip"} and unzipping the downloaded file. After doing so, initialize the environment by running:
{p_end}

{phang2}{cmd:. geotools_init} {it:path_to_geotools-32.0/lib}{cmd:, plus(geotools)}{p_end}

{pstd}
Note that you should replace {it:path_to_geotools-32.0/lib} with the actual file path to your unzipped GeoTools 32.0 lib folder.
{p_end}

{pstd}
Before using the commands {cmd:ncdisp} and {cmd:ncread}, you first need to download the NetCDF Version 5.9.1 Java library.
{p_end}

{pstd}
For a simplified setup, we provide a dedicated command: {cmd:netcdf_init}.
To configure the environment automatically, simply run the following line in Stata:
{p_end}

{phang2}{cmd:. netcdf_init, download plus(netcdf)}{p_end}

{pstd}
* The configuration described above is only required the first time you use the package.
{p_end}

{marker examples}{...}
{title:Examples}

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

{phang}
Write grid data to GeoTIFF:
{p_end}
{phang2}{cmd:. gtiffwrite output.tif, xvar(lon) yvar(lat) valuevar(temp) crs(EPSG:4326)}{p_end}

{dlgtab:NetCDF Operations}

{phang}
Display NetCDF file structure:
{p_end}
{phang2}{cmd:. ncdisp using "climate_data.nc"}{p_end}

{phang}
Read specific variable:
{p_end}
{phang2}{cmd:. ncread temperature using "climate_data.nc", clear}{p_end}

{dlgtab:Spatial Analysis}

{phang}
Calculate zonal statistics:
{p_end}
{phang2}{cmd:. gzonalstats DMSP-like2020.tif, shpfile(admin_boundaries.shp) stats("sum avg") clear}{p_end}

{phang}
Match geographic datasets:
{p_end}
{phang2}{cmd:. matchgeop city_id lat lon using grid_data.dta, neighbors(grid_id lat lon) within(10) gen(distance)}{p_end}


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


