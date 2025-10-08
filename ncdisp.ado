*! version 3.0.1 2025-10-07
cap program drop ncdisp
program define ncdisp,rclass
version 17

    // cap findfile NetCDFUtils-complete.jar
    // if _rc {
    //     display as "installing the jar file, please wait..."
    //      cap net install netcdfutil.pkg, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/main/)
    //      if _rc {
    //         cap cnssc install netcdfutil.pkg
    //      }
    //      sleep 1000

    // }
    // cap findfile NetCDFUtils-complete.jar
    // if _rc {
    //     di as error "downloading NetCDFUtils-complete.jar failed"
    //     di `"please go to {browse "https://github.com/kerrydu/readraster": Github/kerrydu/readraster} to download it and put it in your adopath"'
    //     exit
    // }
    // local jarfiles `r(filename)'

cap findfile netcdfAll-5.9.1.jar

if _rc{
    cap findfile path_ncreadjar.ado 
    if _rc {
        di as error "jar path NOT specified, use netcdf_init for setting up"
        disp "see " `"{view "netcdf_init.sthlp":help netcdf_init}"'
        exit
        
    }

    path_ncreadjar
    local path `r(path)'

    cap findfile netcdfAll-5.9.1.jar, path(`"`path'"')
    if _rc {
        di as error "Missing Java dependencies, netcdfAll-5.9.1.jar NOT found"
        di as error "make sure netcdfAll-5.9.1.jar exists in your specified directory"
		disp "see " `"{view "netcdf_init.sthlp":help netcdf_init}"' " for setting up"
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
    return local dimensions `dimensions' 
    return local coordinates `coordAxes' 
    return local datatype `datatype'
end

cap program drop ncinfo
program define ncinfo
    version 17
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
    // javacall NetCDFUtils printNetCDFStructureEntry, jars("NetCDFUtils-complete.jar") args("`file'")
    netcdfutils NetCDFUtils.printNetCDFStructure("`file'")

end

cap program drop removequotes
program define removequotes,rclass
    version 16
    syntax, file(string) 
    return local file `file'
end
