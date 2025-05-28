
cap program drop ncread 
program define ncread 
version 18
//stgeocominit
syntax [anything] using/,  [Size(numlist integer) Origin(numlist integer >0) CLEAR CSV(string) display]

// local pluspath = c(sysdir_plus)
// cap findfile netcdfAll-5.6.0.jar
// if _rc{
//     di as error "netcdfAll-5.6.0.jar not found"
//     di as error "Please download it from https://www.unidata.ucar.edu/software/netcdf"
//     di as error "and put it in `pluspath' via"
//     di as error "   pjar2plus yourpath/netcdfAll-5.6.0.jar, to(netcdf)"
//     exit 198
// }



cap findfile netcdfAll-5.6.0.jar

if _rc{
    cap findfile path_ncreadjar.ado 
    if _rc {
        di as error "jar path NOT specified, use ncread_init for setting up"
        exit
        
    }

    path_ncreadjar
    local path `r(path)'

    cap findfile netcdfAll-5.6.0.jar, path(`"`path'"')
    if _rc {
        di as error "netcdfAll-5.6.0.jar NOT found"
        di as error "use netcdf_init for re-initializing Java environment"
        di as error "make sure netcdfAll-5.6.0.jar exists in your specified directory"
        exit
    }

    qui adopath ++ `"`path'"'

}


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
    // removequotes,file(`using')
    // local file `r(file)'
    // local file = subinstr(`"`file'"',"\","/",.)
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
// removequotes,file(`using')
// local file `r(file)'
// local file = subinstr(`"`file'"',"\","/",.)
di _n 

qui findfile NCtoStata.java

//////////java//////////////////////
java clear
java: /cp "netcdfAll-5.6.0.jar"
java: /open "NCtoStata.java"
java: NCtoStata.main("`file'","`varname'")

/////////////////////////////////////
// if "`keepmissing'"==""{
//     qui sum `anything',meanonly
//     qui drop if `anything'> `=r(max)+1000'

// }

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


///////////////////////////////////////////
cap program drop ncreadbysec 
program define ncreadbysec 
version 18
syntax anything using/,  [Size(numlist integer) clear] Origin(numlist integer >0)

removequotes,file(`anything')
local varname `r(file)'
confirm new var `varname'
removequotes,file(`"`using'"')
local file `r(file)'
local file = subinstr(`"`file'"',"\","/",.)
di _n 

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

////////////import java////////////
java clear
java: /cp "netcdfAll-5.6.0.jar"
java: /open "NetCDFReader.java"
java: /open "NCtoStatabySection.java"

qui java: NetCDFReader.printVarStructure("`file'","`varname'")
local nd: word count `dimensions'
if `nc' != `nd' {
    di as error "The number of origin and count should be equal # of axises in nc file."
    exit
}

local size2 
forv i =1/`no'{
    local oi: word `i' of `origin'
    local di : word `i' of `dimensions'
    if  `di' < `oi' {
        di as error "The origin excesses the corresponding dimension lenth."
        exit
    }
    // java is zoro-based, so the origin should be minus 1
    local origin0 `origin0' `=`oi'-1'
    local ci: word `i' of `size'
    local endi = `oi' + `ci'-1
    if (`endi'> `di'){
        di as error "Requested section is out of range"
        di as error "(`origin') + (`size') - 1 > (`dimensions')" 
        exit
    }
    if (`ci'==-1) local size2 `size2' `=`di'-`oi'+1'
    else local size2 `size2' `ci'

}

 local size `size2'
 java: NCtoStatabySection.main("`file'","`varname'","`origin0'","`size'")


if `=_N'>0 {
    disp "Sucessfully import `=_N' Obs into Stata."
}

 end


cap program drop ncinfo
program define ncinfo
version 18
syntax anything,[display]
removequotes,file(`"`anything'"')
local file `r(file)'
local file = subinstr(`"`file'"',"\","/",.)
java clear
java: /cp "netcdfAll-5.6.0.jar"
java: /open "NetCDFReader.java"
java: NetCDFReader.printNetCDFStructure("`file'");

end

cap program drop ncreadtocsv
program define ncreadtocsv
syntax anything using/,  csv(string) [Size(numlist integer) Origin(numlist integer >0) clear]
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
//////////java//////////////////////
java clear
java: /cp "netcdfAll-5.6.0.jar"
java: /open "NCtoCSV.java"
java: NCtoCSV.main("`ncfile'","`csvfile'","`varname'")


end


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


cap program drop ncreadtocsvbysec
program define ncreadtocsvbysec
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


qui findfile NCtoCSVbySection.java



////////////import java////////////
java clear
java: /cp "netcdfAll-5.6.0.jar"
java: /open "NetCDFReader.java"
java: /open "NCtoCSVbySection.java"

qui java: NetCDFReader.printVarStructure("`ncfile'","`varname'")
local nd: word count `dimensions'
if `nc' != `nd' {
    di as error "The number of origin and count should be equal # of axises in nc file."
    exit
}

local size2 
forv i =1/`no'{
    local oi: word `i' of `origin'
    local di : word `i' of `dimensions'
    if  `di' < `oi' {
        di as error "The origin excesses the corresponding dimension lenth."
        exit
    }
    // java is zoro-based, so the origin should be minus 1
    local origin0 `origin0' `=`oi'-1'
    local ci: word `i' of `size'
    local endi = `oi' + `ci'-1
    if (`endi'> `di'){
        di as error "Requested section is out of range"
        di as error "(`origin') + (`size') - 1 > (`dimensions')" 
        exit
    }
    if (`ci'==-1) local size2 `size2' `=`di'-`oi'+1'
    else local size2 `size2' `ci'

}
 di
 local size `size2'
 java: NCtoCSVbySection.main("`ncfile'","`csvfile'","`varname'","`origin0'","`size'") //


end 
