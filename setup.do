
************Set up for Readraster************
display "******Download Java dependency for readraster*******"
display "******The dowloading may take dozen mininutes*******"

cap findfile geotools_init.ado
if _rc {
	display "make sure the current directory is the one containing geotools_init.ado"
	exit
}

cap findfile NetCDFUtils-complete.jar
if _rc {
	cap net install netcdfutil.pkg, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/main/)
}

geotools_init, plus(geotools)

display "******Java dependency has been set up*******"
display "********Now you can use readraster**********"

************Set up for Readraster************
