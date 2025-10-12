*! version 3.0.1 2025-10-07
program define netcdf_init
version 16.0
syntax [anything] , [download dir(string) plus(string)]

if "`download'"!=""{

	if `"`dir'"'!="" {
		mata: st_numscalar("r(exist)",direxists(`"`dir'"'))
		local exist = r(exist)
		if `exist'==0{
			di as error "Path Setting Failed..."
			di as error "dir {`dir'} NOT exist"
			exit 198
		}
	}
	if `"`dir'"'=="" local dir = c(pwd)
	di `"Downloading netcdfAll-5.9.1.jar into {browse "`dir'":`dir'}..."'
	di  "Please wait..."
	copy https://downloads.unidata.ucar.edu/netcdf-java/5.9.1/netcdfAll-5.9.1.jar `"`dir'/netcdfAll-5.9.1.jar"'
	if `"`anything'"'!="" & "`plus'"==""{
        di as  `"Warning: {`anything'} is ignored as the jar file is downloaded to {`dir'}"'
	}
	
	if `"`anything'"'!="" & "`plus'"!=""{
        di as  "Warning: {`anything'} is ignored as the jar file is downloaded to {plus/`plus'}"
	}
	local anything `dir'
}

if "`plus'"!=""{
	di "Copying netcdfAll-5.9.1.jar to {browse `c(sysdir_plus)'/`plus'} ..."
	pjar2plus `anything'/netcdfAll-5.9.1.jar, to(`plus')
	wrtjarpath `c(sysdir_plus)'/`plus', jar(netcdfAll-5.9.1.jar) adoname(ncreadjar)
}
else{
	wrtjarpath `anything', jar(netcdfAll-5.9.1.jar) adoname(ncreadjar)
}

end


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
		di as error "Path Setting Failed..."
		di as error `"`jar' NOT found in {`anything'}"'
		exit
	}
	
}



local filename =  c(sysdir_plus) + "p/path_`adoname'.ado"
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


/*
pjar2plus - A Stata program to copy JAR files to a specified directory in Stata PLUS directory

Description:
    This program copies JAR files from a specified source directory or file to a target directory.
    If the source is a directory, all JAR files within it will be copied.
    If the source is a single JAR file, it will be copied to the target directory.
    The target directory can be specified or defaults to the Stata PLUS/jar directory.

Syntax:
    pjar2plus anything, [to(string) replace]

Options:
    anything    - The source directory or file path. Can be a directory containing JAR files or a single JAR file.
    to(string)  - The target directory where the JAR files will be copied. Defaults to the Stata PLUS/jar directory if not specified.
    replace     - Overwrite existing files in the target directory.

Details:
    - It then checks if the target directory exists and creates it if necessary.
    - If the source is a directory, it copies all JAR files from the directory to the target directory.
    - If the source is a single file, it checks if the file is a JAR file and then copies it to the target directory.
    - Appropriate error messages are displayed if the source directory or file is not found or if the file is not a JAR file.

Examples:
    . pjar2plus "E:/source_directory", to("target_directory")
    . pjar2plus "E:/source_directory", replace
    . pjar2plus "E:/source_directory"
    . pjar2plus "E:/source_directory/singlefile.jar", to("target_directory")

Author:
    Your Name
    Your Contact Information
*/


cap program drop pjar2plus
program define pjar2plus
version 16.0
syntax anything, [to(string) replace]

removequotes, file(`anything')
local anything  `r(file)'
local anything = subinstr(`"`anything'"', "\", "/", .)

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
        copy `"`anything'/`file'"' `"`to'/`file'"', `replace'
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

