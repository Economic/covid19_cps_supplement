set more off
clear all

* list of months of supplement data
local monthlist may jun jul aug sep oct

* download the CPS COVID supplement data - you only need to do this once
/*
foreach month in `monthlist' {
    copy "https://www2.census.gov/programs-surveys/cps/datasets/2020/covid/`month'20pubcovid.zip" `month'20pubcovid.zip, replace
}
*/

* convert the raw data to stata format
foreach month in `monthlist' {
    tempfile dat
    !unzip -p `month'20pubcovid.zip > `dat'
    clear
    infile using covid19_cps_supplement.dct, using(`dat')
    tempfile month`month'
    save `month`month''
}
* append it all together 
clear 
foreach month in `monthlist' {
    append using `month`month''
}
* rename/recode variables to merge with EPI extracts
rename qstnum hhid
rename occurnum personid
destring hhid personid, replace 
rename hrmonth month
rename hryear year 
replace year = 2000 + year
tempfile cps_supplement
save `cps_supplement'

load_epiextracts, begin(2020m5) end(2020m10) sample(basic)
merge 1:1 year month hhid personid using `cps_supplement'
* drop non-interview obs in supplement that are not in EPI CPS Basic
drop if _merge == 1
* confirm everything else merged successfully 
assert _merge == 3
drop _merge

* employer closed due to covid
keep if age >= 16 & basicwgt > 0 & basicwgt != .
gen byte telework = ptcovid1 == 1 if emp == 1
gen byte emp_reduced = ptcovid2 == 1  
gen byte furlough_pay = ptcovid3 == 1 if ptcovid2 == 1
collapse (mean) telework emp_reduced furlough_pay [aw=basicwgt], by(wbho)

local mycolor1 68 1 84
local mycolor2 62 74 137
local mycolor3 49 104 142
local mycolor4 31 158 137


foreach depvar in telework emp_reduced {
    local teleworklabel "Telework b/c pandemic, if employed"
    local emp_reducedlabel "Employer closed/lost business b/c pandemic"
    preserve 
    gen pct = `depvar'
    replace pct = pct * 100 
    gen spct = string(pct, "%3.1f") + "%"

    local graphcmd ""
    forvalues i = 1/4 {
        if `i' == 4 local endchar ""
        else local endchar "||"
        local graphcmd `graphcmd' scatter pct wbho if wbho == `i', msymbol(none) mlabel(spct) mlabpos(6) mlabcolor("`mycolor`i''") || bar pct wbho if wbho == `i', color("`mycolor`i''") barw(0.7) `endchar'
    }

    twoway `graphcmd' ///
        ylabel(0 " 0%" 10 "10%" 20 "20%" 30 "30%" 40 "40%", angle(0) gmin gmax) ///
        xlabel(, valuelabel) ///
        ytitle("") xtitle("", size(medsmall)) ///
        legend(off) ///
        title("``depvar'label'", size(medium) color(black) bexpand justification(left)) ///
        /* subtitle("", size(medsmall) bexpand justification(left) margin(b=3))*/ ///
        note("EPI CPS Microdata extracts and supplemental COVID questions", size(small) margin(t=2)) ///
        ysize(4) xsize(3.5) ///
        graphregion(color(white) margin(t=2 b=1))

    graph export bargraph_`depvar'.pdf, replace
    !convert -density 300 bargraph_`depvar'.pdf -quality 100 bargraph_`depvar'.png
    erase bargraph_`depvar'.pdf
    restore
}


