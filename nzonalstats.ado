*! version 1.0.0  2024-01-01
*! NetCDF Zonal Statistics
*! Kerry Du, kerrydu@msu.edu

cap program drop nzonalstats
program define nzonalstats
version 17

syntax using/, var(string) [STATs(string) clear]

if missing("`var'") {
    di as error "Variable name must be specified with var() option"
    exit 198
}

if missing("`stats'") {
    local stats "avg"
}

qui nzonalstats_core `using', var(`var') stats(`stats') `clear'

end