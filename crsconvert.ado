
cap program drop crsconvert
program define crsconvert
version 18

checkdependencies
crsconvert_core `0'

end

program define checkdependencies

version 18 

cap findfile gt-main-32.0.jar
if _rc==0 cap findfile gt-referencing-32.0.jar
if _rc==0 cap findfile gt-epsg-hsql-32.0.jar
if _rc==0 cap findfile gt-epsg-extension-32.0.jar

if _rc{
    cap findfile path_geotoolsjar.ado 
    if _rc {
        di as error "jar path NOT specified, help geotools_init for setting up"
        exit
        
    }

    path_geotoolsjar
    local path `r(path)'
	local jars gt-main-32.0.jar gt-referencing-32.0.jar  gt-epsg-hsql-32.0.jar gt-epsg-extension-32.0.jar

	foreach jar in `jars' {
	
	    cap findfile `jar', path(`"`path'"')
	    if _rc {
        di as error "`jar' NOT found"
        di as error "use geotools_init for re-initializing Java environment"
        di as error "make sure `jar' exists in your specified directory"
        exit
      }
	
	}
	

    qui adopath ++ `"`path'"'

}

end

