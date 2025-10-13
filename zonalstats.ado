*! version 3.0.1 2025-10-08
cap program drop zonalstats
program define zonalstats
version 17

checkdependencies

syntax anything using/, [*]

removequotes, file(`anything')
local raster = r(file)

if strmatch(lower(`"`raster'"'), "*.tif") | strmatch(lower(`"`raster'"'), "*.tiff") {
    gzonalstats_core `0'
}
else if strmatch(lower(`"`raster'"'), "*.nc"){
    nzonalstats_core `0'
}
else{
    di as error `"`raster'"' " is not a supported raster file. Supported formats are GeoTIFF (*.tif, *.tiff) and NetCDF (*.nc)."
    exit 198
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

cap findfile netcdfAll-5.9.1.jar
if _rc {
    cap findfile path_ncreadjar.ado 
    if _rc {
        di as error "jar path NOT specified, use netcdf_init for setting up"
        disp "see " `"{view "netcdf_init.sthlp":help netcdf_init}"'
        exit
    }

    path_ncreadjar
    local path `r(path)'

    cap findfile netcdfAll-5.9.1.jar, path(`"`path'"')
    if _rc {
        di as error "Missing Java dependencies, netcdfAll-5.9.1.jar NOT found"
        di as error "make sure netcdfAll-5.9.1.jar exists in your specified directory"
        disp "see " `"{view "netcdf_init.sthlp":help netcdf_init}"' " for setting up"
        exit
    }
    qui adopath ++ `"`path'"'
}

end

cap program drop removequotes
program define removequotes,rclass
    version 16
    syntax, file(string) 
    return local file `file'
end
