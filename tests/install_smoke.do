version 16.0
clear all
set more off
local root=c(pwd)
capture mkdir ".test-install"
net set ado "`root'/.test-install"
net install suite_undid, from("`root'") replace
cd ".test-install"
adopath ++ "./s"
findfile suite_undid.ado
assert strpos(r(fn),".test-install")>0 | strpos(r(fn),"./s/")>0
set obs 480
gen s=ceil(_n/60)
bysort s: gen t=ceil(_n/10)
gen g=cond(s<=2,3,cond(s<=4,5,0))
gen double y=s+t+2*(g>0 & t>=g)+sin(s*t)/10
suite_undid y, time(t) cluster(s) gvar(g) inference(standard)
assert !missing(e(estimate))
assert e(jackknife_status)==0
di "INSTALLED_PACKAGE_PASS suite_undid"
exit, clear
