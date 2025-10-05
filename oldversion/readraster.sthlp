{smcl}
{* *! version 1.0.0  03jun2025}{...}
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
{bf:Stata Version}: Stata 18 or later version is required
{p_end}


{marker commands}{...}
{title:Available Commands}

{pstd}
The {cmd:readraster} package includes the following commands organized by functionality:

{dlgtab:GeoTIFF Operations}

{phang2}
{help gtiffread:gtiffread} - Read pixel values and coordinates from GeoTIFF files

{phang2}
{help gtiffdisp:gtiffdisp} - Display metadata information from GeoTIFF files

{dlgtab:NetCDF Operations}

{phang2}
{help ncread:ncread} - Read variables from NetCDF files with support for multi-dimensional data

{phang2}
{help ncdisp:ncdisp} - Display structure and metadata of NetCDF files

{dlgtab:Spatial Analysis}

{phang2}
{help gzonalstats:gzonalstats} - Calculate zonal statistics from raster data using polygon zones

{phang2}
{help matchgeop:matchgeop} - Match datasets based on geographic proximity and location

{phang2}
{help crsconvert:crsconvert} - Convert coordinates between different coordinate reference systems

{dlgtab:Setup Commands}

{phang2}
{help geotools_init:geotools_init} - Initialize GeoTools Java library for GeoTIFF operations

{phang2}
{help netcdf_init:netcdf_init} - Initialize NetCDF Java library for NetCDF operations


{marker setup}{...}
{title:Setup Java dependencies}

{pstd}
Before using the package commands, you must initialize the required Java libraries:

{phang}
{bf:For GeoTIFF operations} (gtiffread, gtiffdisp, gzonalstats, crsconvert):
{p_end}
{phang2}{cmd:. geotools_init, download}{p_end}

{phang}
{bf:For NetCDF operations} (ncread, ncdisp):
{p_end}
{phang2}{cmd:. netcdf_init, download}{p_end}

{pstd}
These setup commands only need to be run once per Stata installation.


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


