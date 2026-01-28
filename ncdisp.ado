*! version 3.0.2 2026-1-27
cap program drop ncdisp
program define ncdisp,rclass
version 17

cap findfile NetCDFUtils-complete.jar
if !_rc {
    local 00 `0'
    ncdisp_2 `0'
    gettoken varname 00 : 00
    return local varname `varname'
    return local dimensions `r(dimensions)' 
    return local coordinates `r(coordAxes)' 
    return local datatype `r(datatype)'
    exit
}

cap findfile netcdfAll-5.9.1.jar

if _rc{
    cap findfile path_ncreadjar.ado 
    if _rc {
        di as error "jar path NOT specified, use netcdf_init for setting up"
        disp "see " `"{help netcdf_init:help netcdf_init}"'
        exit
        
    }

    path_ncreadjar
    local path `r(path)'

    cap findfile netcdfAll-5.9.1.jar, path(`"`path'"')
    if _rc {
        di as error "Missing Java dependencies, netcdfAll-5.9.1.jar NOT found"
        di as error "make sure netcdfAll-5.9.1.jar exists in your specified directory"
		disp "see " `"{help netcdf_init:help netcdf_init}"' " for setting up"
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

    // 使用javacall调用新的JAR文件
    // javacall NetCDFUtils printVarStructureEntry, jars("NetCDFUtils-complete.jar") args("`file'" "`varname'")
    netcdfutils NetCDFUtils.printVarStructure("`file'","`varname'")

    return local varname `varname'
    return local dimensions `r(dimensions)' 
    return local coordinates `r(coordAxes)' 
    return local datatype `r(datatype)'
end

cap program drop ncinfo
program define ncinfo
    version 17
    syntax anything,[display]

    removequotes,file(`"`anything'"')
    local file `r(file)'
    local file = subinstr(`"`file'"',"\","/",.)
    
    // 使用javacall调用新的JAR文件
    netcdfutils NetCDFUtils.printNetCDFStructure("`file'")

end

cap program drop removequotes
program define removequotes,rclass
    version 16
    syntax, file(string) 
    return local file `file'
end



cap program drop ncdisp_2
program define ncdisp_2,rclass
version 17


    // 允许 varname 可选
    syntax [anything] using/, [display]

    removequotes, file(`"`using'"')
    local file `r(file)'
    local file = subinstr(`"`file'"',"\","/",.)

    if "`anything'" == "" {
        // 没有变量名，直接调用 ncinfo
        ncinfo_2 "`file'"
        exit
    }

    // 有变量名，输出变量元数据
    removequotes, file(`anything')
    local varname `r(file)'

    // 使用javacall调用新的JAR文件
    javacall NetCDFUtils printVarStructureEntry, jars("NetCDFUtils-complete.jar") args("`file'" "`varname'")
    //netcdfutils NetCDFUtils.printVarStructure("`file'","`varname'")

    return local varname `varname'
    return local dimensions `dimensions' 
    return local coordAxes `coordAxes' 
    return local datatype `datatype'
end

cap program drop ncinfo_2
program define ncinfo_2
    version 17
    syntax anything,[display]

    removequotes,file(`"`anything'"')
    local file `r(file)'
    local file = subinstr(`"`file'"',"\","/",.)
    
    // 使用javacall调用新的JAR文件
    javacall NetCDFUtils printNetCDFStructureEntry, jars("NetCDFUtils-complete.jar") args("`file'")


end

