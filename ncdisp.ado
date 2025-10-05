*! version 2.0.1 2025-10-05
cap program drop ncdisp
program define ncdisp,rclass
version 18

 cap findfile NetCDFUtils-complete.jar
if _rc {
    di as error "NetCDFUtils-complete.jar NOT found"
    di as error "make sure NetCDFUtils-complete.jar exists in your adopath"
    exit
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
    javacall NetCDFUtils printVarStructureEntry, jars("NetCDFUtils-complete.jar") args("`file'" "`varname'")

    return local varname `varname'
    return local dimensions `dimensions' 
    return local coordinates `coordAxes' 
    return local datatype `datatype'
end

cap program drop ncinfo
program define ncinfo
    version 18
    syntax anything,[display]

    cap findfile NetCDFUtils-complete.jar, path(`"`path'"')
    if _rc {
        di as error "NetCDFUtils-complete.jar NOT found"
        di as error "make sure NetCDFUtils-complete.jar exists in your adopath"
        exit
    }

    removequotes,file(`"`anything'"')
    local file `r(file)'
    local file = subinstr(`"`file'"',"\","/",.)
    
    // 使用javacall调用新的JAR文件
    javacall NetCDFUtils printNetCDFStructureEntry, jars("NetCDFUtils-complete.jar") args("`file'")

end

cap program drop removequotes
program define removequotes,rclass
    version 16
    syntax, file(string) 
    return local file `file'
end
