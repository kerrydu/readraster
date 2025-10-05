cap program drop ncreadbysec 
program define ncreadbysec 
version 18
syntax anything using/,  [Size(numlist integer) clear] Origin(numlist integer >0)

removequotes,file(`anything')
local varname `r(file)'
confirm new var `varname'
removequotes,file(`"`using'"')
local file `r(file)'
local file = subinstr(`"`file'"',"\","/",.)
di _n 

local no: word count `origin'

for i=1/`no'{
    local oi: word `i' of `origin'
    local origin0 `origin0' `=`oi'-1'
}

if "`size'"==""{
    forv j=1/`no'{
        local size `size' -1
    }
}

local nc: word count `size'
if `nc' != `no' {
    di as error "The number of origin and size should be the same."
    exit
}

////////////import java////////////
// java clear
// java: /cp "netcdfAll-5.6.0.jar"
// java: /open "NetCDFReader.java"
// java: /open "NCtoStatabySection.java"

// qui java: NetCDFReader.printVarStructure("`file'","`varname'")
// qui ncdisp `varname' using `file'
java: NCtoStatabySection.main("`file'","`varname'","`origin0'","`size'")

local dimensions `dimensions'
local coordAxes `coordAxes'

// The Java code will have already performed the dimension validation
// We can still access the dimension information through the macros set by Java

if `=_N'>0 {
    disp "Sucessfully import `=_N' Obs into Stata."
}

 end


