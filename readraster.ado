*! version 3.0.2, 2025-11-19
program define readraster

syntax, [update]
 
if "`update'" == "" {
	help readraster
}
else {
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
    if "`localversion'" == "`gitversion'" {
    	di "You have the latest version of readraster."
    }
    else {
        gettoken loci localversion : localversion, p(".")
        gettoken giti gitversion : gitversion, p(".")
        if "`loci'" !="" & "`giti'" !="" {
            if "`loci'" < "`giti'" {
                di "updating readraster...."
                net install readraster, from(https://raw.github.com/kerrydu/readraster/develop) replace force
            }
        }
    }

}

end