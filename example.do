* 2025-10-06
********Example of Using readraster Package************
cap findfile readraster.sthlp
    if _rc {
    display "change the working directory to the folder where readraster package is located"
    exit
    }

cap findfile DMSP-like2020.tif
if _rc {
   display "change the working directory to the folder where readraster package is located"
   exit
}
************Set up for Readraster************

cap findfile gt-main-32.0.jar
if _rc {
   display "using setup.do to install Java dependencies"
   display "downloading the Java dependencies requires dozen minutes and might fail due to network issues"
   display `"if it fails, please try again, or download the Java dependencies manually as instructed in georools_init (see {view "geotools_init.sthlp":help geotools_init})"'
   do setup.do
}

cap which geoplot
if _rc {
   ssc install geoplot, replace
}
cap which moremata
if _rc {
    ssc install moremata, replace
}
cap which heatplot
if _rc {
    ssc install heatplot, replace
}
cap which palettes
if _rc {
    ssc install palettes, replace
}
cap which colrspace
if _rc {
    ssc install colrspace, replace
}

cap which sjlog
if _rc {
    net install sjlatex, from(http://www.stata-journal.com/production) replace
}

**********************************************************

capture log close
log using example.log, replace


************5.1 Display the Metadata************

//Display the Metadata of the GeoTIFF File
gtiffdisp DMSP-like2020.tif

//Display the Metadata of the NetCDF File
////The developed commands can directly read nc files on the network. However, due to reasons such as network SSL authentication, the reading may fail. If this happens, you can copy the nc file to the local device and then perform the following corresponding operations.
local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/" + ///
            "NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/" + ///
            "tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"
ncdisp using `"`url'"'

//Display variable metadata with ncdisp
///tas variable
local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/" + ///
            "NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/" + ///
            "tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"
ncdisp tas using `"`url'"'

///time variable
local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/" + ///
            "NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/" + ///
            "tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"
ncdisp time using `"`url'"'



************5.2 Import Raster Data into Stata************

//Read the GeoTIFF file for a specific region
spshape2dta hunan.shp, replace 
use "hunan.dta",clear
crsconvert _CX _CY, gen(alber) from(hunan.shp) to(DMSP-like2020.tif)

qui sum alber_CX
local maxX = r(max)+2000
local minX = r(min)-2000

qui sum alber_CY
local maxY = r(max)+2000
local minY = r(min)-2000

gtiffread DMSP-like2020.tif, origin(1 1) size(-1 1) clear 
gen n=_n
sum n if y>`minY' & y<`maxY'
local start_row = r(min)
local n_rows = r(N)

gtiffread DMSP-like2020.tif, origin(1 1) size(1 -1) clear 
gen n=_n
sum n if x>`minX' & x<`maxX'
local start_col = r(min)
local n_cols = r(N)

gtiffread DMSP-like2020.tif, origin(`start_row' `start_col') size(`n_rows' `n_cols') clear

save DMSP-like2020.dta,replace


set scheme sj, permanently
use DMSP-like2020.dta, clear
heatplot value y x, color(Greys, reverse) level(6) xlabel(, angle(45)) 

graph save gragh1, replace

//Read the NetCDF file
local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/" + ///
            "NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/" + ///
            "tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"

// If reading nc files is too slow, you can opt to read local files instead.
// local url = "tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"

ncread lon using `"`url'"', clear 
gen n=_n 
qui sum n if lon>=108 & lon<=115
local lon_start = r(min)
local lon_count = r(N)

ncread lat using `"`url'"', clear 
gen n=_n 
qui sum n if lat>=24 & lat<=31
local lat_start = r(min)
local lat_count = r(N)

ncread tas using `"`url'"', clear origin(1 `lat_start' `lon_start') ///
 size(-1 `lat_count' `lon_count')
 
gen date = time - 3650.5  + date("2050-01-01", "YMD")
format date %td

list in 1/10

save "grid_all.dta", replace

********5.3 Calculating Average and Total Nighttime Light Intensity for hunan********
gzonalstats DMSP-like2020.tif using hunan.shp, stats("sum avg") clear
list z_Name avg sum
save "hunan_light.dta", replace


use hunan.dta, clear

rename Name z_Name  
merge 1:1 z_Name using hunan_light.dta,nogen
save hunan_light.dta, replace

geoframe create region ///
 "hunan_light.dta", id(_ID) centroids(_CX _CY) ///
 shp(hunan_shp.dta) ///
 replace

geoplot ///
 (area region avg, color(Greys, reverse) ///
	level(6, quantile weight(avg))) ///
 (line region, lwidth(vthin)), ///
 legend(position(sw)) ///
 title("Average Nighttime Light Intensity")
 
graph save avg, replace

geoplot ///
 (area region sum, color(Greys, reverse) ///
	level(6, quantile weight(sum))) ///
 (line region, lwidth(vthin)), ///
 legend(position(sw)) ///
 title("Total Nighttime Light Intensity")

graph save sum, replace

graph combine avg.gph sum.gph

graph save gragh2, replace


********5.4 Match cities to nearest four grid cells using matchgeop********
use "grid_all.dta", clear

rename lon ulon
rename lat ulat
save "grid_all_1.dta", replace

keep if time==3650.5
gen n=_n 
save "hunan_grid.dta", replace

use "hunan_city.dta", clear
matchgeop ORIG_FID lat lon using hunan_grid.dta, neighbors(n ulat ulon) nearcount(4) gen(distance) bearing(angle)

merge m:1 n using hunan_grid.dta, keep(3)
drop _merge
save "hunan_origin.dta", replace

drop time date
joinby ulat ulon using grid_all_1.dta

sort ORIG_FID date 
list city distance angle date tas in 1/10

///Diagram of azimuthal angle
use "hunan_origin.dta", clear
keep if city == "Changsha"

sort angle
gen id=_n

local R = 6371 
gen lat_rad = lat * (_pi/180)  

gen delta_lat = (distance / `R') * (180/_pi)  
gen delta_lon = (distance / (`R' * cos(lat_rad))) * (180/_pi)  

expand 90
bysort n: gen t = _n - 1
gen theta = (angle * t/89) * (_pi/180)  

gen arc_lat = lat + delta_lat * cos(theta)
gen arc_lon = lon + delta_lon * sin(theta)

bysort n: gen label_theta = (angle/2) * (_pi/180)
gen label_lat = lat + delta_lat * cos(label_theta)
gen label_lon = lon + delta_lon * sin(label_theta)
replace label_lat = lat + delta_lat * 0.7 * cos(label_theta) if id == 3
replace label_lon = lon + delta_lon * 0.7 * sin(label_theta) if id == 3

gen latlon_label = "(" + string(lat, "%8.2f") + "°N, " + string(lon, "%8.2f") + "°E)"
gen ulatlon_label = "(" + string(ulat, "%8.2f") + "°N, " + string(ulon, "%8.2f") + "°E)"
gen angle_label = string(angle, "%8.2f") + "{&degree}"

twoway pcarrowi 28.15 113.15307 28.52 113.15307 ///
    || pcarrow lat lon ulat ulon ///
    || scatter lat lon if t == 1, msymbol(triangle) mlabel(latlon_label) mcolor(black) mlabcolor(black) mlabpos(9) mlabgap(0.8) mlabsize(small) ///
    || scatter ulat ulon if t == 1 & (ulat == 28.125), msymbol(circle)  mlabel(ulatlon_label) mlabcolor(black) mlabpos(6) mlabgap(0.8) mlabsize(small) ///
    || scatter ulat ulon if t == 1 & (ulat == 28.375), msymbol(circle) mlabel(ulatlon_label) mlabcolor(black) mlabpos(12) mlabgap(0.8) mlabsize(small) ///
    || line arc_lat arc_lon if id == 1, lpattern(dot)  ///
    || line arc_lat arc_lon if id == 2, lpattern(dot) ///
    || line arc_lat arc_lon if id == 3, lpattern(dot) ///
    || line arc_lat arc_lon if id == 4, lpattern(dot) ///
    || scatter label_lat label_lon, mlabel(angle_label) msymbol(i) mlabcolor(black) mlabsize(small) ///
    xscale(off noline) yscale(off noline) xlabel(, nogrid noticks) ylabel(, nogrid noticks) ///
    aspect(1) legend(off)

graph save gragh3, replace
	
	
********5.5 Calculate 80km-radius IDW temperatures for cities********
use "grid_all.dta", clear
rename lon ulon
rename lat ulat
gen n=_n
save "grid_all_2.dta", replace

use "hunan_city.dta", clear
matchgeop ORIG_FID lat lon using grid_all_2.dta, neighbors(n ulat ulon) within(80) gen(distance)

merge m:1 n using grid_all_2.dta, keep(3)
drop _merge

list city ulat ulon distance date tas in 1/10

save "hunan_80km.dta", replace

drop if tas==.
gen weight  = 1/distance
gen weighted_tas = tas * weight
bysort city date : egen sum_weighted_tas = total(weighted_tas)
bysort city date : egen total_weight = total(weight)
gen idw_tas = sum_weighted_tas / total_weight
gen temp_c = idw_tas - 273.15

duplicates drop city date , force

list city  distance date  temp_c in 1/10

save "hunan_IDW.dta", replace

///IDW interpolated temperature distributions in Hunan
use "hunan_IDW.dta" ,clear
rename city Name
merge m:1 Name using hunan.dta
local dates "01jan2050 01jul2050"
local suffixes "202500101 202500701"

local i = 1
foreach d of local dates {
    local s : word `i' of `suffixes'
    preserve
    keep if date == date("`d'", "DMY")
    save hunan_IDW_`s'.dta, replace

    geoframe create region ///
     "hunan_IDW_`s'.dta", id(_ID) centroids(_CX _CY) ///
     shp(hunan_shp.dta) ///
     replace

    geoplot ///
     (area region temp_c , color(Greys) ///
        level(6, quantile weight(temp_c))) ///
     (line region, lwidth(vthin)), ///
     legend(position(sw)) ///
     title("Temperature(`s')")

    restore

    graph save Temperature(`s'), replace

    local ++i
}

graph combine Temperature(202500101).gph Temperature(202500701).gph
graph save gragh4, replace
log close
