version 16
clear all
set more off
set type double
adopath ++ "."
insheet using "examples/school_policy.csv", comma names clear
suite_undid test_score baseline_score, time(year) cluster(school) gvar(first_treat) inference(jackknife)
matrix school_results=(e(estimate),.,e(jackknife_se))
matrix colnames school_results=estimate native_se jackknife_se
matrix list school_results, format(%10.6f)
assert !missing(school_results[1,1],school_results[1,3])
assert school_results[1,3]>0
tempname output
file open `output' using "examples/school_results.csv", write replace
file write `output' "estimate,native_se,jackknife_se" _n
file write `output' %24.17g (school_results[1,1]) "," %24.17g (school_results[1,2]) "," %24.17g (school_results[1,3]) _n
file close `output'
display "SCHOOL_EXAMPLE_PASS"
