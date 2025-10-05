
cap program drop matchgeop
cap which distinct
if _rc{
    ssc install distinct 
}

program define matchgeop
version 18

syntax varlist(min=3 max=3) using/, Neighbors(string) [Within(numlist >0 min=1 max=1) USERange(string) MILE NEARcount(numlist) gen(name) nsplit(numlist >0 min=1 max=1) UFrame BEARing(name)]

if "`mile'"!=""{
    scalar mile = 3959
    local vlabel "distance: miles"
}
else{
    scalar mile = 6371
    local vlabel "distance: kilomters"
}
if `"`gen'"'!="" confirm new var `gen'
if `"`bearinng'"'!="" confirm new var `bearing'
if "`nearcount'"=="" local nearcount 0
if "`within'"=="" local within = 0
local mid: word 1 of `varlist'
local latname: word 2 of `varlist'
local lonname: word 3 of `varlist'
sum `latname', meanonly
if (r(max) > 90 | r(min) < -90) {
    dis as err "`loctype' latitude var `latname' must be between -90 and 90"
    exit 198
}
sum `lonname', meanonly
if (r(max) > 180 | r(min) < -180) {
    dis as err "`loctype' longitude var `lonname' must be between -180 and 180"
    exit 198
}

local uid: word 1 of `neighbors'
local latname: word 2 of `neighbors'
local lonname: word 3 of `neighbors'
if ("`mid'"=="`uid'"){
	di as error "id varname in master and using data should not be the same"
	exit 198
}
if "`nsplit'"=="" local nsplit =_N //loop over all the data if not specified
qui distinct `mid'
local N = _N
local ndistinct = r(ndistinct)
if (`N'!=`ndistinct') {
    di as err `"`mid' do not uniquely identify observations in the master data"'
    exit
}
if `"`gen'"'=="" local gen  _Distance 
tempname masterdata usingdata
tempvar mid10
qui egen `mid10' = group(`mid')

qui pwf 
local currentframe = r(currentframe)

frame copy `currentframe' `masterdata'


tempname uid2 latlon2

if ("`uframe'"!="") {
    qui frame copy `using' `usingdata',replace 
    cwf `usingdata'
    confirm variable `neighbors'
}
else{
    frame create `usingdata'
    cwf `usingdata'
    qui use `"`using'"'
    confirm variable `neighbors'
}

sum `latname', meanonly
if (r(max) > 90 | r(min) < -90) {
    dis as err "`loctype' latitude var `latname' must be between -90 and 90"
    local rc1 = 198 
    // exit 198
}
sum `lonname', meanonly
if (r(max) > 180 | r(min) < -180) {
    dis as err "`loctype' longitude var `lonname' must be between -180 and 180"
    local rc1 = 198 
    //exit 198
}

