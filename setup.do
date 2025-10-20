
************Set up for Readraster************
display "******Download Java dependency for readraster*******"
display "******The dowloading may take dozen mininutes*******"

cap findfile geotools_init.ado
if _rc {
	display "make sure the current directory is the one containing geotools_init.ado"
	exit
}
cap findfile netcdfAll-5.9.1.jar,path(`"`c(pwd)'"')
if _rc==0 netcdf_init `c(pwd)', plus(netcdf)
else netcdf_init, download plus(netcdf)

cap findfile geotools-32.0-bin.zip, path(`"`c(pwd)'"')
if _rc==0{
     unzipfile geotools-32.0-bin.zip
     geotools_init `c(pwd)'geotools-32.0/lib, plus(geotools) 
}
else geotools_init, plus(geotools) download

display "******Java dependency has been set up*******"
display "********Now you can use readraster**********"

************Set up for Readraster************
