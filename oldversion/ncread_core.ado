

cap program drop ncread_core 
program define ncread_core 
version 18

syntax [anything] using/,  [Size(numlist integer) Origin(numlist integer >0) CLEAR CSV(string) display]


removequotes,file(`"`using'"')
local file `r(file)'
local file = subinstr(`"`file'"',"\","/",.)
mata: st_numscalar("r(isurl)",pathisurl(`"`file'"'))
local isurl = r(isurl)
if `isurl'==0 & fileexists(`"`using'"')==0{
    di as error `"`using' NOT exists"'
    exit 198
}

// check if the file is a nc file
local ext = substr(`"`using'"',length("`file'")-2,.)
if "`ext'" != ".nc" {
    di as error "Not a nc file"
    exit 198
}

if `"`anything'"'==""{
    ncinfo `"`file'"'
    exit
}
if "`display'"!=""{
    ncdisp `0'
}

if "`csv'"!=""{
    ncreadtocsv `0'
    exit
}


if "`clear'"=="" & `"`csv'"'==""{
    qui describe
    if r(N) != 0 | r(k) != 0 {
        di as error "Current dataset is NOT empty, using clear option"
        exit 198
    }
}
`clear'

if `"`origin'"'!=""{
    ncreadbysec `0'
    exit
}

removequotes,file(`anything')
local varname `r(file)'
confirm new var `varname'


java: NCtoStata.main("`file'","`varname'")

if `=_N'>0 {
    disp "Sucessfully import `=_N' Obs into Stata."
}

end

/////////////////////////////////////////////
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
import ucar.ma2.InvalidRangeException;
import ucar.nc2.dataset.NetcdfDataset;
import com.stata.sfi.*;

public class NCtoStata {
    private static final long MAX_SAFE_ELEMENTS = 1_000_000_000;
    private static final int BLOCK_SIZE = 100_000;

    public static void main(String ncFilePath, String variableName) {
        try (NetcdfDataset ncFile = NetcdfDataset.openDataset(ncFilePath)) {
            Variable mainVar = ncFile.findVariable(variableName);
            if (mainVar == null) {
                SFIToolkit.errorln("Variable " + variableName + " not found");
                return;
            }

            List<Variable> coordVars = new ArrayList<>();
            Map<Variable, Integer> dimOrderMap = new HashMap<>();
            List<Dimension> mainDimensions = mainVar.getDimensions();
            for (int dimIndex = 0; dimIndex < mainDimensions.size(); dimIndex++) {
                Dimension dim = mainDimensions.get(dimIndex);
                Variable coordVar = ncFile.findVariable(dim.getShortName());
                if (coordVar != null) {
                    coordVars.add(coordVar);
                    dimOrderMap.put(coordVar, dimIndex);
                }
            }

            long totalSize = calculateTotalSize(coordVars);
            if (totalSize > MAX_SAFE_ELEMENTS) {
                SFIToolkit.errorln("Dataset exceeds size limit");
                return;
            }

            createStataVariables(coordVars, variableName, totalSize);
            processData(coordVars, mainVar, totalSize, dimOrderMap);
            Data.updateModified();
        } catch (Exception e) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
        }
    }

    private static long calculateTotalSize(List<Variable> coordVars) {
        long total = 1;
        for (Variable var : coordVars) total *= var.getSize();
        return total;
    }

    private static void createStataVariables(List<Variable> coordVars, String varName, long totalSize) {
        if (totalSize > Integer.MAX_VALUE) {
            SFIToolkit.errorln("Observation limit exceeded");
            return;
        }
        Data.setObsTotal((int) totalSize);
        for (Variable var : coordVars) Data.addVarDouble(var.getShortName());
        Data.addVarDouble(varName);
    }

    private static void processData(List<Variable> coordVars, Variable mainVar, 
                                   long totalSize, Map<Variable, Integer> dimOrderMap) throws IOException {
    
            List<double[]> coordCache = new ArrayList<>();
            for (Variable var : coordVars) {
                Array data = var.read();
                coordCache.add((double[]) data.get1DJavaArray(double.class));
            }

            Array mainArray = mainVar.read();
            double[] mainValues = (double[]) mainArray.get1DJavaArray(double.class);

            int[] shape = coordVars.stream()
                .mapToInt(v -> (int)v.getSize())
                .toArray();

            int[] dimIndexes = new int[coordVars.size()];
            for (int i = 0; i < coordVars.size(); i++) {
                dimIndexes[i] = dimOrderMap.get(coordVars.get(i));
            }

            double[] buffer = new double[coordVars.size() + 1];
            
            for (int blockStart = 0; blockStart < totalSize; blockStart += BLOCK_SIZE) {
                int blockEnd = (int) Math.min(blockStart + BLOCK_SIZE, totalSize);
                
                for (int obs = blockStart; obs < blockEnd; obs++) {
                    int[] indices = calculateIndices(obs, shape);
                    int row = obs + 1;

                    for (int varIdx = 0; varIdx < coordVars.size(); varIdx++) {
                        buffer[varIdx] = coordCache.get(varIdx)[indices[dimIndexes[varIdx]]];
                    }
                    buffer[coordVars.size()] = mainValues[obs];

                    for (int col = 0; col < buffer.length; col++) {
                        Data.storeNumFast(col + 1, row, buffer[col]);
                    }
                }
            }
            Data.updateModified();
    
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
