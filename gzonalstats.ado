
cap program drop gzonalstats
program define gzonalstats
version 18.0

checkdependencies
gzonalstats_core `0'

end



program define checkdependencies

version 18 

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

    path_geotoolsjar
    local path `r(path)'

    foreach jar in `jars' {
    
        cap findfile `jar', path(`"`path'"')
        if _rc {
        di as error "`jar' NOT found"
        di as error "use geotools_init for re-initializing Java environment,help geotools_init"
        di as error "make sure `jar' exists in your specified directory"
        exit
      }
    
    }
    
    qui adopath ++ `"`path'"'
}

end

