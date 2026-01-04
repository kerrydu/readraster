*! version 3.0.1 2025-10-08
cap program drop zonalstats
program define zonalstats
version 17

cap findfile readraster-all-1.0.0-fat.jar
if !_rc {
    zonalstats_2 `0'
    exit
}

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


cap program drop zonalstats_2
program define zonalstats_2
version 17


syntax anything using/, [*]

removequotes, file(`anything')
local raster = r(file)

if strmatch(lower(`"`raster'"'), "*.tif") | strmatch(lower(`"`raster'"'), "*.tiff") {
    gzonalstats_core_2 `0'
}
else if strmatch(lower(`"`raster'"'), "*.nc"){
    nzonalstats_core_2 `0'
}
else{
    di as error `"`raster'"' " is not a supported raster file. Supported formats are GeoTIFF (*.tif, *.tiff) and NetCDF (*.nc)."
    exit 198
}


end

cap program drop gzonalstats_core_2
program define gzonalstats_core_2
version 17
syntax anything using/, [STATs(string) band(integer 1) clear crs(string)]

// Check if clear option is provided when data is in memory
if "`clear'"=="" {
    qui describe
    if r(N) > 0 | r(k) > 0 {
        di as error "Data already in memory, use the clear option to overwrite"
        exit 198
    }
}

if `band'<1{
    di as error "Band index must be >= 1"
    exit 198
}

local band = `band' - 1

// Default value for stats if not provided
if missing("`stats'") {
    local stats "avg"
}

//check stats in supported list
local stats_inlist  count  avg min max std sum

foreach stat of local stats {
    local unsupported: list stats - stats_inlist
    if "`unsupported'" != "" {
        di as error "Invalid stats parameter, must be a combination of count, avg, sum, min, max, and std"
        exit 198
    }
}

// Convert file paths to Unix-style paths
local shpfile `using'
local using `anything'

removequotes, file(`using')

local using = subinstr(`"`using'"',"\","/",.)
local shpfile = subinstr(`"`shpfile'"',"\","/",.)
// 判断路径是否为绝对路径
//if !strmatch("`using'", "*:\\*") & !strmatch("`using'", "/*") {
if !strpos("`using'", "/") {
    // 如果是相对路径，拼接当前工作目录
    local using = "`c(pwd)'/`using'"
}
removequotes, file(`shpfile')
local shpfile `r(file)'
// 判断路径是否为绝对路径
//if !strmatch("`shpfile'", "*:\\*") & !strmatch("`shpfile'", "/*") {
if !strpos("`shpfile'", "/") {
    // 如果是相对路径，拼接当前工作目录
    local shpfile = "`c(pwd)'/`shpfile'"
}

local using = subinstr(`"`using'"',"\","/",.)
local shpfile = subinstr(`"`shpfile'"',"\","/",.)

// Use the arguments passed to the program
local tifffile `"`using'"'

// Prepare CRS option
local usercrs "`crs'"

// Clear data in Stata directly if needed
if "`clear'" == "clear" {
    clear
}

java clear
// Call unified Java via javacall using the fat jar by filename (placed in working directory)
javacall org.readraster.ReadRasterAll method1, ///
    jars("readraster-all-1.0.0-fat.jar") ///
    args("zonalstatics" "`shpfile'" "`tifffile'" `band' "`stats'" "`usercrs'")

// Add variable labels in Stata code after Java execution
cap confirm var count
if !_rc {
    label var count "Number of pixels in zone"
}
cap confirm var avg
if !_rc {
    label var avg "Average pixel value in zone"
}
cap confirm var min
if !_rc {
    label var min "Minimum pixel value in zone"
}
cap confirm var max
if !_rc {
    label var max "Maximum pixel value in zone"
}
cap confirm var std
if !_rc {
    label var std "Standard deviation of pixel values in zone"
}
cap confirm var sum
if !_rc {
    label var sum "Sum of pixel values in zone"
}

end


cap program drop nzonalstats_core_2
program define nzonalstats_core_2
version 17
syntax anything using/, origin(numlist integer >0) size(numlist integer) [STATs(string) var(string) clear  crs(string)]

// Check if clear option is provided when data is in memory
if "`clear'"=="" {
    qui describe
    if r(N) > 0 | r(k) > 0 {
        di as error "Data already in memory, use the clear option to overwrite"
        exit 198
    }
}

// Default variable name if not provided
if missing("`var'") {
    di as error "Variable name must be specified with var() option"
    exit 198
}

// Default value for stats if not provided
if missing("`stats'") {
    local stats "avg"
}

//check stats in supported list
local stats_inlist  count  avg min max std sum

foreach stat of local stats {
    local unsupported: list stats - stats_inlist
    if "`unsupported'" != "" {
        di as error "Invalid stats parameter, must be a combination of count, avg, sum, min, max, and std"
        exit 198
    }
}

// Convert file paths to Unix-style paths
local shpfile `using'
local using `anything'

removequotes, file(`using')
local using = subinstr(`"`using'"',"\","/",.)
local shpfile = subinstr(`"`shpfile'"',"\","/",.)
// 判断路径是否为绝对路径
//if !regexm("`using'", "^(https?|ftp|s3|gs|/vsicurl/|/vsis3/|/vsigs/|/vsiaz/|/vsicurl_streaming/|/vsihttp/|/vsimem/|/vsizip/|/vsitar/|/vsicurl/).*") ///
//    & !strmatch("`using'", "*:\\*") & !strmatch("`using'", "/*") {
if !strpos("`using'","/") {
    local using = "`c(pwd)'/`using'"
}

removequotes, file(`shpfile')
local shpfile `r(file)'
// 判断路径是否为绝对路径
//if !strmatch("`shpfile'", "*:\\*") & !strmatch("`shpfile'", "/*") {
if !strpos("`shpfile'", "/") {
    // 如果是相对路径，拼接当前工作目录
    local shpfile = "`c(pwd)'/`shpfile'"
}

local using = subinstr(`"`using'"',"\","/",.)
local shpfile = subinstr(`"`shpfile'"',"\","/",.)

// Use the arguments passed to the program
local ncfile `"`using'"'

// Clear data in Stata directly if needed
if "`clear'" == "clear" {
    clear
}

// Parse origin and size
local origin0
if "`origin'"!="" {
    local no : word count `origin'
    forvalues i=1/`no' {
        local oi : word `i' of `origin'
        local origin0 `origin0' `=`oi'-1'
    }
}

if "`size'"=="" & "`origin'"!="" {
    local size
    local no : word count `origin'
    forvalues i=1/`no' {
        local size `size' -1
    }
}

// 检查 size 元素>1的个数不能大于2
if "`size'"!="" {
    local nsize : word count `size'
    local n_gt1 0
    forvalues i=1/`nsize' {
        local si : word `i' of `size'
        if `si'>1 {
            local n_gt1 = `n_gt1'+1
        }
    }
    if `n_gt1'>2 {
        di as error "Only 2D grids are supported: at most 2 dimensions with size>1."
        exit 198
    }
}

// Prepare CRS option
local usercrs "`crs'"

// Call unified Java via javacall using the fat jar by filename (placed in working directory)
java clear
if "`origin'"!="" {
    javacall org.readraster.ReadRasterAll method1, ///
        jars("readraster-all-1.0.0-fat.jar") ///
        args("nzonalstatics" "`shpfile'" "`ncfile'" "`var'" "`stats'" "`origin0'" "`size'" "`usercrs'")
} 
else {
    javacall org.readraster.ReadRasterAll method1, ///
        jars("readraster-all-1.0.0-fat.jar") ///
        args("nzonalstatics" "`shpfile'" "`ncfile'" "`var'" "`stats'" "" "" "`usercrs'")
}

// Add variable labels in Stata code after Java execution
cap confirm var count
if !_rc {
    label var count "Number of pixels in zone"
}
cap confirm var avg
if !_rc {
    label var avg "Average pixel value in zone"
}
cap confirm var min
if !_rc {
    label var min "Minimum pixel value in zone"
}
cap confirm var max
if !_rc {
    label var max "Maximum pixel value in zone"
}
cap confirm var std
if !_rc {
    label var std "Standard deviation of pixel values in zone"
}
cap confirm var sum
if !_rc {
    label var sum "Sum of pixel values in zone"
}

end
