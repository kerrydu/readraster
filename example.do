* 2025-10-06
cap which sjlog
if _rc {
    net install sjlatex, from(http://www.stata-journal.com/production) replace
}

capture log close
sjlog using example, replace

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
cap which lmoremata.mlib
if _rc {
    ssc install moremata, replace
}
cap which heatplot
if _rc {
    ssc install heatplot, replace
	cap ssc install colrspace
}
cap which palettes.hlp
if _rc {
    ssc install palettes, replace
}



set scheme sj, permanently

**********************************************************
* downloading nc file
cap findfile tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc

if _rc{
	local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/" + ///
				"NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/" + ///
				"tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"
				
	copy `"`url'"' .
}
**************************Example of GeoTIFF********************************
************5.1 Display the Metadata************

//Display the Metadata of the GeoTIFF File
gtiffdisp DMSP-like2020.tif

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

gtiffread DMSP-like2020.tif, origin(`start_row' `start_col') ///
                             size(`n_rows' `n_cols') clear

save DMSP-like2020.dta,replace

// heatplot
use DMSP-like2020.dta, clear
heatplot value y x, color(Greys, reverse) level(6) ///
                xlabel(, angle(45)) graphr(c(white))

graph save gragh1, replace


********5.3 Calculating Average Nighttime Light Intensity for hunan********
zonalstats DMSP-like2020.tif using hunan.shp, stats("avg") clear
list z_Name avg
save "hunan_light.dta", replace

use hunan.dta, clear

rename Name z_Name  
merge 1:1 z_Name using hunan_light.dta,nogen
save hunan_light.dta, replace

geoframe create region     ///
         "hunan_light.dta", id(_ID) centroids(_CX _CY) ///
          shp(hunan_shp.dta) replace

geoplot ///
    (area region avg, color(Greys, reverse) ///
	        level(6, quantile weight(avg))) ///
    (line region, lwidth(vthin)), legend(position(sw))
 
graph save gragh2, replace

********5.4 Calculate 80km-radius IDW light for cities********

use "DMSP-like2020.dta", clear
crsconvert x y, gen(wsg84_) from(DMSP-like2020.tif) to(hunan.shp)
gen n=_n
save "light_china.dta", replace

use "hunan_city.dta", clear
matchgeop ORIG_FID lat lon using light_china.dta, ///
               neighbors(n wsg84_y wsg84_x) within(80) gen(distance)

merge m:1 n using light_china.dta, keep(3)
drop _merge

drop if value==.
gen weight  = 1/distance
gen weighted_light = value * weight
bysort city: egen sum_weighted_light = total(weighted_light)
bysort city: egen total_weight = total(weight)
gen idw_light = sum_weighted_light / total_weight

duplicates drop city, force

///IDW interpolated light distributions in Hunan
rename city Name
merge m:1 Name using hunan.dta

save "hunan_light.dta", replace

geoframe create region ///
   "hunan_light.dta", id(_ID) centroids(_CX _CY) ///
    shp(hunan_shp.dta) replace

geoplot ///
  (area region idw_light , color(Greys, reverse) ///
          level(6, quantile weight(idw_light))) ///
  (line region, lwidth(vthin)), legend(position(sw))

graph save gragh3, replace

**************************Example of NetCDF********************************

************6.1 Display the Metadata************

//Display the Metadata of the NetCDF File
ncdisp using tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc

//Display variable metadata with ncdisp
///tas variable
ncdisp tas using tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc

///time variable
ncdisp time using tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc

************6.2 Import Raster Data into Stata************

//Read the NetCDF file

ncread lon using tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc, clear 
gen n=_n 
qui sum n if lon>=108 & lon<=115
local lon_start = r(min)
local lon_count = r(N)

ncread lat using tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc, clear 
gen n=_n 
qui sum n if lat>=24 & lat<=31
local lat_start = r(min)
local lat_count = r(N)

ncread tas using tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc, ///
                        clear origin(1 `lat_start' `lon_start') ///
                        size(-1 `lat_count' `lon_count')

gen date = time - 3650.5  + date("2050-01-01", "YMD")
format date %td

list in 1/10

save "grid_all.dta", replace

********6.3 Calculating Average temperature for hunan********

zonalstats tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc using "hunan.shp", ///
                      var(tas) stats(avg) origin(1 `lat_start' `lon_start') ///
		              size(1 `lat_count' `lon_count') crs(EPSG:4326) clear
replace avg = avg - 273.15
save "hunan_temp.dta", replace

use hunan.dta, clear

rename Name z_Name  
merge 1:1 z_Name using hunan_temp.dta,nogen
save hunan_temp.dta, replace

geoframe create region ///
   "hunan_temp.dta", id(_ID) centroids(_CX _CY) ///
    shp(hunan_shp.dta) replace

geoplot ///
 (area region avg, color(Greys) ///
	           level(6, quantile weight(avg))) ///
 (line region, lwidth(vthin)), legend(position(sw))

graph save gragh4, replace

********6.4 Calculate 80km-radius IDW average temperatures for cities********
use "grid_all.dta", clear
rename lon ulon
rename lat ulat
gen n=_n
save "grid_all_2.dta", replace

use "hunan_city.dta", clear
matchgeop ORIG_FID lat lon using grid_all_2.dta, ///
                     neighbors(n ulat ulon) within(80) gen(distance)

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

keep if date == date("01jan2050", "DMY")
save hunan_IDW_202500101.dta, replace

geoframe create region ///
    "hunan_IDW_202500101.dta", id(_ID) centroids(_CX _CY) ///
    shp(hunan_shp.dta) ///
    replace

geoplot ///
    (area region temp_c , color(Greys) ///
                level(6, quantile weight(temp_c))) ///
    (line region, lwidth(vthin)), legend(position(sw))

graph save gragh5, replace
sjlog close

