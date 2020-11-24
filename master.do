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

* simple analysis by race:
keep if age >= 16 & basicwgt > 0 & basicwgt != .
gen byte telework = ptcovid1 == 1 if emp == 1
gen byte emp_reduced = ptcovid2 == 1  
gen byte furlough_pay = ptcovid3 == 1 if ptcovid2 == 1
collapse (mean) telework emp_reduced furlough_pay [aw=basicwgt], by(wbho)


