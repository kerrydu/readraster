{smcl}
{* 14July2016}{...}
{hline}
help for {hi:netcdf_init}
{hline}

{title:Initializes the environment for ncread/ncdisp}

{cmd:netcdf_init } initializes the environment for reading NetCDF files using the netcdfAll-5.9.1.java library. 
{marker syntax}{...}
{title:Syntax}

{p 4 10 2}
{cmd:netcdf_init }[{it:pathofjar}] 
[,{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}

{synopt :{opt download}}specify downloading netcdfALL-5.9.1.jar{p_end}
{synopt :{opt dir(string)}}specify the target directory for downloading netcdfALL-5.9.1.jar{p_end}
{synopt :{opt plus(string)}}copy netcdfALL-5.9.1.jar to the specified folder in sysdir_plus{p_end}

{synoptline}
 

{marker examples}{...}
{title:Examples}

{phang}
1. Manually downloading netcdfALL-5.9.1.jar and add the current directory into Stata adopath:

{p 12 16 2}
{cmd:.copy https://downloads.unidata.ucar.edu/netcdf-java/5.9.1/netcdfAll-5.9.1.jar .}{break}

{p 12 16 2}
{cmd:.netcdf_init}{break}

{phang}
2. Manually downloading netcdfALL-5.9.1.jar into D:/jars and add D:/jars into Stata adopath:

{p 12 16 2}
{cmd:.mkdir D:/jars}{break}

{p 12 16 2}
{cmd:.copy https://downloads.unidata.ucar.edu/netcdf-java/5.9.1/netcdfAll-5.9.1.jar D:/jars/netcdfAll-5.9.1.jar}{break}

{p 12 16 2}
{cmd:.netcdf_init D:/jars}{break}

{phang}
3. Automatically downloading netcdfALL-5.9.1.jar into sysdir_plus/jar:

{p 12 16 2}
{cmd:.netcdf_init, download plus(jar)}{break}


{hline}


{title:Authors}
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
{p 7 14 2}Help:  {help ncread}, {helpb ncdisp} (if installed){p_end}
