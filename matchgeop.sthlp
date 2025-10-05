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
Match datasets using nearest neighbors within 10 km:

{p 12 16 2}
{cmd:. ncread tas using "hunan.nc", clear}{break}

{p 12 16 2}
{cmd:. gen n=_n}{break}

{p 12 16 2}
{cmd:. save "hunan_grid.dta", replace}{break}

{p 12 16 2}
{cmd:. use "hunan_city.dta", clear}{break}

{p 12 16 2}
{cmd:. matchgeop ORIG_FID lat lon using hunan_grid.dta, neighbors(n lat lon) within(10) gen(distance)}{break}

{phang}
Match datasets using 5 nearest neighbors within 5 miles:

{p 12 16 2}
{cmd:. ncread tas using "hunan.nc", clear}{break}

{p 12 16 2}
{cmd:. gen n=_n}{break}

{p 12 16 2}
{cmd:. save "hunan_grid.dta", replace}{break}

{p 12 16 2}
{cmd:. use "hunan_city.dta", clear}{break}

{p 12 16 2}
{cmd:. matchgeop ORIG_FID lat lon using hunan_grid.dta, neighbors(n lat lon) within(5) mile nearcount(5) gen(distance) bearing(angle)}{break}

{phang}
Process the dataset in 5 parts:

{p 12 16 2}
{cmd:. ncread tas using "hunan.nc", clear}{break}

{p 12 16 2}
{cmd:. gen n=_n}{break}

{p 12 16 2}
{cmd:. save "hunan_grid.dta", replace}{break}

{p 12 16 2}
{cmd:. use "hunan_city.dta", clear}{break}

{p 12 16 2}
{cmd:. matchgeop ORIG_FID lat lon using hunan_grid.dta, neighbors(n lat lon) within(10) gen(distance) nsplit(5)}{break}

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

