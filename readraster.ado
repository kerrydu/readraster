*! version 3.0.6, 2025-12-21
program define readraster

syntax, [update]
 
if "`update'" == "" {
	help readraster
    extractversion
    local localversion `r(localversion)'
    local gitversion   `r(gitversion)'

    if "`localversion'" != "`gitversion'" {
        gettoken loci localversion : localversion, p(".")
        gettoken giti gitversion : gitversion, p(".")
		while ("`loci'" !="" & "`giti'" !=""){
	        if "`loci'" !="" & "`giti'" !="" {
	            if "`loci'" < "`giti'" {
					di "run the following command to update the package"
	                di  "      readraster, update"
	            }
	         }
        gettoken loci localversion : localversion, p(".")
        gettoken giti gitversion : gitversion, p(".")		
	    }
	}
}
else {
	extractversion
    local localversion `r(localversion)'
    local gitversion   `r(gitversion)'

    if "`localversion'" == "`gitversion'" {
    	di "You have the latest version of readraster."
    }
    else {
        gettoken loci localversion : localversion, p(".")
        gettoken giti gitversion : gitversion, p(".")
		while ("`loci'" !="" & "`giti'" !=""){
	        if "`loci'" !="" & "`giti'" !="" {
	            if "`loci'" < "`giti'" {
	                di "updating readraster...."
	                net install readraster, from(https://raw.github.com/kerrydu/readraster/develop) replace force
	            }
	        }
        gettoken loci localversion : localversion, p(".")
        gettoken giti gitversion : gitversion, p(".")		
	  }
	    di
		di "The Java dependencies can be updated via:"
		di "          geotools_init, compiled"
	    di "          netcdf_init,   compiled"
    }
}

end

/////////////////////////////////////////////////////
program define extractversion,rclass
    version 16
	qui findfile readraster.ado 
    local fn `r(fn)'
    mata: filec = cat(`"`fn'"')
    mata: filec = filec[1,1]
    mata: st_local("filec", filec)
    local filec = substr("`filec'", strpos("`filec'", "version")+8,.)
    local localversion = substr("`filec'", 1,strpos("`filec'", ",")-1)
    di "The local version is `localversion'"

    mata: filec = cat(`"https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/develop/readraster.ado"')
    mata: filec = filec[1,1]
    mata: st_local("filec", filec)
    local filec = substr("`filec'", strpos("`filec'", "version")+8,.)
    local gitversion = substr("`filec'", 1,strpos("`filec'", ",")-1)
    di "The remote version is `gitversion'"
	return local localversion `localversion'
	return local gitversion  `gitversion'
end