if "`rc1'" == "198" {
    qui cwf `currentframe'
    if "`uframe'"=="" {
       cap frame drop `usingdata'
    }
    exit 198
}


//ds
qui keep `neighbors'
qui `userange'
qui duplicates drop `uid', force 
gettoken iidd neighbors: neighbors

tempvar uid20 
qui egen `uid20' = group(`uid')
qui putmata `uid2' = `uid20' `latlon2' = (`neighbors'),replace
//list in 1/10

cwf `masterdata'
qui keep `varlist' `mid10'
tempvar group  
qui gen int `group' = mod(_n,`nsplit') // loop over groups, reducing # of loops, for small data, set nsplit = 1

// tempvar in mata 
tempname mid1 latlon1 g dist

gettoken mid varlist: varlist

// put data into mata 
qui putmata `mid1' = `mid10' `latlon1' = (`varlist') `g' = `group',replace

// calculate distance in mata, return pairs within the distance
if "`bearing'"==""{
    mata: matchdis(`mid1',`uid2',`latlon1',`latlon2',`g',`within',`dist'=.)
}
else{
    mata: matchdis(`mid1',`uid2',`latlon1',`latlon2',`g',`within',`dist'=.,bearing=.)
}


clear 
// get results from mata
//mata: cols(`dist')
qui getmata (`mid10' `uid20' `gen' `bearing') = `dist' 

//keep only the nearest # neighbors
if `nearcount' > 0 {
    qui bysort `mid10' (`gen'): gen nearcount = _n 
    qui drop if nearcount > `nearcount'
}


qui frlink m:1 `mid10', frame(`currentframe')
qui frget `mid', from(`currentframe')
qui frlink m:1 `uid20', frame(`usingdata')
qui frget `uid', from(`usingdata')
keep `mid' `uid' `gen' `bearing'
label var `gen' "`vlabel'"
if "`bearing'"!="" label var `bearing' "bearing: degrees"

tempfile matchedlink

qui save `matchedlink',replace

cwf `currentframe'
qui merge 1:m `mid' using `matchedlink', nogen

cap mata mata drop `mid1' `latlon1' `g' `dist' `uid2' `latlon2' 
cap drop `mid10' `uid20' 
cap frame drop `usingdata' `masterdata'
 
end

mata:  mata set matastrict off
cap mata mata drop matchdis()
cap mata mata drop matchdis0()
cap mata mata drop calculate_distance()
cap mata mata drop repmat()
cap mata mata drop min2()

mata:
void function matchdis(real colvector mid,
                       real colvector uid,
                       real matrix latlon1,
                       real matrix latlon2,
                       real colvector group,
                       real scalar within,
                       real matrix dist,
                       | real scalar bearing)
{
    
    id = uniqrows(group)
    if (args()>7) dist = J(0,4,.)
    else dist = J(0,3,.)
    for(i=1;i<=length(id);i++){ // loop over groups
        midi = select(mid,group:==id[i])
        latlon1i = select(latlon1,group:==id[i])
        if (args()>7){
            disti = matchdis0(midi,uid,latlon1i,latlon2,within,bearing)
        }
        else{
            disti = matchdis0(midi,uid,latlon1i,latlon2,within)
        }
		//rows(disti)
        if(length(disti)>0){
            dist = dist \ disti
        }
    }

}


real matrix matchdis0(real colvector mid,
                        real colvector uid,
                        real matrix latlon1,
                        real matrix latlon2,
                        real scalar within,
                        | real scalar bear)
{
   
    lng1 = latlon1[,2]
    lng2 = latlon2[,2]
    lat1 = latlon1[,1]
    lat2 = latlon2[,1]
    if (args()>5){
        
        distance = calculate_distance(lat1, lng1, lat2, lng2,bearing=.)
        dist = repmat(mid,length(uid),1),repmat(uid,length(mid),1,1),distance,bearing
    }
    else{
        distance = calculate_distance(lat1, lng1, lat2, lng2)
        dist = repmat(mid,length(uid),1),repmat(uid,length(mid),1,1),distance
    }
	//rows(distance)
	if(within>0){
		dist = select(dist,distance:<=within)
	}
    
	return(dist)
}

real matrix repmat(real matrix x, real scalar rows, real scalar cols,| real scalar byeach)
{
    if (args()<4) byeach = 0
    if (byeach==0){ // repeat the whole x 
        z = J(rows,cols,1)#x
    }
    else{ // repeat each elements of x 
        z = x#J(rows,cols,1)
    }
    
    return(z)
}

real matrix calculate_distance(real colvector lat1, 
                               real colvector lon1, 
                               real colvector lat2, 
                               real colvector lon2,
                              | real colvector bearing)
{
    ra = st_numscalar("mile")
    d2r = pi()/180
    lon11 = repmat(lon1,1,length(lon2)) 
    lon21 = repmat(lon2',length(lon1),1)
    lat11 = repmat(lat1,1,length(lat2)) 
    lat21 = repmat(lat2',length(lat1),1)
    distance = 2 * asin(min2(1, sqrt( ///
        sin((lat21 - lat11) * d2r / 2):^2 + ///
        cos(lat11 * d2r):* cos(lat21 * d2r):* ///
        sin((lon21 - lon11) * d2r / 2):^2))) * ra
		//length(vec(distance))
    //计算方位角
    if (args()>4){
        x = sin(lon21*d2r - lon11*d2r):* cos(lat21*d2r)
        y = cos(lat11*d2r) :* sin(lat21*d2r) - sin(lat11*d2r) :* cos(lat21*d2r) :* cos(lon21*d2r - lon11*d2r)
        bearing = atan2(y,x)/d2r 
        //rows(y),cols(y),rows(x),cols(x)
        bearing = vec(bearing:*(bearing:>=0) + (bearing:+360):*(bearing:<0))
    }
    return(vec(distance))
}

real matrix function min2(real scalar x, real matrix y)
{
	z = x:*(y:>=x)+y:*(y:<=x)
	return(z)
}
end


