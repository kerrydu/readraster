Title:  Reading and processing geographical raster data in Stata

```
* install within Stata
net install readraster, from(https://raw.githubusercontent.com/kerrydu/readraster/refs/heads/main/)
```


See [manuscript.pdf](https://github.com/kerrydu/readraster/blob/main/readraster-manuscript.pdf) for details

Author 1 name: Kerry Du
Author 1 from:  School of Managemnet, Xiamen University, Xiamen, China
Author 1 email: kerrydu@xmu.edu.cn

Author 2 name: Chunxia Chen
Author 2 from:  School of Managemnet, Xiamen University, Xiamen, China
Author 2 email: chenchunxia@stu.xmu.edu.cn

Author 3 name: Shuo Hu
Author 3 from: School of Economics, Southwestern University of Finance and Economics, China
Author 3 email: advancehs@163.com

Author 4 name: Yang Song
Author 4 from:  School of Economics, Hefei University of Technology, Hefei, China
Author 4 email: ss0706082021@163.com

Author 5 name: Ruipeng Tan
Author 5 from:  School of Economics, Hefei University of Technology, Hefei, China
Author 5 email: tanruipeng@hfut.edu.cn

Help keywords:  GeoTIFF, NetCDF, Java, Raster, Geospatial

File list: geotools_init.ado geotools_init.sthlp  gtiffdisp.ado gtiffdisp.sthlp gtiffdisp_core.ado gtiffread.ado gtiffread_core.ado gtiffread.sthlp gzonalstats.ado gzonalstats.sthlp gzonalstats_core.ado crsconvert.ado crsconvert.sthlp crsconvert_core.ado ncread.ado ncread_core.ado ncread.sthlp ncreadbysec.ado ncreadtocsv.ado ncreadtocsvbysec.ado ncdisp.ado ncdisp.sthlp ncdisp_core.ado ncinfo.ado matchgeop.ado matchgeop.sthlp netcdf_init.ado netcdf_init.sthlp DMSP-like2020.tif geotools-32.0 hunan.dbf hunan.shp hunan.shx hunan.prj hunan_city.dta example.do

Notes: Given the large size of the GeoTools package, the download process can be time-consuming. To save time, we recommend that users manually download the GeoTools package from Sourceforge {https://sourceforge.net/projects/geotools/files/GeoTools\%2032\%20Releases/32.0/}. Then, use the \stcmd{geotools\_init} command to specify the path to "geotools-32.0/lib".The developed commands can directly read nc files on the network. However, due to reasons such as network SSL authentication, the reading may fail. If this happens, you can copy the nc file to the local device and then perform the following corresponding operations.
