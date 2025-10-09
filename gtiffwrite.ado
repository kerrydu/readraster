cap program drop gtiffwrite
program define gtiffwrite
version 17
syntax anything, [xvar(varname) yvar(varname) valuevar(varname) crs(string) nodata(real -9999) resolution(numlist min=2 max=2) replace]

gtiffwrite_core `0'

end