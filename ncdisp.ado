cap program drop ncdisp
program define ncdisp,rclass
version 18


    cap findfile netcdfAll-5.6.0.jar
    if _rc {
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

    // 允许 varname 可选
    syntax [anything] using/, [display]

    removequotes, file(`"`using'"')
    local file `r(file)'
    local file = subinstr(`"`file'"',"\","/",.)

    if "`anything'" == "" {
        // 没有变量名，直接调用 ncinfo
        ncinfo "`file'"
        exit
    }

    // 有变量名，输出变量元数据
    removequotes, file(`anything')
    local varname `r(file)'

    java clear
    java: /cp "netcdfAll-5.6.0.jar"
    java: /open "NetCDFReader.java"
    java: NetCDFReader.printVarStructure("`file'","`varname'")

    return local varname `varname'
    return local dimensions `dimensions' 
    return local coordinates `coordAxes' 
    return local datatype `datatype'
end

cap program drop removequotes
program define removequotes,rclass
version 16
syntax, file(string) 
return local file `file'
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
