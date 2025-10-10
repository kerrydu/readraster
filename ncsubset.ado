*! version 1.0.0 2025-10-10
cap program drop ncsubset
program define ncsubset
version 17

// Syntax: ncsubset var using ncfile, origin() size() saving() [replace]
syntax anything using/, Origin(numlist integer >0) [Size(numlist integer) SAVING(string) REPLACE CLEAR]

// normalize inputs
removequotes, file(`"`using''" )
local nc `r(file)'
local nc = subinstr(`"`nc'"',"\\","/",.)

removequotes, file(`anything')
local var `r(file)'
confirm name `var'

// check saving()
if missing(`"`saving''" ) {
    di as error "saving() is required to write the new NetCDF"
    exit 198
}
local out `"`saving''" 
local out = subinstr(`"`out'"',"\\","/",.)

// prevent overwrite unless replace
mata: st_numscalar("r(exists)", strofreal(fileexists(st_local("out"))))
if r(exists) & "`replace'"=="" {
    di as error "output file exists; add replace to overwrite"
    exit 602
}

// ensure dataset clear if requested
if "`clear'"=="" {
    qui describe
    if r(N) | r(k) {
        di as error "Data in memory; use clear to proceed or drop data"
        exit 198
    }
}
`clear'

// convert Stata 1-based origin to Java 0-based
local no : word count `origin'
local origin0
forvalues i=1/`no' {
    local oi : word `i' of `origin'
    local origin0 `origin0' `=`oi'-1'
}

// auto-fill size with -1
if "`size'"=="" {
    forvalues i=1/`no' {
        local size `size' -1
    }
}

// call Java
netcdfutils NetCDFUtils.subsetToFile("`nc'", "`out'", "`var'", "`origin0'", "`size'")

// message
di as text "Created subset: `out'"

end

// helper
cap program drop removequotes
program define removequotes, rclass
    version 16
    syntax, file(string)
    return local file `file'
end
