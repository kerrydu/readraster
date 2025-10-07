*! version 3.0.1   2025-10-07
* NetCDF Utilities for processing NetCDF files in Stata
*
program define netcdfutils 
    version 17
    java: `0'


end 

java:
// NetCDF Java Library imports (5.9.1 版本)
/cp netcdfAll-5.9.1.jar

import ucar.nc2.dataset.NetcdfDataset;
import ucar.nc2.dataset.NetcdfDatasets;
import ucar.nc2.Dimension;
import ucar.nc2.Variable;
import ucar.nc2.Attribute;
import ucar.ma2.Array;
import ucar.ma2.DataType;
import ucar.ma2.InvalidRangeException;

// Java standard library imports
import java.io.IOException;
import java.io.BufferedWriter;
import java.io.FileWriter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

// Stata SFI imports
import com.stata.sfi.*;

/**
 * NetCDFUtils - 统一的NetCDF文件处理工具类
 * 
 * 本类整合了原先分散在多个类中的NetCDF文件读取、显示、转换功能，
 * 提供了一套完整的NetCDF数据处理方案。
 * 
 * 主要功能包括：
 * 1. 显示NetCDF文件结构和变量信息
 * 2. 读取NetCDF数据到Stata
 * 3. 按指定区域读取NetCDF数据  
 * 4. 将NetCDF数据导出为CSV文件
 * 5. 按指定区域导出NetCDF数据为CSV
 * 
 * 所有方法都提供了符合 javacall 要求的入口函数
 */

public class NetCDFUtils {
    
    // 常量定义
    private static final long MAX_SAFE_ELEMENTS = 1_000_000_000;
    private static final int BLOCK_SIZE = 100_000;
    private static final int BUFFER_SIZE = 8192 * 1024;
    
    // 坐标轴识别模式
    private static final java.util.regex.Pattern COORD_PATTERN = 
        java.util.regex.Pattern.compile("(?i)lat|lon|time|height|depth");

    // ================= JAVACALL 入口函数 =================
    
    /**
     * javacall 入口：显示变量结构信息
     * 调用方式：javacall NetCDFUtils printVarStructureEntry, args("ncfile" "varname")
     */
    public static int printVarStructureEntry(String[] args) {
        if (args.length != 2) {
            SFIToolkit.errorln("Usage: printVarStructureEntry ncFilePath variableName");
            return 198; // Stata error code for invalid syntax
        }
        try {
            printVarStructure(args[0], args[1]);
            return 0; // Success
        } catch (Exception e) {
            SFIToolkit.errorln("Error in printVarStructureEntry: " + e.getMessage());
            return 111; // General error
        }
    }
    
    /**
     * javacall 入口：显示NetCDF文件结构
     * 调用方式：javacall NetCDFUtils printNetCDFStructureEntry, args("ncfile")
     */
    public static int printNetCDFStructureEntry(String[] args) {
        if (args.length != 1) {
            SFIToolkit.errorln("Usage: printNetCDFStructureEntry ncFilePath");
            return 198;
        }
        try {
            printNetCDFStructure(args[0]);
            return 0;
        } catch (Exception e) {
            SFIToolkit.errorln("Error in printNetCDFStructureEntry: " + e.getMessage());
            return 111;
        }
    }
    
    /**
     * javacall 入口：读取数据到Stata
     * 调用方式：javacall NetCDFUtils readToStataEntry, args("ncfile" "varname")
     */
    public static int readToStataEntry(String[] args) {
        if (args.length != 2) {
            SFIToolkit.errorln("Usage: readToStataEntry ncFilePath variableName");
            return 198;
        }
        try {
            readToStata(args[0], args[1]);
            return 0;
        } catch (Exception e) {
            SFIToolkit.errorln("Error in readToStataEntry: " + e.getMessage());
            return 111;
        }
    }
    
    /**
     * javacall 入口：按区域读取数据到Stata
     * 调用方式：javacall NetCDFUtils readToStataBySectionEntry, args("ncfile" "varname" "origin" "size")
     */
    public static int readToStataBySectionEntry(String[] args) {
        if (args.length != 4) {
            SFIToolkit.errorln("Usage: readToStataBySectionEntry ncFilePath variableName origin size");
            return 198;
        }
        try {
            readToStataBySection(args[0], args[1], args[2], args[3]);
            return 0;
        } catch (Exception e) {
            SFIToolkit.errorln("Error in readToStataBySectionEntry: " + e.getMessage());
            return 111;
        }
    }
    
    /**
     * javacall 入口：导出数据到CSV
     * 调用方式：javacall NetCDFUtils exportToCSVEntry, args("ncfile" "csvfile" "varname")
     */
    public static int exportToCSVEntry(String[] args) {
        if (args.length != 3) {
            SFIToolkit.errorln("Usage: exportToCSVEntry ncFilePath csvFilePath variableName");
            return 198;
        }
        try {
            exportToCSV(args[0], args[1], args[2]);
            return 0;
        } catch (Exception e) {
            SFIToolkit.errorln("Error in exportToCSVEntry: " + e.getMessage());
            return 111;
        }
    }
    
    /**
     * javacall 入口：按区域导出数据到CSV
     * 调用方式：javacall NetCDFUtils exportToCSVBySectionEntry, args("ncfile" "csvfile" "varname" "origin" "size")
     */
    public static int exportToCSVBySectionEntry(String[] args) {
        if (args.length != 5) {
            SFIToolkit.errorln("Usage: exportToCSVBySectionEntry ncFilePath csvFilePath variableName origin size");
            return 198;
        }
        try {
            exportToCSVBySection(args[0], args[1], args[2], args[3], args[4]);
            return 0;
        } catch (Exception e) {
            SFIToolkit.errorln("Error in exportToCSVBySectionEntry: " + e.getMessage());
            return 111;
        }
    }

    // ================= 原有核心功能方法 =================

    /**
     * 显示变量的详细结构信息
     * 对应原 NetCDFReader.printVarStructure 方法
     */
    public static void printVarStructure(String ncFileName, String variableName) {
        StringBuilder output = new StringBuilder(1024);
        try {
            // 设置系统属性以绕过SSL验证
            System.setProperty("jdk.net.URLClassPath.disableClassPathURLCheck", "true");
            
            try (NetcdfDataset netcdfDataset = NetcdfDatasets.openDataset(ncFileName)) {
                Variable variable = netcdfDataset.findVariable(variableName);
                if (variable == null) {
                    SFIToolkit.errorln("Variable " + variableName + " not found");
                    return;
                }
        
                output.append("\n=== Variable Structure ===\n");
                output.append(String.format("Name: %-25s Type: %-15s%n", 
                    variable.getShortName(), variable.getDataType()));
                
                SFIToolkit.display("\n=== Dimensions ===\n");
                SFIToolkit.display(String.format("%-15s %-8s %-15s%n", "Dimension", "Length", "Coordinate"));
                
                // 缓存维度信息避免重复方法调用
                java.util.List<Dimension> dimensions = variable.getDimensions();
                
                dimensions.forEach(dim -> 
                    SFIToolkit.display(String.format("%-15s %-8d %-15s%n",
                        dim.getShortName(),
                        dim.getLength(),
                        isCoordinateAxis(dim, netcdfDataset) ? "[Yes]" : ""))
                );
        
                // 标度参数输出
                SFIToolkit.display("\n=== Scale/Offset Parameters ===\n");
                String[] scaleAtts = {"scale_factor", "add_offset", "missing_value", "_FillValue"};
                Arrays.stream(scaleAtts).forEach(attName -> {
                    Attribute att = findAttributeRecursive(variable, attName);
                    if (att != null && att.getDataType().isNumeric()) {
                        double value = att.getNumericValue().doubleValue();
                        SFIToolkit.display(String.format("%-15s: %-12.6f (Type: %s)%n",
                            attName.replace("_", " "), 
                            value,
                            att.getDataType()));
                    }
                });
        
                SFIToolkit.display("\n=== Attributes ===\n");
                variable.attributes().forEach(attr -> {
                    String value = attr.getDataType().isString() ? 
                        attr.getStringValue() : attr.getNumericValue().toString();
                    SFIToolkit.display(String.format("%-20s: %s%n", attr.getShortName(), value));
                });
        
                SFIToolkit.display("\n=== Metadata ===\n");
                Attribute unitAtt = variable.findAttribute("units");
                if (unitAtt != null) {
                    String unit = unitAtt.getStringValue()
                        .replace("degrees_", "°")
                        .replace("meters", "m");
                    SFIToolkit.display(String.format("%-15s: %s (original: %s)%n", 
                        "Units", unit, unitAtt.getStringValue()));
                    Macro.setLocal("unit", unitAtt.getStringValue());
                }
        
                int[] shape = variable.getShape();
                SFIToolkit.display(String.format("%n%-15s: %s%n", "Shape", Arrays.toString(shape)));
                SFIToolkit.display(String.format("%-15s: %s%n", "Data Type", variable.getDataType()));
                
                Macro.setLocal("dimensions", Arrays.stream(shape)
                    .mapToObj(String::valueOf)
                    .collect(Collectors.joining(" ")));
                    
                Macro.setLocal("datatype", variable.getDataType().toString());
                
                String coordinates = variable.getDimensions().stream()
                    .filter(dim -> isCoordinateAxis(dim, netcdfDataset))
                    .map(Dimension::getShortName)
                    .collect(Collectors.joining(" "));
                Macro.setLocal("coordAxes", coordinates);
                    
                SFIToolkit.display(output.toString());
            }
        } catch (IOException e) {
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

    /**
     * 显示NetCDF文件的整体结构信息
     * 对应原 NetCDFinfo.printNetCDFStructure 方法
     */
    public static void printNetCDFStructure(String ncFileName) {
        try (NetcdfDataset netcdfDataset = NetcdfDatasets.openDataset(ncFileName)) {
            SFIToolkit.display("\n=== File Structure ===\n");
            
            SFIToolkit.display("\n[Global Attributes]\n");
            netcdfDataset.getGlobalAttributes().forEach(attr -> 
                SFIToolkit.display(String.format("%-25s: %s%n", 
                    attr.getShortName(), 
                    truncate(attr.getStringValue(), 50)))
            );

            SFIToolkit.display("\n[Dimensions]\n");
            Set<String> axisDims = netcdfDataset.getVariables().stream()
                .filter(var -> var.findAttribute("axis") != null ||
                    var.getShortName().matches("(?i)time|lat|lon"))
                .map(Variable::getShortName)
                .collect(Collectors.toSet());

            SFIToolkit.display(String.format("%-20s %-8s %-15s%n", "Name", "Length", "Attribute"));
            netcdfDataset.getRootGroup().getDimensions().forEach(dim -> 
                SFIToolkit.display(String.format("%-20s %-8d %-15s%n",
                    dim.getShortName(),
                    dim.getLength(),
                    axisDims.contains(dim.getShortName()) ? "Coordinate" : ""))
            );

            SFIToolkit.display("\n[Variables]\n");
            SFIToolkit.display(String.format("%-25s %-30s %-15s%n", "Name", "Dimensions", "Type"));
            netcdfDataset.getVariables().forEach(var -> 
                SFIToolkit.display(String.format("%-25s %-30s %-15s%n",
                    var.getShortName(),
                    var.getDimensionsString(),
                    var.getDataType()))
            );

            SFIToolkit.display("\n[Groups]\n");
            netcdfDataset.getRootGroup().getGroups().forEach(group -> {
                SFIToolkit.display(String.format("Group: %s%n", group.getShortName()));
                SFIToolkit.display(String.format("%-25s %-8s%n", "Dimensions", "Variables"));
                SFIToolkit.display(String.format("%-25s %-8s%n",
                    group.getDimensions().size(),
                    group.getVariables().size()));
            });
            
        } catch (IOException e) {
            SFIToolkit.errorln("Error: " + e.getMessage());
        }
    }

    /**
     * 读取完整的NetCDF变量数据到Stata
     * 对应原 NCtoStata.main 方法
     */
    public static void readToStata(String ncFilePath, String variableName) {
        try (NetcdfDataset ncFile = NetcdfDatasets.openDataset(ncFilePath)) {
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
            processStataData(coordVars, mainVar, totalSize, dimOrderMap);
            Data.updateModified();
        } catch (Exception e) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
        }
    }

    /**
     * 按指定区域读取NetCDF变量数据到Stata
     * 对应原 NCtoStatabySection.main 方法
     */
    public static void readToStataBySection(String ncFilePath, String variableName, String strorigin, String strsize) {
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

        try (NetcdfDataset ncFile = NetcdfDatasets.openDataset(ncFilePath)) {
            Variable mainVar = ncFile.findVariable(variableName);
            if (mainVar == null) {
                SFIToolkit.errorln("Variable " + variableName + " not found");
                return;
            }

            List<Dimension> dims = mainVar.getDimensions();
            
            // 返回维度信息到Stata
            StringBuilder dimSizes = new StringBuilder();
            StringBuilder coordAxesBuilder = new StringBuilder();
            
            for (int i = 0; i < dims.size(); i++) {
                Dimension dim = dims.get(i);
                if (i > 0) dimSizes.append(" ");
                dimSizes.append(dim.getLength());
                
                Variable coordVar = ncFile.findVariable(dim.getShortName());
                if (coordVar != null) {
                    if (coordAxesBuilder.length() > 0) coordAxesBuilder.append(" ");
                    coordAxesBuilder.append(dim.getShortName());
                }
            }
            
            Macro.setLocal("dimensions", dimSizes.toString());
            Macro.setLocal("coordAxes", coordAxesBuilder.toString());
            
            // 验证维度匹配
            if (origin.length != dims.size() || size.length != dims.size()) {
                SFIToolkit.errorln("The number of origin and count should be equal # of axes in nc file.");
                return;
            }
            
            // 验证每个维度的范围边界
            for (int i = 0; i < dims.size(); i++) {
                int dimLength = dims.get(i).getLength();
                
                if (origin[i] < 0 || origin[i] >= dimLength) {
                    SFIToolkit.errorln("Origin index " + (origin[i] + 1) + " is out of bounds for dimension " + 
                                      dims.get(i).getShortName() + " with length " + dimLength);
                    return;
                }
                
                int effectiveSize = size[i];
                if (effectiveSize == -1) {
                    effectiveSize = dimLength - origin[i];
                    size[i] = effectiveSize;
                }
                
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
                SFIToolkit.errorln("Reading Section too large");
                return;
            }

            createStataVariables(coordVars, variableName, totalSize);
            processStataSectionData(coordVars, mainVar, totalSize, origin, size, dimIndexMap);
            Data.updateModified();
        } catch (Exception e) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
        }
    }

    /**
     * 将完整的NetCDF变量数据导出为CSV文件
     * 对应原 NCtoCSV.main 方法
     */
    public static void exportToCSV(String ncFilePath, String csvFilePath, String variableName) {
        try (NetcdfDataset ncDataset = NetcdfDatasets.openDataset(ncFilePath)) {
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
            SFIToolkit.display("Total rows: " + totalSize + "\n");

            if (totalSize > MAX_SAFE_ELEMENTS) {
                SFIToolkit.errorln("Warning: Dataset too large");
                return;
            }

            try (BufferedWriter writer = new BufferedWriter(new FileWriter(csvFilePath), BUFFER_SIZE)) {
                writeCSVHeader(writer, coordVars, variableName);
                processCSVData(writer, coordVars, mainVar, totalSize, dimOrderMap);
                SFIToolkit.display("Data written to CSV: " + csvFilePath + "\n");
            }
        } catch (IOException e) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
        }
    }

    /**
     * 按指定区域将NetCDF变量数据导出为CSV文件
     * 对应原 NCtoCSVbySection.main 方法
     */
    public static void exportToCSVBySection(String ncFilePath, String csvFilePath, String variableName, String start, String count) {
        int[] origin = parseIndices(start);
        int[] size = parseIndices(count);

        try (NetcdfDataset ncFile = NetcdfDatasets.openDataset(ncFilePath)) {
            Variable mainVar = ncFile.findVariable(variableName);
            if (mainVar == null) {
                SFIToolkit.errorln("Variable " + variableName + " not found");
                return;
            }

            List<Dimension> dims = mainVar.getDimensions();
            
            // 验证维度匹配
            if (origin.length != dims.size() || size.length != dims.size()) {
                SFIToolkit.errorln("The number of origin and count should be equal # of axes in nc file.");
                return;
            }
            
            // 验证范围边界
            for (int i = 0; i < dims.size(); i++) {
                int dimLength = dims.get(i).getLength();
                
                if (origin[i] < 0 || origin[i] >= dimLength) {
                    SFIToolkit.errorln("Origin index " + (origin[i] + 1) + " is out of bounds for dimension " + 
                                      dims.get(i).getShortName() + " with length " + dimLength);
                    return;
                }
                
                int effectiveSize = size[i];
                if (effectiveSize == -1) {
                    effectiveSize = dimLength - origin[i];
                    size[i] = effectiveSize;
                }
                
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
                writeCSVHeader(writer, coordVars, variableName);
                processCSVSectionData(writer, coordVars, mainVar, origin, size, totalSize, dimIndexMap);
                SFIToolkit.display("Data written to CSV: " + csvFilePath + "\n");
            }
        } catch (Exception e) {
            SFIToolkit.errorln(SFIToolkit.stackTraceToString(e));
        }
    }

    // ================= 私有辅助方法 =================

    /**
     * 递归查找属性
     */
    private static Attribute findAttributeRecursive(Variable var, String attName) {
        Attribute att = var.findAttribute(attName);
        return att != null ? att : var.getParentGroup().getNetcdfFile().findGlobalAttribute(attName);
    }

    /**
     * 截断字符串
     */
    private static String truncate(String value, int maxLength) {
        return value.length() > maxLength ? 
            value.substring(0, maxLength-3) + "..." : value;
    }

    /**
     * 判断是否为坐标轴 - 现代化API版本
     */
    private static boolean isCoordinateAxis(Dimension dim, NetcdfDataset dataset) {
        return COORD_PATTERN.matcher(dim.getShortName()).matches()
            || dataset.findVariable(dim.getShortName()) != null;
    }

    /**
     * 计算总大小
     */
    private static long calculateTotalSize(List<Variable> coordVars) {
        long total = 1;
        for (Variable var : coordVars) total *= var.getSize();
        return total;
    }

    /**
     * 计算数组总大小
     */
    private static long calculateTotalSize(int[] size) {
        long total = 1;
        for (int s : size) total *= s;
        return total;
    }

    /**
     * 创建Stata变量
     */
    private static void createStataVariables(List<Variable> coordVars, String varName, long totalSize) {
        if (totalSize > Integer.MAX_VALUE) {
            SFIToolkit.errorln("Observation limit exceeded");
            return;
        }
        Data.setObsTotal((int) totalSize);
        for (Variable var : coordVars) Data.addVarDouble(var.getShortName());
        Data.addVarDouble(varName);
    }

    /**
     * 处理完整数据到Stata
     */
    private static void processStataData(List<Variable> coordVars, Variable mainVar, 
                                        long totalSize, Map<Variable, Integer> dimOrderMap) throws IOException {
        
        List<double[]> coordCache = new ArrayList<>();
        for (Variable var : coordVars) {
            Array data = var.read();
            coordCache.add((double[]) data.get1DJavaArray(DataType.DOUBLE));
        }

        Array mainArray = mainVar.read();
        double[] mainValues = (double[]) mainArray.get1DJavaArray(DataType.DOUBLE);

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

    /**
     * 处理区域数据到Stata
     */
    private static void processStataSectionData(List<Variable> coordVars, Variable mainVar, 
                                               long totalSize, int[] origin, int[] size,
                                               Map<Variable, Integer> dimIndexMap) throws IOException {
        try {
            // 预加载坐标数据
            List<double[]> coordCache = new ArrayList<>();
            for (Variable var : coordVars) {
                Array fullData = var.read();
                coordCache.add((double[]) fullData.get1DJavaArray(DataType.DOUBLE));
            }

            // 读取主变量切片数据
            Array mainData = mainVar.read(origin, size);
            double[] mainValues = (double[]) mainData.get1DJavaArray(DataType.DOUBLE);

            // 生成维度索引映射数组
            int[] dimIndexes = new int[coordVars.size()];
            for (int i = 0; i < coordVars.size(); i++) {
                dimIndexes[i] = dimIndexMap.get(coordVars.get(i));
            }

            // 创建索引映射
            int[][] indexMap = new int[(int) totalSize][];
            for (int i = 0; i < totalSize; i++) {
                indexMap[i] = calculateIndices(i, size);
            }

            // 数据写入缓冲区
            double[] rowBuffer = new double[coordVars.size() + 1];
            
            for (int blockStart = 0; blockStart < totalSize; blockStart += BLOCK_SIZE) {
                int blockEnd = (int) Math.min(blockStart + BLOCK_SIZE, totalSize);
                
                for (int i = blockStart; i < blockEnd; i++) {
                    int[] indices = indexMap[i];
                    int row = i + 1;

                    // 填充坐标值
                    for (int dim = 0; dim < coordVars.size(); dim++) {
                        int actualDim = dimIndexes[dim];
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

    /**
     * 写入CSV文件头
     */
    private static void writeCSVHeader(BufferedWriter writer, List<Variable> coordVars, String variableName) throws IOException {
        for (Variable coordVar : coordVars) writer.write(coordVar.getShortName() + ",");
        writer.write(variableName + "\n");
    }

    /**
     * 处理完整数据到CSV
     */
    private static void processCSVData(BufferedWriter writer, List<Variable> coordVars, 
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
            coordCache.add((double[]) var.read().get1DJavaArray(DataType.DOUBLE));

        double[] mainValues = (double[]) mainVar.read().get1DJavaArray(DataType.DOUBLE);

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

    /**
     * 处理区域数据到CSV
     */
    private static void processCSVSectionData(BufferedWriter writer, List<Variable> coordVars, Variable mainVar,
                                             int[] origin, int[] size, long totalSize, Map<Variable, Integer> dimIndexMap)
        throws IOException, InvalidRangeException {
        
        // 预加载坐标数据
        List<double[]> coordCache = new ArrayList<>();
        for (Variable var : coordVars) {
            Array fullData = var.read();
            coordCache.add((double[]) fullData.get1DJavaArray(DataType.DOUBLE));
        }

        // 主变量切片读取
        Array mainData = mainVar.read(origin, size);
        double[] mainValues = (double[]) mainData.get1DJavaArray(DataType.DOUBLE);

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

    /**
     * 解析索引字符串
     */
    private static int[] parseIndices(String str) {
        String[] parts = str.split(" ");
        int[] indices = new int[parts.length];
        for (int i = 0; i < parts.length; i++) {
            indices[i] = Integer.parseInt(parts[i]);
        }
        return indices;
    }

    /**
     * 计算多维索引
     */
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