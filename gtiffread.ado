*! version 2.0.1 2025-10-05
cap program drop gtiffread
program define gtiffread
version 17

cap findfile readraster-all-1.0.0-fat.jar
if !_rc {
    gtiffread_2 `0'
    exit
}

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


cap program drop gtiffread_2
program define gtiffread_2
version 17
syntax anything, [CRScode(string) band(real 1) origin(numlist min=2 max=2 integer >0) size(numlist min=2 max=2 integer)  clear]

// 参数处理逻辑
if "`clear'" != "clear" {
    qui describe
    if r(N) > 0 | r(k) > 0 {
        di as error "Data already in memory, use the clear option to overwrite"
        exit 198
    }
} 
else {
    clear
}

local using `anything'

removequotes, file(`using')
local using = usubinstr(`"`using'"',"\","/",.)
//if !strmatch("`using'", "*:/*") & !strmatch("`using'", "/*") {
if !strpos("`using'", "/")  {
    local using = "`c(pwd)'/`using'"
}
local using = usubinstr(`"`using'"',"\","/",.)

if "`crscode'" == "" {
    local crscode "None" // Default to "None" if not provided
}

//// 处理 crscode 参数
if strpos(lower("`crscode'"), ".tif") | strpos(lower("`crscode'"), ".shp") {
    removequotes, file(`crscode')
    local crscode `r(file)'
    local crscode = subinstr("`crscode'", "\", "/", .)
    //if !strmatch("`crscode'", "*:\\*") & !strmatch("`crscode'", "/*") {
    if !strpos("`crscode'", "/")  {
        local crscode = "`c(pwd)'/`crscode'"
    }
    local crscode = subinstr("`crscode'", "\", "/", .)
}



//初始化 Stata 数据结构
qui {
    gen double x = .
    gen double y = .
    gen double value = .
}

if "`origin'" == "" {
    local startRow 0
    local startCol 0
    local endRow -1
    local endCol -1
} 
else {
    local startRow: word 1 of `origin'
    local startCol: word 2 of `origin'
    local startCol = `startCol' - 1
    local startRow = `startRow' - 1

    if "`size'" == "" {
        local endRow -1
        local endCol -1
    } 
    else {
        local endRow: word 1 of `size'
        local endCol: word 2 of `size'
        local endRow = `endRow' + `startRow' - 1
        local endCol = `endCol' + `startCol' - 1
    }
}

java clear
// Call unified Java via javacall using the fat jar by filename (placed in working directory)
javacall org.readraster.ReadRasterAll method1, ///
    jars("readraster-all-1.0.0-fat.jar") ///
    args("geotiffExport" "`using'" `band' "`crscode'" `startRow' `endRow' `startCol' `endCol')

// 添加标签和注释
label variable x "GeoTiff X Coordinate"
label variable y "GeoTiff Y Coordinate"
label variable value "Pixel Value (Band `band')"



end


cap program drop removequotes
program define removequotes,rclass
    version 16
    syntax, file(string) 
    return local file `file'
end
