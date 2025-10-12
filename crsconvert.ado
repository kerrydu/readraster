*! version 2.0.1 2025-10-05
cap program drop crsconvert
program define crsconvert
version 17

checkdependencies
crsconvert_core `0'

end

program define checkdependencies

version 17

cap findfile gt-main-32.0.jar
if _rc==0 cap findfile gt-referencing-32.0.jar
if _rc==0 cap findfile gt-epsg-hsql-32.0.jar
if _rc==0 cap findfile gt-epsg-extension-32.0.jar

if _rc{
    cap findfile path_geotoolsjar.ado 
    if _rc {
        di as error "Missing Java dependencies"
        disp "see " `"{help geotools_init:help geotools_init}"'  
        exit
        
    }

    path_geotoolsjar
    local path `r(path)'
	local jars gt-main-32.0.jar gt-referencing-32.0.jar  gt-epsg-hsql-32.0.jar gt-epsg-extension-32.0.jar

	foreach jar in `jars' {
	
	    cap findfile `jar', path(`"`path'"')
	    if _rc {
        di as error "Missing Java dependencies, `jar' NOT found"
        di as error "make sure `jar' exists in your specified directory"
		disp "see " `"{help geotools_init:help geotools_init}"' " for setting up"
        exit
      }
	
	}
	

    qui adopath ++ `"`path'"'

}

end

