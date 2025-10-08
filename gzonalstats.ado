*! version 2.0.1 2025-10-05
cap program drop gzonalstats
program define gzonalstats
version 17

checkdependencies

syntax [anything] using/, [*]

if "`anything'" != "" {
    gzonalstats_core `0'
}
else{
    zonalstats_core `0'
}



end



program define checkdependencies

version 17 

// List of all required JARs, including core GeoTools libraries and external dependencies
local jars gt-main-32.0.jar gt-referencing-32.0.jar gt-epsg-hsql-32.0.jar gt-process-raster-32.0.jar
local jars `jars' gt-epsg-extension-32.0.jar gt-geotiff-32.0.jar gt-coverage-32.0.jar
local jars `jars' gt-shapefile-32.0.jar gt-api-32.0.jar gt-metadata-32.0.jar
local jars `jars' json-simple-1.1.1.jar commons-lang3-3.15.0.jar commons-io-2.16.1.jar jts-core-1.20.0.jar

local rc 0
foreach jar in `jars'{
    cap findfile `jar'
    if _rc {
        local rc = 1
    }
}

if `rc'{
    capture which path_geotoolsjar
    if _rc {
        di as error "Missing Java dependencies"
        disp "see " `"{view "geotools_init.sthlp":help geotools_init}"' 
        exit 198
    }

    path_geotoolsjar
    local path `r(path)'

    foreach jar in `jars' {
    
	    cap findfile `jar', path(`"`path'"')
	    if _rc {
        di as error "Missing Java dependencies, `jar' NOT found"
        di as error "make sure `jar' exists in your specified directory"
		disp "see " `"{view "geotools_init.sthlp":help geotools_init}"' " for setting up"
        exit
      }
    
    }
    
    qui adopath ++ `"`path'"'
}

end

