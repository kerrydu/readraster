*! version 2.0.1 2025-10-05
cap program drop crsconvert
program define crsconvert
version 17

// Check for readraster-all-1.0.0-fat.jar and call crsconvert_2 if found
cap findfile readraster-all-1.0.0-fat.jar
if !_rc {
    crsconvert_2 `0'
    exit
}

checkdependencies
crsconvert_core `0'

end

program define checkdependencies

version 17

cap findfile gt-main-34.0.jar

if _rc{
    cap findfile path_geotoolsjar.ado 
    if _rc {
        di as error "Missing Java dependencies"
        disp "see " `"{help geotools_init:help geotools_init}"'  
        exit
        
    }

    path_geotoolsjar
    local path `r(path)'
	//local jars gt-main-32.0.jar gt-referencing-32.0.jar  gt-epsg-hsql-32.0.jar gt-epsg-extension-32.0.jar
    local jars gt-main-34.0.jar 
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

cap program drop crsconvert_2
program define crsconvert_2
version 17


syntax varlist(min=2 max=2 numeric), gen(string) from(string) to(string)

local x: word 1 of `varlist'
local y: word 2 of `varlist'

confirm new var `gen'`x'
confirm new var `gen'`y'

qui gen double `gen'`x' = .
qui gen double `gen'`y' = .

// 处理 from 和 to 参数的路径
local from `from'
local to `to'

if strpos(lower("`from'"), ".tif") | strpos(lower("`from'"), ".tiff") | strpos(lower("`from'"), ".shp") | strpos(lower("`from'"), ".nc") {
    removequotes, file(`from')
    local from `r(file)'
    local from = subinstr("`from'", "\", "/", .)
     // 只对相对路径拼接 c(pwd)
     //if !regexm("`from'", "^[A-Za-z]:/") & !strmatch("`from'", "/*") {
     if !strpos("`from'", "/") {
        local from = "`c(pwd)'/`from'"
    }
    local from = subinstr("`from'", "\", "/", .)
}

// 检查 to 是否是文件路径
if strpos(lower("`to'"), ".tif") | strpos(lower("`to'"), ".tiff") | strpos(lower("`to'"), ".shp") | strpos(lower("`to'"), ".nc") {
    removequotes, file(`to')
    local to `r(file)'
    local to = subinstr("`to'", "\", "/", .)
     //if !regexm("`to'", "^[A-Za-z]:/") & !strmatch("`to'", "/*") {
	if !strpos("`to'", "/") {
        local to = "`c(pwd)'/`to'"
    }
    local to = subinstr("`to'", "\", "/", .)
}

// 调用统一 Java 类 via javacall
java clear
javacall org.readraster.ReadRasterAll method1, ///
    jars("readraster-all-1.0.0-fat.jar") ///
    args("crsconvert" "`x'" "`y'" "`gen'`x'" "`gen'`y'" "`from'" "`to'")

end

cap program drop removequotes
program define removequotes,rclass
    version 16
    syntax, file(string) 
    return local file `file'
end

