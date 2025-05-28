
cap program drop ncreadtocsv
program define ncreadtocsv
syntax anything using/,  csv(string) [Size(numlist integer) Origin(numlist integer >0) clear]
local varname `anything'
confirm name `varname'
parsecsvopt `csv'
local  csvfile `r(file)'

if `"`origin'"'!=""{
    ncreadtocsvbysec `anything' using `using', csv(`csvfile') size(`size') origin(`origin')
    exit
}

removequotes,file(`"`using'"')
local ncfile `r(file)'



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
local ncfile = usubinstr(`"`ncfile'"',"\","/",.)
local csvfile = usubinstr(`"`csvfile'"',"\","/",.)
cap qui findfile NCtoCSV.java
di 
//////////java//////////////////////
// java clear
// java: /cp "netcdfAll-5.6.0.jar"
// java: /open "NCtoCSV.java"
java: NCtoCSV.main("`ncfile'","`csvfile'","`varname'")


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

end

///////////////////////////


cap program drop removequotes
program define removequotes,rclass
version 16
syntax, file(string) 
return local file `file'
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

public class NCtoCSV {
    private static final int BUFFER_SIZE = 8192 * 1024;
    private static final long MAX_SAFE_ELEMENTS = 1_000_000_000;

    public static void main(String ncFilePath, String csvFilePath, String variableName) {
        try (NetcdfDataset ncDataset = NetcdfDataset.openDataset(ncFilePath)) {
            Variable mainVar = ncDataset.findVariable(variableName);
            if (mainVar == null) {
                SFIToolkit.errorln("Variable " + variableName + " not found");
                return;
            }

            List<Variable> coordVars = new ArrayList<>();
            Map<Variable, Integer> dimOrderMap = new HashMap<>();
            List<Dimension> mainDims = mainVar.getDimensions();
            
            for (int dimIndex = 0; dimIndex < mainDims.size(); dimIndex++) {
                Dimension dim = mainDims.get(dimIndex);
                Variable coordVar = ncDataset.findVariable(dim.getShortName());
                if (coordVar != null) {
                    coordVars.add(coordVar);
                    dimOrderMap.put(coordVar, dimIndex);
                }
            }

            long totalSize = calculateTotalSize(coordVars);
            System.out.println("Total rows: " + totalSize);

            if (totalSize > MAX_SAFE_ELEMENTS) {
                SFIToolkit.errorln("Warning: Dataset too large");
                return;
            }

            try (BufferedWriter writer = new BufferedWriter(new FileWriter(csvFilePath), BUFFER_SIZE)) {
                writeHeader(writer, coordVars, variableName);
                processData(writer, coordVars, mainVar, totalSize, dimOrderMap);
                System.out.println("Data written to CSV: " + csvFilePath);
            }
        } catch (IOException e) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
        }
    }

    private static long calculateTotalSize(List<Variable> coordVars) {
        long totalSize = 1;
        for (Variable coordVar : coordVars) totalSize *= coordVar.getSize();
        return totalSize;
    }

    private static void writeHeader(BufferedWriter writer, List<Variable> coordVars, String variableName) throws IOException {
        for (Variable coordVar : coordVars) writer.write(coordVar.getShortName() + ",");
        writer.write(variableName + "\n");
    }

    private static void processData(BufferedWriter writer, List<Variable> coordVars, 
                                   Variable mainVar, long totalSize, 
                                   Map<Variable, Integer> dimOrderMap) throws IOException {
        StringBuilder sb = new StringBuilder();
        int[] shape = new int[mainVar.getRank()];
        List<Dimension> dims = mainVar.getDimensions();
        for (int i = 0; i < dims.size(); i++) shape[i] = dims.get(i).getLength();

        int[] dimIndexes = new int[coordVars.size()];
        for (int i = 0; i < coordVars.size(); i++) 
            dimIndexes[i] = dimOrderMap.get(coordVars.get(i));

        List<double[]> coordCache = new ArrayList<>();
        for (Variable var : coordVars) 
            coordCache.add((double[]) var.read().get1DJavaArray(double.class));

        double[] mainValues = (double[]) mainVar.read().get1DJavaArray(double.class);

        for (long i = 0; i < totalSize; i++) {
            int[] indices = calculateIndices(i, shape);
            
            for (int j = 0; j < coordVars.size(); j++) {
                int actualDim = dimIndexes[j];
                sb.append(coordCache.get(j)[indices[actualDim]]).append(",");
            }
            
            sb.append(mainValues[(int)i]).append("\n");
            
            if (sb.length() > BUFFER_SIZE) {
                writer.write(sb.toString());
                sb.setLength(0);
            }
        }
        
        if (sb.length() > 0) writer.write(sb.toString());
    }

    private static int[] calculateIndices(long flatIndex, int[] shape) {
        int[] indices = new int[shape.length];
        for (int i = shape.length-1; i >= 0; i--) {
            indices[i] = (int)(flatIndex % shape[i]);
            flatIndex /= shape[i];
        }
        return indices;
    }
}

end
