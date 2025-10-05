

cap program drop gtiffdisp
program define gtiffdisp,rclass
version 18.0

checkdependencies
gtiffdisp_core `0'



return scalar nband = bands
return scalar ncol = width
return scalar nrow = height
return scalar minX = minX
return scalar minY = minY
return scalar maxX = maxX
return scalar maxY = maxY
return scalar Xcellsize = xRes
return scalar Ycellsize = yRes

end


//////////////////////////

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
        di as error "use geotools_init for re-initializing Java environment,help geotools_init"
        di as error "make sure `jar' exists in your specified directory"
        exit
      }
	
	}
	

    qui adopath ++ `"`path'"'
}



end

////////////////////