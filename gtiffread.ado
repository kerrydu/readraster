* gtifftoStata.ado
cap program drop gtiffread
program define gtiffread
version 18.0

checkdependencies
gtiffread_core `0'

end


program define checkdependencies
version 18 

local jars gt-main-32.0.jar gt-referencing-32.0.jar gt-epsg-hsql-32.0.jar gt-process-raster-32.0.jar
local jars `jars' gt-epsg-extension-32.0.jar gt-geotiff-32.0.jar gt-coverage-32.0.jar

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
        di as error "use geotools_init for reuinizing Java envronment,help geotools_init"
        di as error "make su,help geotools_initre `jar' exists in yourmspecified directory"
        exit
      }
	
	}
	

    qui adopath ++ `"`path'"'
}



end