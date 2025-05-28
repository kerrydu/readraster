
cap program drop ncdisp_core
program define ncdisp_core,rclass
version 18


cap findfile netcdfAll-5.6.0.jar

if _rc{
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


//stgeocominit
syntax anything using/ ,[display]
removequotes,file(`anything')
local varname `r(file)'
removequotes,file(`using')
local file `r(file)'
local file = subinstr(`"`file'"',"\","/",.)

java: NetCDFReader.printVarStructure("`file'","`varname'");

return local varname `varname'
return local dimensions `dimensions' 
return local coordinates `coordAxes' 
return local datatype `datatype'
end


////////////////////////////////////////
cap program drop removequotes
program define removequotes,rclass
version 16
syntax, file(string) 
return local file `file'
end


java:
/cp "netcdfAll-5.6.0.jar"
import ucar.nc2.dataset.NetcdfDataset;
import ucar.nc2.Group;
import ucar.nc2.Dimension;
import ucar.nc2.Variable;
import ucar.nc2.Attribute;
import java.io.IOException;
import com.stata.sfi.*;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

public class NetCDFReader {
    // Add this static pattern at class level
    private static final java.util.regex.Pattern COORD_PATTERN = 
        java.util.regex.Pattern.compile("(?i)lat|lon|time|height|depth");
    
    public static void printVarStructure(String ncFileName, String variableName) {
        StringBuilder output = new StringBuilder(1024);
        try {
            // Add this line before opening the dataset to bypass SSL validation when needed
            System.setProperty("jdk.net.URLClassPath.disableClassPathURLCheck", "true");
            
            try (NetcdfDataset netcdfDataset = NetcdfDataset.openDataset(ncFileName)) {
                Variable variable = netcdfDataset.findVariable(variableName);
                if (variable == null) {
                    SFIToolkit.errorln("Variable " + variableName + " not found");
                    return;
                }
        
                output.append("\n=== Variable Structure ===\n");
                output.append(String.format("Name: %-25s Type: %-15s%n", 
                    variable.getShortName(), variable.getDataType()));
                
                System.out.println("\n=== Dimensions ===");
                System.out.printf("%-15s %-8s %-15s%n", "Dimension", "Length", "Coordinate");
                
                // Cache dimensions to avoid repeated method calls
                java.util.List<Dimension> dimensions = variable.getDimensions();
                
                // Use the cached dimensions list
                dimensions.forEach(dim -> 
                    System.out.printf("%-15s %-8d %-15s%n",
                        dim.getShortName(),
                        dim.getLength(),
                        isCoordinateAxis(dim) ? "[Yes]" : "")
                );
        
                // 新增标度参数输出区块
                System.out.println("\n=== Scale/Offset Parameters ===");
                String[] scaleAtts = {"scale_factor", "add_offset", "missing_value", "_FillValue"};
                Arrays.stream(scaleAtts).forEach(attName -> {
                    Attribute att = findAttributeRecursive(variable, attName);
                    if (att != null && att.getDataType().isNumeric()) {
                        double value = att.getNumericValue().doubleValue();
                        System.out.printf("%-15s: %-12.6f (Type: %s)%n",
                            attName.replace("_", " "), 
                            value,
                            att.getDataType());
                    }
                });
        
                System.out.println("\n=== Attributes ===");
                variable.getAttributes().forEach(attr -> {
                    String value = attr.getDataType().isString() ? 
                        attr.getStringValue() : attr.getNumericValue().toString();
                    System.out.printf("%-20s: %s%n", attr.getShortName(), value);
                });
        
                System.out.println("\n=== Metadata ===");
                Attribute unitAtt = variable.findAttribute("units");
                if (unitAtt != null) {
                    String unit = unitAtt.getStringValue()
                        .replace("degrees_", "°")
                        .replace("meters", "m");
                    System.out.printf("%-15s: %s (original: %s)%n", 
                        "Units", unit, unitAtt.getStringValue());
                    Macro.setLocal("unit", unitAtt.getStringValue());
                }
        
                int[] shape = variable.getShape();
                System.out.printf("%n%-15s: %s%n", "Shape", Arrays.toString(shape));
                System.out.printf("%-15s: %s%n", "Data Type", variable.getDataType());
                
                Macro.setLocal("dimensions", Arrays.stream(shape)
                    .mapToObj(String::valueOf)
                    .collect(Collectors.joining(" ")));
                    
                // Set the datatype macro
                Macro.setLocal("datatype", variable.getDataType().toString());
                
                // Set the coordinates macro
                String coordinates = variable.getDimensions().stream()
                    .filter(NetCDFReader::isCoordinateAxis)
                    .map(Dimension::getShortName)
                    .collect(Collectors.joining(" "));
                Macro.setLocal("coordAxes", coordinates);
                    
                // Then print once at the end
                System.out.print(output.toString());
            }
        } catch (IOException e) {
            // Improve error handling with specific SSL error message
            if (e.toString().contains("SSLHandshake") || e.toString().contains("PKIX path")) {
                SFIToolkit.errorln("SSL Certificate Error: Unable to validate the server's certificate.");
                SFIToolkit.errorln("This can happen when accessing NetCDF files via HTTPS.");
                SFIToolkit.errorln("Original error: " + e.getMessage());
            } else {
                SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
            }
        } catch (Exception e) {
            SFIToolkit.errorln("Unexpected error: " + SFIToolkit.stackTraceToString(e));
        }
    }
    
    // 添加属性查找方法
    private static Attribute findAttributeRecursive(Variable var, String attName) {
        // Check variable's attributes first (faster)
        Attribute att = var.findAttribute(attName);
        // Only check global attributes if not found at variable level
        return att != null ? att : var.getParentGroup().getNetcdfFile().findGlobalAttribute(attName);
    }

    private static String truncate(String value, int maxLength) {
        return value.length() > maxLength ? 
            value.substring(0, maxLength-3) + "..." : value;
    }

    // Then modify the isCoordinateAxis method
    private static boolean isCoordinateAxis(Dimension dim) {
        return COORD_PATTERN.matcher(dim.getShortName()).matches()
            || dim.getGroup().findVariable(dim.getShortName()) != null;
    }



}




end
