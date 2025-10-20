*! version 2.0.1 2025-10-05
cap program drop gtiffread
program define gtiffread
version 17

checkdependencies
gtiffread_core `0'

end


program define checkdependencies
version 17 

local jars gt-main-34.0.jar 

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
        disp "see " `"{help geotools_init:help geotools_init}"' 
        exit 198
    }
    
	path_geotoolsjar
    local path `r(path)'

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
