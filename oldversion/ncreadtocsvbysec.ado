cap program drop ncreadtocsvbysec
program define ncreadtocsvbysec
syntax anything using/,  csv(string) [Size(numlist integer) Origin(numlist integer >0)]
local varname `anything'
confirm name `varname'
local csvfile `csv'
removequotes,file(`using')
local ncfile `r(file)'

local ncfile = usubinstr(`"`ncfile'"',"\","/",.)
local csvfile = usubinstr(`"`csvfile'"',"\","/",.)



local no: word count `origin'
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

// Convert Stata 1-based indices to Java 0-based indices
local origin0
forv i=1/`no'{
    local oi: word `i' of `origin'
    local origin0 `origin0' `=`oi'-1'
}

// No need for any other validation - Java will handle it all
di
java: NCtoCSVbySection.main("`ncfile'","`csvfile'","`varname'","`origin0'","`size'")
end 



cap program drop parsecsvopt
program define parsecsvopt,rclass
syntax anything, [replace]

local file `anything'
local replace `replace'

removequotes,file(`"`file'"')
local file `r(file)'
local flag = fileexists(`"`file'"')


if "`replace'"=="" & `flag'{
    di as error "file exist, adding replace in csv() to overwrite it."
    exit 198
}

return local file `file'




cap program drop removequotes
program define removequotes,rclass
version 16
syntax, file(string) 
return local file `file'
end


java:

/cp netcdfAll-5.6.0.jar
import ucar.nc2.dataset.NetcdfDataset;
import ucar.nc2.Variable;
import ucar.ma2.Array;
import ucar.nc2.Dimension;
import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import ucar.ma2.InvalidRangeException;
import com.stata.sfi.*;

public class NCtoCSVbySection {
    private static final int BUFFER_SIZE = 8192 * 1024;
    private static final long MAX_SAFE_ELEMENTS = 1_000_000_000;

    public static void main(String ncFilePath, String csvFilePath, String variableName, String start, String count) {
        int[] origin = parseIndices(start);
        int[] size = parseIndices(count);

        try (NetcdfDataset ncFile = NetcdfDataset.openDataset(ncFilePath)) {
            Variable mainVar = ncFile.findVariable(variableName);
            if (mainVar == null) {
                SFIToolkit.errorln("Variable " + variableName + " not found");
                return;
            }

            List<Dimension> dims = mainVar.getDimensions();
            
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

            List<Variable> coordVars = new ArrayList<>();
            Map<Variable, Integer> dimIndexMap = new HashMap<>();
            for (int i = 0; i < dims.size(); i++) {
                Dimension dim = dims.get(i);
                Variable coordVar = ncFile.findVariable(dim.getShortName());
                if (coordVar != null) {
                    coordVars.add(coordVar);
                    dimIndexMap.put(coordVar, i);
                }
            }

            long totalSize = calculateTotalSize(size);
            if (totalSize > MAX_SAFE_ELEMENTS) {
                SFIToolkit.errorln("Dataset too large");
                return;
            }

            try (BufferedWriter writer = new BufferedWriter(new FileWriter(csvFilePath), BUFFER_SIZE)) {
                writeHeader(writer, coordVars, variableName);
                processData(writer, coordVars, mainVar, origin, size, totalSize, dimIndexMap);
                System.out.println("Data written to CSV: " + csvFilePath);
            }
        } catch (Exception e) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
        }
    }

    private static int[] parseIndices(String str) {
        String[] parts = str.split(" ");
        int[] indices = new int[parts.length];
        for (int i = 0; i < parts.length; i++) {
            indices[i] = Integer.parseInt(parts[i]);
        }
        return indices;
    }

    private static long calculateTotalSize(int[] size) {
        long total = 1;
        for (int s : size) total *= s;
        return total;
    }

    private static void writeHeader(BufferedWriter writer, List<Variable> coordVars, String varName) 
        throws IOException {
        for (Variable var : coordVars) {
            writer.write(var.getShortName() + ",");
        }
        writer.write(varName + "\n");
    }

    private static void processData(BufferedWriter writer, List<Variable> coordVars, Variable mainVar,
                                   int[] origin, int[] size, long totalSize, Map<Variable, Integer> dimIndexMap)
        throws IOException, InvalidRangeException {
        
        // 预加载坐标数据
        List<double[]> coordCache = new ArrayList<>();
        for (Variable var : coordVars) {
            Array fullData = var.read();
            coordCache.add((double[]) fullData.get1DJavaArray(double.class));
        }

        // 主变量切片读取
        Array mainData = mainVar.read(origin, size);
        double[] mainValues = (double[]) mainData.get1DJavaArray(double.class);

        // 生成维度索引数组
        int[] dimIndexes = new int[coordVars.size()];
        for (int i = 0; i < coordVars.size(); i++) {
            dimIndexes[i] = dimIndexMap.get(coordVars.get(i));
        }

        // 预计算索引
        int[] shape = size.clone();
        int[][] indexMap = new int[(int) totalSize][];
        for (long i = 0; i < totalSize; i++) {
            indexMap[(int)i] = calculateIndices(i, shape);
        }

        // 缓冲优化
        StringBuilder sb = new StringBuilder(BUFFER_SIZE * 2);
        final int ROW_SIZE = coordVars.size() + 1;
        String[] rowBuffer = new String[ROW_SIZE];

        for (long i = 0; i < totalSize; i++) {
            int[] indices = indexMap[(int)i];
            
            // 处理坐标值
            for (int j = 0; j < coordVars.size(); j++) {
                int actualDim = dimIndexes[j];
                int pos = origin[actualDim] + indices[actualDim];
                rowBuffer[j] = String.valueOf(coordCache.get(j)[pos]);
            }
            
            // 处理主变量值
            rowBuffer[coordVars.size()] = String.valueOf(mainValues[(int)i]);
            
            // 构建CSV行
            sb.append(String.join(",", rowBuffer)).append("\n");

            // 缓冲控制
            if (sb.length() > BUFFER_SIZE) {
                writer.write(sb.toString());
                sb.setLength(0);
            }
        }

        if (sb.length() > 0) {
            writer.write(sb.toString());
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
