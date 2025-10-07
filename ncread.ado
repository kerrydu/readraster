*! version 2.0.1 2025-10-05
cap program drop ncread 
program define ncread 
version 18

syntax [anything] using/,  [Size(numlist integer) Origin(numlist integer >0) CLEAR CSV(string) display]


    cap findfile NetCDFUtils-complete.jar
    if _rc {
        display as "installing the jar file, please wait..."
         cap net install netcdfutil.pkg, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/main/)
         if _rc {
            cap cnssc install netcdfutil.pkg
         }
         sleep 1000

    }
    cap findfile NetCDFUtils-complete.jar
    if _rc {
        di as error "downloading NetCDFUtils-complete.jar failed"
        di `"please go to {browse "https://github.com/kerrydu/readraster": Github/kerrydu/readraster} to download it and put it in your adopath"'
        exit
    }
    local jarfiles `r(filename)'

removequotes,file(`"`using'"')
local file `r(file)'
local file = subinstr(`"`file'"',"\","/",.)
mata: st_numscalar("r(isurl)",pathisurl(`"`file'"'))
local isurl = r(isurl)
if `isurl'==0 & fileexists(`"`using'"')==0{
    di as error `"`using' NOT exists"'
    exit 198
}

// check if the file is a nc file
local ext = substr(`"`using'"',length("`file'")-2,.)
if "`ext'" != ".nc" {
    di as error "Not a nc file"
    exit 198
}

if `"`anything'"'==""{
    ncinfo `"`file'"'
    exit
}
if "`display'"!=""{
    ncdisp `0'
}

if "`csv'"!=""{
    ncreadtocsv `0'
    exit
}


if "`clear'"=="" & `"`csv'"'==""{
    qui describe
    if r(N) != 0 | r(k) != 0 {
        di as error "Current dataset is NOT empty, using clear option"
        exit 198
    }
}
`clear'

if `"`origin'"'!=""{
    ncreadbysec `0'
    exit
}

removequotes,file(`anything')
local varname `r(file)'
confirm new var `varname'

// 使用javacall调用NetCDFUtils
javacall NetCDFUtils readToStataEntry, jars(NetCDFUtils-complete.jar) args("`file'" "`varname'")

if `=_N'>0 {
    disp "Sucessfully import `=_N' Obs into Stata."
}

end

/////////////////////////////////////////////
cap program drop removequotes
program define removequotes,rclass
version 16
syntax, file(string) 
return local file `file'
end

/////////////////////////////////////////////////
cap program drop ncinfo
program define ncinfo
    version 18
    syntax anything,[display]

    cap findfile NetCDFUtils-complete.jar, path(`"`path'"')
    if _rc {
        di as error "NetCDFUtils-complete.jar NOT found"
        di as error "make sure NetCDFUtils-complete.jar exists in your adopath"
        exit
    }

    removequotes,file(`"`anything'"')
    local file `r(file)'
    local file = subinstr(`"`file'"',"\","/",.)
    
    // 使用javacall调用新的JAR文件
    javacall NetCDFUtils printNetCDFStructureEntry, jars(NetCDFUtils-complete.jar) args("`file'")

end

program define ncreadbysec 
version 18
syntax anything using/,  [Size(numlist integer) clear ] Origin(numlist integer >0)

removequotes,file(`anything')
local varname `r(file)'
confirm new var `varname'
removequotes,file(`"`using'"')
local file `r(file)'
local file = subinstr(`"`file'"',"\","/",.)
di _n 

local no: word count `origin'

forv i=1/`no'{
    local oi: word `i' of `origin'
    local origin0 `origin0' `=`oi'-1'
}

if "`size'"==""{
    forv j=1/`no'{
        local size `size' -1
    }
}

local nc: word count `size'
if `nc' != `no' {
    di as error "The number of origin and size should be the same."
    exit
}

////////////import java////////////
// 使用javacall调用NetCDFUtils
javacall NetCDFUtils readToStataBySectionEntry, jars(NetCDFUtils-complete.jar) args("`file'" "`varname'" "`origin0'" "`size'")

local dimensions `dimensions'
local coordAxes `coordAxes'

// The Java code will have already performed the dimension validation
// We can still access the dimension information through the macros set by Java

if `=_N'>0 {
    disp "Sucessfully import `=_N' Obs into Stata."
}

 end


///////////////////////////////////////////
program define ncreadtocsv
version 18
syntax anything using/,  csv(string) [Size(numlist integer) Origin(numlist integer >0) clear ]
local varname `anything'
confirm name `varname'
parsecsvopt `csv'
local  csvfile `r(file)'

if `"`origin'"'!=""{
    ncreadtocsvbysec `anything' using `using', csv(`csvfile') size(`size') origin(`origin')
    exit
}

removequotes,file(`"`using'"')
local ncfile `r(file)'



local no: word count `origin'
if "`size'"==""{
    forv j=1/`no'{
        local size `size' -1
    }
}

local nc: word count `size'
if `nc' != `no' {
    di as error "The number of origin and size should be the same."
    exit
}
local ncfile = usubinstr(`"`ncfile'"',"\","/",.)
local csvfile = usubinstr(`"`csvfile'"',"\","/",.)
cap qui findfile NCtoCSV.java
di 
//////////javacall//////////////////////
javacall NetCDFUtils exportToCSVEntry, jar(`NetCDFUtils-complete.jar') args(`"`ncfile'"' `"`csvfile'"' `"`varname'"')


end


/////////////////////////////////////////

program define ncreadtocsvbysec
version 18
syntax anything using/,  csv(string) [Size(numlist integer) Origin(numlist integer >0)]

local varname `anything'
confirm name `varname'
local csvfile `csv'
removequotes,file(`using')
local ncfile `r(file)'

local ncfile = usubinstr(`"`ncfile'"',"\","/",.)
local csvfile = usubinstr(`"`csvfile'"',"\","/",.)

local no: word count `origin'
if "`size'"==""{
    forv j=1/`no'{
        local size `size' -1
    }
}

local nc: word count `size'
if `nc' != `no' {
    di as error "The number of origin and size should be the same."
    exit
}

// Convert Stata 1-based indices to Java 0-based indices
local origin0
forv i=1/`no'{
    local oi: word `i' of `origin'
    local origin0 `origin0' `=`oi'-1'
}

// No need for any other validation - Java will handle it all
di
javacall NetCDFUtils exportToCSVBySectionEntry, jar(`NetCDFUtils-complete.jar') args(`"`ncfile'"' `"`csvfile'"' `"`varname'"' `"`origin0'"' `"`size'"')

end


//////////////////////////////////////////

cap program drop parsecsvopt
program define parsecsvopt,rclass
syntax anything, [replace]

local file `anything'
local replace `replace'

removequotes,file(`"`file'"')
local file `r(file)'
local flag = fileexists(`"`file'"')


if "`replace'"=="" & `flag'{
    di as error "file exist, adding replace in csv() to overwrite it."
    exit 198
}

return local file `file'

end