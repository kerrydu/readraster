capture log close
log using example.log, replace

*7.1 Set up the Java dependence

//tiff

//manually download the GeoTools package from Sourceforge https://sourceforge.net/projects/geotools/files/GeoTools\%2032\%20Releases/32.0/ and specify the path to "geotools-32.0/lib" 

geotools_init "C:/Users/17286/Documents/geotools-32.0/lib/"

//nc

netcdf_init, download plus(jar)
capture log close
log using example.log, replace

*7.2 Display the Metadata

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


*7.3 Import Raster Data into Stata
//Read the GeoTIFF file for a specific region
shp2dta using "hunan.shp", database(hunan_db) coordinates(hunan_coord) genid(id)
use "hunan_coord.dta",clear
drop if missing(_X, _Y)
crsconvert _X _Y, gen(alber_) from(hunan.shp) to(DMSP-like2020.tif)

qui sum alber__X
local maxX = r(max)+2000
local minX = r(min)-2000

qui sum alber__Y
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

//heatplot
ssc install heatplot, replace
ssc install palettes, replace
ssc install colrspace, replace

use DMSP-like2020.dta, clear

heatplot value y x, color(plasma) ///
    keylabels(, format(%4.2f))
	
graph save gragh1, replace

//Read the NetCDF file
local url = "https://nex-gddp-cmip6.s3-us-west-2.amazonaws.com/" + ///
"NEX-GDDP-CMIP6/BCC-CSM2-MR/ssp245/r1i1p1f1/tas/" + ///
"tas_day_BCC-CSM2-MR_ssp245_r1i1p1f1_gn_2050.nc"

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


*7.4 Calculating Average and Total Nighttime Light Intensity for Hunan
gzonalstats DMSP-like2020.tif using hunan.shp, stats("sum avg") clear
list z_Name avg sum
save "hunan_light.dta", replace

//presents TNLI and ANLI in Hunan

// The hunan.shp has been converted to a dta in example 7.3.
//shp2dta using "hunan.shp", database(hunan_db) coordinates(hunan_coord) genid(id)

use "hunan_light.dta" ,clear
rename z_Name Name
merge 1:1 Name using hunan_db.dta,nogen

spmap sum using "hunan_coord.dta", id(id) clmethod(q) cln(6) fcolor(Heat) title("Total Night Light Index")
graph save graph1, replace

spmap avg using "hunan_coord.dta", id(id) clmethod(q) cln(6) fcolor(Heat) title("Average Night Light Index")  
graph save graph2, replace

graph combine graph1.gph graph2.gph

graph save gragh2, replace


*7.5 Match cities to nearest four grid cells using matchgeop
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

twoway pcarrowi 28.15 113.15307 28.52 113.15307, color(black) ///
    || pcarrow lat lon ulat ulon, color(blue) ///
    || scatter lat lon if t == 1, mcolor(red) mlabel(latlon_label) mlabcolor(black) mlabpos(9) mlabgap(0.8) mlabsize(medium) ///
    || scatter ulat ulon if t == 1 & (ulon == 113.125), mcolor(red) mlabel(ulatlon_label) mlabcolor(black) mlabpos(9) mlabgap(0.8) mlabsize(medium) ///
    || scatter ulat ulon if t == 1 & (ulon == 113.375), mcolor(red) mlabel(ulatlon_label) mlabcolor(black) mlabpos(3) mlabgap(0.8) mlabsize(medium) ///
    || line arc_lat arc_lon if id == 1 , lcolor(green) ///
    || line arc_lat arc_lon if id == 2, lcolor(green) ///
    || line arc_lat arc_lon if id == 3, lcolor(green) ///
    || line arc_lat arc_lon if id == 4, lcolor(green) ///
    || scatter label_lat label_lon, mlabel(angle_label) msymbol(i) mlabcolor(black) mlabsize(medium) ///
    xscale(off noline) yscale(off noline) xlabel(, nogrid noticks) ylabel(, nogrid noticks) ///
    aspect(1) legend(off)

graph save gragh3, replace
	
* 7.6 Calculate 80km-radius IDW temperatures for cities
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

///Distribution of raster points within 80 kilometers of Changsha City
use "hunan_80km.dta" ,clear
keep if time == 3650.5
keep if city == "Changsha"

summarize lon 
local clon = r(mean)
summarize lat 
local clat = r(mean)

preserve
clear
set obs 720
gen theta = (_n-1) * 2 * _pi/720 

local R = 6371  
local d = 80    
local delta = `d'/`R'  

gen lat_c = asin(sin(`clat'*_pi/180)*cos(`delta') + ///
             cos(`clat'*_pi/180)*sin(`delta')*cos(theta)) * (180/_pi)
             
gen lon_c = `clon' + ///
            atan2(sin(theta)*sin(`delta')*cos(`clat'*_pi/180), ///
                  cos(`delta') - sin(`clat'*_pi/180)*sin(lat_c*_pi/180)) * (180/_pi)
				  
expand 2 if _n == _N
replace theta = 0 if _n == _N

save circle.dta ,replace
restore

merge 1:1 _n using circle.dta, nogen

twoway (line lat_c lon_c, sort lcolor(dimgray) lwidth(0.6) lpattern(solid)) ///
    (pcarrowi  28.22691 113.1531 28.22691 113.9696, color(black)) ///
	(scatter lat lon, mcolor(red) msymbol(D) msize(small)) ///
    (scatter ulat ulon, mcolor(blue) msymbol(O) msize(small)), ///
    xlabel(minmax) ylabel(minmax) ///
	aspect(1)  legend(off) ///
    xscale(off noline) yscale(off noline) xlabel(, nogrid noticks) ylabel(, nogrid noticks) ///
	text(28.26 113.71 "80km", size(medsmall) justification(center))

graph save gragh4, replace

///IDW interpolated temperature distributions in Hunan
// The hunan.shp has been converted to a dta in example 7.3.
// shp2dta using "hunan.shp", database(hunan_db) coordinates(hunan_coord) genid(id)
//January 1

use "hunan_IDW.dta" ,clear
keep if date == date("01jan2050", "DMY")

spmap temp_c using "hunan_coord.dta", id(OBJECTID) clmethod(q) cln(6) fcolor(Heat) legtitle("Temperature (°C)") title("Temperature(20500101)") subtitle("Within 80km Radius")  
graph save graph1, replace

//July 1
use "hunan_IDW.dta" ,clear
keep if date == date("01jul2050", "DMY")

spmap temp_c using "hunan_coord.dta", id(OBJECTID) clmethod(q) cln(6) fcolor(Heat) legtitle("Temperature (°C)") title("Temperature(20500701)") subtitle("Within 80km Radius")  
graph save graph2, replace

graph combine graph1.gph graph2.gph

graph save gragh5, replace

log close



