clear
set obs 480
gen s=ceil(_n/60)
bysort s: gen t=ceil(_n/10)
gen g=cond(s<=2,3,cond(s<=4,5,0))
gen double y=s+t+2*(g>0 & t>=g)+sin(s*t)/10
suite_undid y, time(t) cluster(s) gvar(g) inference(full) reps(7) seed(19)
