version 16.0

clear all

set more off

capture set processors 1

adopath ++ "."

local checks 0

local maxerror 0

foreach label in balanced unequal covariates strings {

    insheet using "tests/fixtures/`label'_summary.csv", clear comma names double

    foreach v in estimate se statistic p ri_beta_p ri_beta_hits {

        scalar expected_`v' = `v'[1]

    }

    insheet using "tests/fixtures/`label'_deleted.csv", clear comma names double

    mkmat _all, matrix(EXDEL)

    insheet using "tests/fixtures/`label'_draws.csv", clear comma names double

    mkmat _all, matrix(EXDRAWS)

    insheet using "tests/fixtures/assignments.csv", clear comma names double

    mkmat _all, matrix(A)

    insheet using "tests/fixtures/`label'.csv", clear comma names double

    local covs ""

    if "`label'" == "covariates" local covs "x x2"

    suite_undid y `covs', time(t) cluster(s) gvar(g) inference(full) assignments(A)

    assert abs(e(estimate)-expected_estimate)<1e-9

    assert abs(e(jackknife_se)-expected_se)<1e-9

    assert abs(e(jackknife_t)-expected_statistic)<1e-9

    assert abs(e(jackknife_p)-expected_p)<1e-9

    assert e(jackknife_df)==7

    assert e(ri_beta_p)==expected_ri_beta_p

    assert e(ri_beta_hits)==expected_ri_beta_hits

    assert missing(e(native_se))

    assert missing(e(ri_t_native_p))

    matrix DEL=e(delete_estimates)

    matrix DRAWS=e(ri_statistics)

    mata: assert(max(abs(st_matrix("DEL")-st_matrix("EXDEL")))<1e-9)

    mata: assert(max(abs(st_matrix("DRAWS")-st_matrix("EXDRAWS")))<1e-9)

    mata: st_numscalar("matrix_error", max(abs(st_matrix("DEL")-st_matrix("EXDEL"))))
    local maxerror=max(`maxerror',matrix_error,abs(e(estimate)-expected_estimate),abs(e(jackknife_se)-expected_se),abs(e(jackknife_t)-expected_statistic),abs(e(jackknife_p)-expected_p))

    local checks = `checks'+14

}

insheet using "tests/fixtures/unequal.csv", clear comma names double

gen D=g>0 & t>=g

suite_undid y, time(t) cluster(s) treatment(D)

scalar base=e(estimate)

egen id=group(s j)

suite_undid y, time(t) cluster(s) gvar(g) ivar(id) datamode(panel)

assert abs(e(estimate)-base)<1e-9

local checks=`checks'+1

local before=c(rngstate)

suite_undid y, time(t) cluster(s) gvar(g) inference(ri_beta) reps(4) seed(18)

assert "`before'"==c(rngstate)

matrix ASAMPLE=e(assignments)

scalar oldp=e(ri_beta_p)

suite_undid y, time(t) cluster(s) gvar(g) inference(ri_beta) reps(4) seed(18)

assert e(ri_beta_p)==oldp

matrix ASAMPLE2=e(assignments)

mata: assert(all(st_matrix("ASAMPLE"):==st_matrix("ASAMPLE2")))

local checks=`checks'+3

preserve

keep if s<=4

replace g=cond(s<=2,3,0)

suite_undid y, time(t) cluster(s) gvar(g) inference(ri_beta) exact

assert e(assignment_space)==6

assert e(ri_reps)==5

restore

local checks=`checks'+3

preserve

replace g=0 if s==2

suite_undid y, time(t) cluster(s) gvar(g) inference(jackknife)

assert e(jackknife_p)<.

assert e(jackknife_status)==0

matrix DEL=e(delete_estimates)

mata: assert(rows(st_matrix("DEL"))==8)

restore

local checks=`checks'+3

preserve

replace y=s+t

suite_undid y, time(t) cluster(s) gvar(g) inference(jackknife)

assert missing(e(jackknife_p))

assert e(jackknife_status)==2

restore

local checks=`checks'+2

preserve

replace x2=x

suite_undid y x, time(t) cluster(s) gvar(g)

scalar identifiable=e(estimate)

suite_undid y x x2, time(t) cluster(s) gvar(g)

assert abs(e(estimate)-identifiable)<1e-9

restore

local checks=`checks'+1

capture noisily suite_undid y, time(t) cluster(s) gvar(g) ccc(hom)

assert _rc==198

local checks=`checks'+1

preserve

replace g=0 if s!=1

suite_undid y, time(t) cluster(s) gvar(g) inference(jackknife)

assert e(estimate)<. & missing(e(jackknife_p))

matrix DD=e(delete_estimates)

assert missing(DD[1,1]) & DD[2,1]<.

restore

di "MAXIMUM_DISCREPANCY " %21.16g `maxerror'

di "SUITE_TESTS_PASS undid: `checks' assertion groups"

exit, clear

