

cap program drop ncinfo
program define ncinfo
    version 18
    syntax anything,[display]
    removequotes,file(`"`anything'"')
    local file `r(file)'
    local file = subinstr(`"`file'"',"\","/",.)
    java: NetCDFinfo.printNetCDFStructure("`file'");

end

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

public class NetCDFinfo {
    
    // 添加属性查找方法
    private static Attribute findAttributeRecursive(Variable var, String attName) {
        Attribute att = var.findAttribute(attName);
        if (att == null) {
            att = var.getParentGroup().getNetcdfFile().findGlobalAttribute(attName);
        }
        return att;
    }
    public static void printNetCDFStructure(String ncFileName) {
        try (NetcdfDataset netcdfDataset = NetcdfDataset.openDataset(ncFileName)) {
            System.out.println("\n=== File Structure ===");
            
            System.out.println("\n[Global Attributes]");
            netcdfDataset.getGlobalAttributes().forEach(attr -> 
                System.out.printf("%-25s: %s%n", 
                    attr.getShortName(), 
                    truncate(attr.getStringValue(), 50))
            );

            System.out.println("\n[Dimensions]");
            Set<String> axisDims = netcdfDataset.getVariables().stream()
                .filter(var -> var.findAttribute("axis") != null ||
                    var.getShortName().matches("(?i)time|lat|lon"))
                .map(Variable::getShortName)
                .collect(Collectors.toSet());

            System.out.printf("%-20s %-8s %-15s%n", "Name", "Length", "Attribute");
            netcdfDataset.getDimensions().forEach(dim -> 
                System.out.printf("%-20s %-8d %-15s%n",
                    dim.getShortName(),
                    dim.getLength(),
                    axisDims.contains(dim.getShortName()) ? "Coordinate" : "")
            );

            System.out.println("\n[Variables]");
            System.out.printf("%-25s %-30s %-15s%n", "Name", "Dimensions", "Type");
            netcdfDataset.getVariables().forEach(var -> 
                System.out.printf("%-25s %-30s %-15s%n",
                    var.getShortName(),
                    var.getDimensionsString(),
                    var.getDataType())
            );

            System.out.println("\n[Groups]");
            netcdfDataset.getRootGroup().getGroups().forEach(group -> {
                System.out.printf("Group: %s%n", group.getShortName());
                System.out.printf("%-25s %-8s%n", "Dimensions", "Variables");
                System.out.printf("%-25s %-8s%n",
                    group.getDimensions().size(),
                    group.getVariables().size());
            });
            
        } catch (IOException e) {
            SFIToolkit.errorln("Error: " + e.getMessage());
        }
    }

    private static String truncate(String value, int maxLength) {
        return value.length() > maxLength ? 
            value.substring(0, maxLength-3) + "..." : value;
    }

    private static boolean isCoordinateAxis(Dimension dim) {
        return dim.getShortName().matches("(?i)lat|lon|time|height|depth") 
            || dim.getGroup().findVariable(dim.getShortName()) != null;
    }



}




end
