*! version 2.0.1 2025-10-05
cap program drop gtiffdisp
program define gtiffdisp,rclass
version 17

cap findfile readraster-all-1.0.0-fat.jar
if !_rc {
    gtiffdisp_2 `0'
    exit
}

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


cap program drop gtiffdisp_2
program define gtiffdisp_2,rclass
version 17

syntax anything

local using `anything'

removequotes,file(`using')

local using = usubinstr(`"`using'"',"\","/",.)
// 判断路径是否为绝对路径
if !strmatch("`using'", "*:/*") & !strmatch("`using'", "/*") {
    // 如果是相对路径，拼接当前工作目录
    local using = "`c(pwd)'/`using'"
}
local using = usubinstr(`"`using'"',"\","/",.)

local rc = fileexists("`using'")
if `rc'==0{
	di as error `"`using' NOT found"'
	exit
}

// Use consolidated Java via javacall (ReadRasterAll.gtiffInfo)
// Per user request: only use fat jar, no path, and no existence checks.
// Ensure the fat jar file is placed in the current working directory or on Stata's search path.
local jar_fat readraster-all-1.0.0-fat.jar

// Clear previous Java classloader cache
cap noisily java clear

// Invoke
capture noisily javacall org.readraster.ReadRasterAll method1, jars("`jar_fat'") args("gtiffInfo" "`using'")


 /// Optionally return Stata scalars here if needed; Java already sets scalars via SFIToolkit.Scalar
   return scalar nband = bands
   return scalar ncol = width
   return scalar nrow = height
   return scalar minX = minX
   return scalar minY = minY
   return scalar Xcellsize = xRes
   return scalar Ycellsize = yRes 

end

cap program drop removequotes
program define removequotes,rclass
    version 16
    syntax, file(string) 
    return local file `file'
end

////////////////////
