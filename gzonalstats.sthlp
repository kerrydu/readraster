{smcl}
{* *! version 2.0  08oct2025  (merged modes)}{...}
{vieweralsosee "[R] merge" "help merge"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] matchgeop" "help matchgeop"}{...}
{viewerjumpto "Syntax" "gzonalstats##syntax"}{...}
{viewerjumpto "Description" "gzonalstats##description"}{...}
{viewerjumpto "Raster mode options" "gzonalstats##rasteropts"}{...}
{viewerjumpto "Vector-to-raster mode options" "gzonalstats##vectoropts"}{...}
{viewerjumpto "Remarks" "gzonalstats##remarks"}{...}
{viewerjumpto "Examples" "gzonalstats##examples"}{...}
{viewerjumpto "Stored results" "gzonalstats##results"}{...}
{title:Title}

{phang}
{bf:gzonalstats} {hline 2} Zonal statistics command: (1) direct GeoTIFF raster mode and (2) in‑memory vector grid -> raster mode


{marker syntax}{...}
{title:Syntax}

{pstd}{ul:Two distinct syntaxes (choose one):}

{p 4 8 2}{bf:Raster mode (direct GeoTIFF)}{p_end}
{p 8 17 2}{cmd:gzonalstats} {it:rasterfilename} {cmd:using} {it:shapefile}{cmd:,} {opt stats(string)} [{opt band(#)} {opt clear}]{p_end}

{p 4 8 2}{bf:Vector-to-raster mode (former zonalstats_core)}{p_end}
{p 8 17 2}{cmd:gzonalstats} {cmd:using} {it:shapefile}{cmd:,} {opt xvar(varname)} {opt yvar(varname)} {opt valuevar(varname)} {opt frame(name)} {opt crs(string)} [{opt stats(string)} {opt nodata(#)}]{p_end}

{pstd}In raster mode a GeoTIFF file is read directly. In vector mode the data already in Stata (regular grid of x,y,value) is rasterized on‑the‑fly before computing zonal statistics.

{p 8 17 2}{cmd:shapefile} must include accompanying .shx .dbf (and ideally .prj) files.

{marker description}{...}
{title:Description}

{pstd}{cmd:gzonalstats} computes statistics of raster cell values aggregated over polygon zones defined in a shapefile. It now unifies two workflows:

{p 6 10 2}1. {bf:Raster mode}: read one band of a GeoTIFF on disk and summarize values inside each polygon.{p_end}
{p 6 10 2}2. {bf:Vector mode}: take a regular grid present as point observations (x,y,value) in memory, build a temporary raster, then summarize by polygon.{p_end}

{pstd}For both modes the command:
{p 8 12 2}• Reprojects the shapefile to match the raster / constructed raster CRS if needed{p_end}
{p 8 12 2}• Supports multiple statistics (count avg min max std sum){p_end}
{p 8 12 2}• Uses GeoTools Java libraries for spatial processing{p_end}

{pstd}Vector mode adds CRS specification ({cmd:crs()}) and optional storage of results to a new frame so your original data remain intact.

{title:Dependencies}
{pstd}All modes require GeoTools Java dependencies; see {help geotools_init}. 

{marker rasteropts}{...}
{title:Raster mode options}

{phang}{opt stats(string)} Statistics to compute; default {cmd:avg}. Any space‑separated subset of {cmd:count avg min max std sum}. Invalid names produce an error.
{phang}{opt band(#)} Band index (1-based) for multi-band GeoTIFF. Default 1; must be >=1.
{phang}{opt clear} Clear current data in memory before loading results (required if data present).

{marker vectoropts}{...}
{title:Vector-to-raster mode options}

{dlgtab:Required}
{phang}{opt xvar(varname)} Variable holding X (typically longitude / easting) coordinates of grid points.
{phang}{opt yvar(varname)} Variable holding Y (typically latitude / northing) coordinates.
{phang}{opt valuevar(varname)} Variable holding cell values to aggregate.
{phang}{opt frame(name)} Name of a new frame to store results (must not already exist). 
{phang}{opt crs(string)} Coordinate reference system for the in‑memory grid. Forms:
{p 12 16 2}• EPSG code: {cmd:crs(EPSG:4326)}{break}
{p 12 16 2}• Reference GeoTIFF: {cmd:crs("ref.tif", tif)}{break}
{p 12 16 2}• Reference shapefile: {cmd:crs("ref.shp", shp)}{break}
{p 12 16 2}• Reference NetCDF: {cmd:crs("ref.nc", nc)} (attempts CRS inference){p_end}

{dlgtab:Optional}
{phang}{opt stats(string)} Same list and default as raster mode.
{phang}{opt nodata(#)} Value used as no‑data placeholder when constructing raster (default -9999). Cells with this value excluded from statistics.

{marker remarks}{...}
{title:Remarks}

{pstd}{bf:Choosing a mode.} If you already have a GeoTIFF, use raster mode (faster, no rasterization). If data are point/grid observations in Stata, use vector mode. Results are equivalent provided the constructed grid matches the original raster's alignment and resolution.

{pstd}{bf:Grid assumptions (vector mode).} Points must form a regular grid. The command infers: resolution, width, height, extent. Duplicate (x,y) throw errors. Irregular spacing will yield incorrect rasterization.

{pstd}{bf:CRS handling.} Shapefile is reprojected to raster CRS (or specified CRS in vector mode). NetCDF CRS inference attempts EPSG code or WKT; falls back to WGS84 if unresolved.

{pstd}{bf:Performance tips.}
{p 8 12 2}• Limit requested statistics to those needed{p_end}
{p 8 12 2}• Use appropriate CRS in projected meters for large area analyses to avoid distortion-driven artifacts{p_end}
{p 8 12 2}• Pre-filter polygons to study region before running{p_end}
{p 8 12 2}• For very large rasters consider tiling externally; current command reads full needed extent{p_end}

{marker examples}{...}
{title:Examples}

{bf:Raster mode}
{phang}Nighttime lights statistics by city (sum + average):
{phang2}{cmd:. gzonalstats DMSP-like2020.tif using hunan.shp, stats("sum avg") clear}

{phang}Single statistic (mean) default:
{phang2}{cmd:. gzonalstats nl2022.tif using provinces.shp, clear}

{phang}Specify band 3 of a multi-band GeoTIFF:
{phang2}{cmd:. gzonalstats multiband.tif using zones.shp, band(3) stats("avg std") clear}

{bf:Vector-to-raster mode}
{phang}Basic usage with WGS84 coordinates:
{phang2}{cmd:. use temperature_grid, clear}
{phang2}{cmd:. gzonalstats using admin_boundaries.shp, xvar(lon) yvar(lat) valuevar(temp) frame(temp_zones) crs(EPSG:4326) stats("avg min max")}

{phang}Multiple stats and custom nodata value:
{phang2}{cmd:. use precipitation_data, clear}
{phang2}{cmd:. gzonalstats using watersheds.shp, xvar(x) yvar(y) valuevar(rain) frame(rain_stats) crs(EPSG:4326) stats("count avg sum min max std") nodata(-999)}

{phang}Using a reference GeoTIFF for CRS alignment:
{phang2}{cmd:. use nightlight_grid, clear}
{phang2}{cmd:. gzonalstats using cities.shp, xvar(lon) yvar(lat) valuevar(lum) frame(city_lights) crs("reference_raster.tif", tif) stats("avg sum")}

{phang}Using NetCDF file for CRS inference:
{phang2}{cmd:. use climate_grid, clear}
{phang2}{cmd:. gzonalstats using countries.shp, xvar(longitude) yvar(latitude) valuevar(temp) frame(country_climate) crs("climate.nc", nc) stats("avg min max std")}

{bf:Comparing modes}
{phang}If you have both point grid and corresponding GeoTIFF:
{phang2}{cmd:. gzonalstats grid.tif using regions.shp, stats("avg std") clear}
{phang2}{cmd:. use grid_points, clear}
{phang2}{cmd:. gzonalstats using regions.shp, xvar(x) yvar(y) valuevar(val) frame(vec_stats) crs(EPSG:3857) stats("avg std")}

{marker results}{...}
{title:Stored results}

{pstd}Output dataset (or results frame in vector mode) contains:
{synoptset 22 tabbed}{...}
{p2col 5 24 28 2: Variable}Description{p_end}
{synoptline}
{synopt:{it:zone_id_vars}}All non-geometry attributes from shapefile polygons{p_end}
{synopt:{cmd:count}}Pixel count in zone (if requested){p_end}
{synopt:{cmd:avg}}Mean cell value (if requested){p_end}
{synopt:{cmd:min}}Minimum cell value (if requested){p_end}
{synopt:{cmd:max}}Maximum cell value (if requested){p_end}
{synopt:{cmd:std}}Standard deviation (if requested){p_end}
{synopt:{cmd:sum}}Sum of cell values (if requested){p_end}
{synoptline}
{p2colreset}{...}

{pstd}Each observation = one polygon zone. Statistics only include non‑nodata pixels.

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
Online: {help geotools_init}, {help matchgeop}, {help gtiffdisp}, {help gtiffread}{p_end}

