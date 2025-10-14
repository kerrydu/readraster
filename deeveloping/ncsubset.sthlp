{smcl}
{* *! version 1.0.0  2025-10-10}{...}
{vieweralsosee "ncread" "help ncread"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col :{bf:ncsubset} {hline 2}}Write a sliced subset of a NetCDF variable to a new NetCDF file{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 16 2}
{cmd:ncsubset} {it:varname} {cmd:using} {it:netcdf_file}{cmd:,}
{opt origin(numlist)} [{opt size(numlist)} {opt saving(path)} {opt replace} {opt clear}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt origin(numlist)}}1-based start indices along each variable dimension; required{p_end}
{synopt :{opt size(numlist)}}counts along each dimension; use -1 to read to end; default fills with -1 for all{p_end}
{synopt :{opt saving(path)}}output NetCDF file path; required{p_end}
{synopt :{opt replace}}overwrite existing output file{p_end}
{synopt :{opt clear}}clear data in memory before running{p_end}
{synoptline}

{title:Description}

{pstd}
{cmd:ncsubset} slices a variable from an input NetCDF file and writes it to a new NetCDF file. The output
contains the sliced main variable and only the coordinate axes that remain after slicing. If a non-spatial
axis (e.g., {it:time}, {it:level}) has {cmd:size==1}, that axis and its coordinate variable are dropped in the new file.
Spatial axes (lon/lat or x/y) are always retained.{p_end}

{title:Options}

{phang}{opt origin()} supplies 1-based starting indices for each dimension of the variable.

{phang}{opt size()} supplies counts per dimension. Use {cmd:-1} to extend to the end of that dimension. If omitted, all dimensions default to {cmd:-1}.{p_end}

{phang}{opt saving()} specifies the output NetCDF file. Use {opt replace} to overwrite if it exists.{p_end}

{title:Examples}

{pstd}Extract a single time slice and spatial window, writing a compact NetCDF (time axis dropped):{p_end}
{cmd:. ncsubset tas using climate.nc, origin(1 200 300) size(1 50 80) saving(tas_200_300.nc) replace clear}

{pstd}Keep multiple times; time axis retained:{p_end}
{cmd:. ncsubset tas using climate.nc, origin(1 200 300) size(30 50 80) saving(tas_month.nc) replace}

{title:Notes}

{pstd}Input {cmd:origin()} is 1-based (Stata style); internally it is converted to 0-based for Java. Dimension count in {cmd:origin()} and {cmd:size()} must match the variable rank.{p_end}
