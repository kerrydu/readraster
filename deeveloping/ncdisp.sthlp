{smcl}
{*}
{hline}
{title:Title}

{phang}
{bf:ncdisp} {hline 2} Display the structure of a NetCDF file and retrieve information about a specific variable

{hline}

{title:Syntax}
To view metadata for an entire NetCDF file:
{phang}
{cmd:ncdisp} {cmd:using} {it:file(string)}

To view metadata for a specific variable in a NetCDF file:
{phang}
{cmd:ncdisp} {it:varname} {cmd:using} {it:file(string)}

{title:Description}

{pstd}
{cmd:ncdisp} is used to display the information about 
a specific variable in a nc file. It reads the file path provided as an argument.

{marker dependencies}{...}
{title:Dependencies}

{pstd}
The {cmd:ncdisp} command requires the netcdfAll-5.9.1.jar. Use {cmd:netcdf_init} for setting up.

{title:Options}

{phang}
{opt varname} specifies any valid Stata expression.

{phang}
{opt file} specifies the path to the NetCDF file.

{title:Stored results}

{phang}
ncdisp stores the following in r():

{phang}
local

{phang}
{opt r(varname)} returns the name of the variable.

{phang}
{opt r(dimensions)} returns the dimensions of the variable.

{phang}
{opt r(coordinates)} returns the coordinate axes of the variable.

{phang}
{opt r(datatype)} returns the data type of the variable.

{marker examples}{...}
{title:Examples}

{pstd}Display the meta information of the entrie NetCDF file:{p_end}
{phang2}{cmd:. local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"}{p_end}
{phang2}{cmd:. ncdisp using `url'}{p_end}

{pstd}Display the meta information of the variable:{p_end}
{phang2}{cmd:. local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"}{p_end}
{phang2}{cmd:. ncdisp tas using `url'}{p_end}

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


{title:Also see}

{psee}
Online: {help netcdf_init} {help ncread}
{p_end}
