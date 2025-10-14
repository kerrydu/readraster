{smcl}
{* *! version 1.0  07sep2024}{...}
{vieweralsosee "[D] import" "mansection D import"}{...}
{viewerjumpto "Syntax" "ncread##syntax"}{...}
{viewerjumpto "Description" "ncread##description"}{...}
{viewerjumpto "Options" "ncread##options"}{...}
{viewerjumpto "Examples" "ncread##examples"}{...}
{title:Title}

{phang}
{bf:ncread} {hline 2} Read data from NetCDF file

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:ncread} [{it:varname}] {cmd:using} {it:filename} [{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opt clear}} Clear the current dataset{p_end}
{synopt:{opt csv(path[,replace])}} Specify exporting data to a CSV{p_end}
{synopt:{opt origin(numlist)}} Specify the starting position for reading{p_end}
{synopt:{opt size(numlist)}} Specify the size of each dimension to read{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
The {cmd:ncread} command is used to read data for a specified variable from a NetCDF file into Stata. It can read the entire variable or a specified section of data. If varname is not specified, ncread displays the meta information of the NetCDF file.


{marker options}{...}
{title:Options}


{phang}
{opt clear} clear the current dataset for importing data. It is only activated without csv() option.

{phang}
{opt csv(pathtocsv[,replace])} export data to a CSV file. If replace is specified, the existing file will be overwritten. 

{phang}
{opt origin(numlist)} specifies the starting position for reading. Must be used together with the size option.

{phang}
{opt size(numlist)} specifies the size of each dimension to read. If not specified, the entire variable is read by default. If the element of numlist is -1, the entire dimension is read.

{marker examples}{...}
{title:Examples}

{pstd}Display the meta information of the NetCDF file:{p_end}
{phang2}{cmd:. local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"}{p_end}
{phang2}{cmd:. ncread using `url'}{p_end}

{pstd}Read the entire variable:{p_end}
{phang2}{cmd:. local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"}{p_end}
{phang2}{cmd:. ncread tas using `url'}{p_end}

{pstd}Read a specified section:{p_end}
{phang2}{cmd:. local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"}{p_end}
{phang2}{cmd:. ncread tas using `url', origin(1 1 1) size(10 20 30)}{p_end}

{pstd}Read a the first day section:{p_end}
{phang2}{cmd:. local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"}{p_end}
{phang2}{cmd:. ncread tas using `url', origin(1 1 1) size(1 -1 -1)}{p_end}

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
Online:  {manhelp import D:import}, {help netcdf_init}, {help ncdisp}
{p_end}
