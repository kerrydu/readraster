*! version 1.1, 2025-09-21
program define geotools_init
version 17.0

if `c(version)'<18{
	java query
	local jdk `r(version)'
	gettoken jv : jdk, p(.)
    if `jv'<17{
      di as error "Stata 17 requires manually installing JDK 17"
	  di "See " `"{help readraster:help readraster}"' " for configuring JDK 17 before using this command"
	  exit
    }

}

syntax [anything] , [download dir(string) plus(string)]

if "`download'"!=""{

	if `"`dir'"'!="" {
		mata: st_numscalar("r(exist)",direxists(`"`dir'"'))
		local exist = r(exist)
		if `exist'==0{
			di as error "dir {`dir'} NOT exist"
			exit 198
		}
	}
	if `"`dir'"'=="" local dir = c(pwd)
    local pwd `c(pwd)'
    qui cd "`dir'"
	di `"Downloading geotools-34.0-bin.zip into {browse "`dir'":`dir'}"'
    di `"Please wait for a while..."'
	copy https://master.dl.sourceforge.net/project/geotools/GeoTools%2034%20Releases/34.0/geotools-34.0-bin.zip geotools-34.0-bin.zip
    unzipfile geotools-34.0-bin.zip

	if `"`anything'"'!="" & "`plus'"==""{
        di as  `"Warning: {`anything'} is ignored as the jar file is downloaded to {`dir'}"'
	}
	if `"`anything'"'!="" & "`plus'"!=""{
        di as  "Warning: {`anything'} is ignored as the jar file is downloaded to {plus/`plus'}"
	}
	local anything `dir'/geotools-34.0/lib/
	qui cd "`pwd'"
}

if "`plus'"!=""{
    di "Copying geotools jars to {browse `c(sysdir_plus)'`plus'} ..."
	pjar2plus `anything', to(`plus') jar(gt-main-34.0.jar)
    wrtjarpath `c(sysdir_plus)'/`plus', jar(gt-main-34.0.jar) adoname(geotoolsjar)
}
else{
	wrtjarpath `anything', jar(gt-main-34.0.jar) adoname(geotoolsjar)
}

end

//////////////////////////////////////

cap program drop wrtjarpath
program define wrtjarpath
version 16.0
syntax [anything] ,[jar(string)] adoname(string)

// confirm name `adoname'

if `"`anything'"'==""{
	local anything `c(pwd)'
}
else{
	removequotes,file(`anything')
	local anything `r(file)'
	mata: st_numscalar("r(exist)",direxists(`"`anything'"'))
    local exist = r(exist)
	if `exist'==0{
		di as error "Path Setting Failed..."
		di as error "dir {`anything'} NOT exist"
		exit 198
	}
}

if `"`jar'"'!=""{
	local fileexist = fileexists(`"`anything'/`jar'"')
	if `fileexist'==0{
		di as error `"`jar' NOT found in {`anything'}"'
		di as error `"Make sure the specified directory contains all jar files in GeoTools/lib"'
		exit
	}
	
}


cap mkdir `"`c(sysdir_plus)'p"'
local filename =  c(sysdir_plus) + "p/path_`adoname'.ado"

local pdir = c(sysdir_plus) + "p"
mata: st_numscalar("r(exist)", direxists("`pdir'"))
if (r(exist)==0) {
    mkdir "`pdir'"
}
file open myfile using `"`filename'"', write text replace
file write myfile "cap program drop path_`adoname'" _n
file write myfile "program define path_`adoname', rclass" _n
file write myfile "version 16.0" _n
file write myfile `"return local path `anything'"' _n
file write myfile "end" _n
file close myfile
end


cap program drop removequotes
program define removequotes,rclass
version 16
syntax, file(string) 
return local file `file'
end




cap program drop pjar2plus
program define pjar2plus
version 16.0
syntax anything, [to(string) replace jar(string)]

removequotes, file(`anything')
local anything  `r(file)'
local anything = subinstr(`"`anything'"', "\", "/", .)


local fileexist = fileexists(`"`anything'/`jar'"')
if `fileexist'==0{
	di as error `"`jar' NOT found in {`anything'}"'
	di as error `"Make sure the specified directory contains all jar files in GeoTools/lib"'
	exit
}

local pluspath = c(sysdir_plus)
if `"`to'"' == "" {
    cap mkdir "`pluspath'jar"
    local to `"`pluspath'jar"'
}
else {
    confirm name `to'
    local to `"`pluspath'`to'"'  // 将用户提供的目录名拼接到plus路径后
    mata: st_numscalar("r(exist)", direxists(`"`to'"'))
    if r(exist) == 0 {
        mkdir `"`to'"'
    }
}

mata: st_numscalar("r(exist)", direxists(`"`anything'"'))
local direxist = r(exist)

local fileexist = fileexists(`"`anything'"')

if `direxist' == 0 & `fileexist' == 0 {
    di as err `"Directory or file {`anything'} not found"'
    exit 198
}

if `direxist' {
    local files : dir `"`anything'"' files "*.jar"
    foreach file in `files' {
		cap confirm file  `"`to'/`file'"'
        if _rc copy `"`anything'/`file'"' `"`to'/`file'"', `replace'
    }
}

if `fileexist' {
    local ext = substr(`"`anything'"', -4, .)
    if lower("`ext'") != ".jar" {
        di as err "Not a jar file"
        exit 198
    }
    mata: st_local("jarfile", pathbasename(`"`anything'"'))
    copy `"`anything'"' `"`to'/`jarfile'"', `replace'
}

end