cap program drop removequotes
program define removequotes,rclass
    version 16
    syntax, file(string) 
    return local file `file'
end


java:
/cp netcdfAll-5.6.0.jar
import ucar.nc2.Variable;
import ucar.ma2.Array;
import ucar.nc2.Dimension;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.xml.crypto.Data;
import ucar.nc2.dataset.NetcdfDataset;
import ucar.ma2.InvalidRangeException;
import com.stata.sfi.*;
import com.stata.sfi.Data;

public class NCtoStatabySection {
    private static final long MAX_SAFE_ELEMENTS = 1_000_000_000;
    private static final int BLOCK_SIZE = 100_000;

    public static void main(String ncFilePath, String variableName, String strorigin, String strsize) {
        String[] originStr = strorigin.split(" ");
        String[] sizeStr = strsize.split(" ");
        int[] origin = new int[originStr.length];
        int[] size = new int[sizeStr.length];

        for (int i = 0; i < originStr.length; i++) {
            origin[i] = Integer.parseInt(originStr[i]);
        }
        for (int i = 0; i < sizeStr.length; i++) {
            size[i] = Integer.parseInt(sizeStr[i]);
        }

        try (NetcdfDataset ncFile = NetcdfDataset.openDataset(ncFilePath)) {
            Variable mainVar = ncFile.findVariable(variableName);
            if (mainVar == null) {
                SFIToolkit.errorln("Variable " + variableName + " not found");
                return;
            }

            List<Dimension> dims = mainVar.getDimensions();
            
            // Return dimension information to Stata
            StringBuilder dimSizes = new StringBuilder();
            StringBuilder coordAxesBuilder = new StringBuilder();
            
            for (int i = 0; i < dims.size(); i++) {
                Dimension dim = dims.get(i);
                if (i > 0) dimSizes.append(" ");
                dimSizes.append(dim.getLength());
                
                // Check if dimension is a coordinate axis
                Variable coordVar = ncFile.findVariable(dim.getShortName());
                if (coordVar != null) {
                    if (coordAxesBuilder.length() > 0) coordAxesBuilder.append(" ");
                    coordAxesBuilder.append(dim.getShortName());
                }
            }
            
            // Set dimension info as Stata locals
            Macro.setLocal("dimensions", dimSizes.toString());
            Macro.setLocal("coordAxes", coordAxesBuilder.toString());
            
            // Validate dimensions match
            if (origin.length != dims.size() || size.length != dims.size()) {
                SFIToolkit.errorln("The number of origin and count should be equal # of axes in nc file.");
                return;
            }
            
            // Validate range bounds for each dimension
            for (int i = 0; i < dims.size(); i++) {
                int dimLength = dims.get(i).getLength();
                
                // Check if origin is within bounds
                if (origin[i] < 0 || origin[i] >= dimLength) {
                    SFIToolkit.errorln("Origin index " + (origin[i] + 1) + " is out of bounds for dimension " + 
                                      dims.get(i).getShortName() + " with length " + dimLength);
                    return;
                }
                
                // Handle special case: size[i] = -1 means "read to the end"
                int effectiveSize = size[i];
                if (effectiveSize == -1) {
                    effectiveSize = dimLength - origin[i];
                    size[i] = effectiveSize; // Update size for actual reading
                }
                
                // Check if origin + size is within bounds
                if (origin[i] + effectiveSize > dimLength) {
                    SFIToolkit.errorln("Reading section exceeds bounds for dimension " + 
                                      dims.get(i).getShortName() + ": origin=" + (origin[i] + 1) + 
                                      ", size=" + effectiveSize + ", dimension length=" + dimLength);
                    return;
                }
            }
            
            // Remaining code continues as before...

            List<Variable> coordVars = new ArrayList<>();
            Map<Variable, Integer> dimIndexMap = new HashMap<>();
            // for (int i = 0; i < dims.size(); i++) {
            //     Variable coordVar = ncFile.findVariable(dims.get(i).getShortName());
            //     if (coordVar != null) {
            //         coordVars.add(coordVar);
            //         dimIndexMap.put(coordVar, i);
            //     }
            // }

            // 修改dimIndexMap的生成逻辑
            for (int i = 0; i < dims.size(); i++) {
                Dimension dim = dims.get(i); // 获取主变量的维度
                Variable coordVar = ncFile.findVariable(dim.getShortName());
                if (coordVar != null) {
                    coordVars.add(coordVar);
                    dimIndexMap.put(coordVar, i); // 记录该坐标变量对应的维度索引
                }
            }


            long totalSize = calculateTotalSize(size);
            if (totalSize > MAX_SAFE_ELEMENTS) {
                SFIToolkit.errorln("Reading Section too large");
                return;
            }

            createStataVariables(coordVars, variableName, totalSize);
            processData(coordVars, mainVar, totalSize, origin, size, dimIndexMap);
            Data.updateModified();
        } catch (Exception e) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
        }
    }

    private static long calculateTotalSize(int[] size) {
        long total = 1;
        for (int s : size) total *= s;
        return total;
    }

    private static void createStataVariables(List<Variable> coordVars, String varName, long totalSize) {
        if (totalSize > Integer.MAX_VALUE) {
            SFIToolkit.errorln("Dataset exceeds Stata limit");
            return;
        }
        Data.setObsTotal((int) totalSize);
        coordVars.forEach(v -> Data.addVarDouble(v.getShortName()));
        Data.addVarDouble(varName);
    }

    // 优化后的processData方法核心代码
    private static void processData(List<Variable> coordVars, Variable mainVar, 
                               long totalSize, int[] origin, int[] size,
                               Map<Variable, Integer> dimIndexMap) throws IOException {
    try {
        // 1. 预加载坐标数据
        List<double[]> coordCache = new ArrayList<>();
        for (Variable var : coordVars) {
            Array fullData = var.read();
            coordCache.add((double[]) fullData.get1DJavaArray(double.class));
        }

        // 2. 读取主变量切片数据
        Array mainData = mainVar.read(origin, size);
        double[] mainValues = (double[]) mainData.get1DJavaArray(double.class);

        // 3. 生成维度索引映射数组
        int[] dimIndexes = new int[coordVars.size()];
        for (int i = 0; i < coordVars.size(); i++) {
            dimIndexes[i] = dimIndexMap.get(coordVars.get(i));
        }

        // 4. 创建索引映射（根据主变量维度顺序）
        int[][] indexMap = new int[(int) totalSize][];
        for (int i = 0; i < totalSize; i++) {
            indexMap[i] = calculateIndices(i, size);
        }

        // 5. 数据写入缓冲区
        double[] rowBuffer = new double[coordVars.size() + 1];
        
        for (int blockStart = 0; blockStart < totalSize; blockStart += BLOCK_SIZE) {
            int blockEnd = (int) Math.min(blockStart + BLOCK_SIZE, totalSize);
            
            for (int i = blockStart; i < blockEnd; i++) {
                int[] indices = indexMap[i];
                int row = i + 1;

                // 填充坐标值（按主变量维度顺序）
                for (int dim = 0; dim < coordVars.size(); dim++) {
                    int actualDim = dimIndexes[dim]; // 获取原始维度位置
                    int pos = origin[actualDim] + indices[actualDim];
                    rowBuffer[dim] = coordCache.get(dim)[pos];
                }

                // 填充主变量值
                rowBuffer[coordVars.size()] = mainValues[i];

                // 批量存储到Stata
                for (int col = 0; col < rowBuffer.length; col++) {
                    Data.storeNumFast(col + 1, row, rowBuffer[col]);
                }
            }
        }
        
        Data.updateModified();
    } catch (InvalidRangeException e) {
        SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
    }
}
    private static int[] calculateIndices(long index, int[] shape) {
        int[] indices = new int[shape.length];
        for (int i = shape.length-1; i >= 0; i--) {
            indices[i] = (int)(index % shape[i]);
            index /= shape[i];
        }
        return indices;
    }
}


 end
