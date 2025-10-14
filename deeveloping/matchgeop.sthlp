{smcl}
{* *! version 1.0  29jul2024}{...}
{vieweralsosee "[R] merge" "help merge"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] geonear" "help geonear"}{...}
{viewerjumpto "Syntax" "matchgeop##syntax"}{...}
{viewerjumpto "Description" "matchgeop##description"}{...}
{viewerjumpto "Options" "matchgeop##options"}{...}
{viewerjumpto "Examples" "matchgeop##examples"}{...}
{title:Title}

{phang}
{bf:matchgeop} {hline 2} Match datasets based on geographic location


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:matchgeop} {it:varlist} {cmd:using} {it:filename} {cmd:,} {opt n:eighbors(varlist)} [{it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opt n:eighbors(varlist)}}specify neighbor variables for matching{p_end}
{synopt:{opt uf:rame}}specify using data is a frame name{p_end}
{synopt:{opt w:ithin(#)}}specify range within which neighbors are considered{p_end}
{synopt:{opt user:ange(string)}}specify range variable for user-defined ranges{p_end}
{synopt:{opt mile}}measure distances in miles{p_end}
{synopt:{opt nearc:ount(#)}}specify number of nearest neighbors to consider{p_end}
{synopt:{opt g:en(newvar)}}specify name of new variable to store distance{p_end}
{synopt:{opt bear:ing(newvar)}}specify name of new variable to store bearing{p_end}
{synopt:{opt nsplit(#)}}specify number of splits for looping{p_end}
{synoptline}
{p2colreset}{...}
{p 4 6 2}
{it:varlist} must contain 3 variables in the order: id, latitude, and longitude.
{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:matchgeop} merges datasets based on a specified variable list and neighbors. It finds the nearest neighbors based on geographic location and generates a linked dataset.


{marker options}{...}
{title:Options}

{dlgtab:Main}

{phang}
{opt neighbors(varlist)} specifies the neighbor variables to consider for matching. Must contain 3 variables in the order: id, latitude, and longitude.

{phang}
{opt uframe} specifies the using data is in a frame. By default, the using data is Stata data format in the disk.

{phang}
{opt within(#)} specifies the range within which neighbors are considered.

{phang}
{opt userange(string)} specifies the range variable to use for user-defined ranges. For example, userange(keep if _n>10) will use the range if _n>10.

{phang}
{opt mile} specifies that distances should be measured in miles. Default is kilometers.

{phang}
{opt nearcount(#)} specifies the number of nearest neighbors to consider. Must be a positive number.

{phang}
{opt gen(newvar)} specifies the name of the new variable to store the distance.

{phang}
{opt bearing(newvar)} specifies the name of the new variable to store the bearing.

{phang}
{opt nsplit(#)} specifies the number of splits for looping. nsplit = 1 does one loop with all observations (requires large memory), nsplit = 2 does two loops with half of the observations, and so on.


{marker examples}{...}
{title:Examples}

{phang}
Match datasets using nearest neighbors within 80 km:

{p 12 16 2}
{cmd:. local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"}{break}


{p 12 16 2}
{cmd:. ncread lon using `url', clear }{break}

{p 12 16 2}
{cmd:. gen n=_n}{break}

{p 12 16 2}
{cmd:. qui sum n if lon>=108 & lon<=115}{break}

{p 12 16 2}
{cmd:. local lon_start = r(min)}{break}

{p 12 16 2}
{cmd:. local lon_count = r(N)}{break}

{p 12 16 2}
{cmd:. ncread lat using `url', clear }{break}

{p 12 16 2}
{cmd:. gen n=_n}{break}

{p 12 16 2}
{cmd:. qui sum n if lat>=24 & lat<=31}{break}

{p 12 16 2}
{cmd:. local lat_start = r(min)}{break}

{p 12 16 2}
{cmd:. local lat_count = r(N)}{break}

{p 12 16 2}
{cmd:. ncread tas using `url', clear origin(1 `lat_start' `lon_start') size(-1 `lat_count' `lon_count')}{break}

{p 12 16 2}
{cmd:. gen date = time - 3650.5  + date("2050-01-01", "YMD")}{break}

{p 12 16 2}
{cmd:. format date %td}{break}

{p 12 16 2}
{cmd:. rename lon ulon}{break}

{p 12 16 2}
{cmd:. rename lat ulat}{break}

{p 12 16 2}
{cmd:. gen n=_n }{break}

{p 12 16 2}
{cmd:. save "grid_all.dta", replace}{break}

{p 12 16 2}
{cmd:. use "hunan_city.dta", clear}{break}

{p 12 16 2}
{cmd:. matchgeop ORIG_FID lat lon using grid_all.dta, neighbors(n ulat ulon) within(80) gen(distance)}{break}

{p 12 16 2}
{cmd:. merge m:1 n using grid_all.dta, keep(3)}{break}

{hline}

{title:Author}

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
Online: {help gtiffread}, {help ncread}
{p_end}
