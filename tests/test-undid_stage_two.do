clear all
set more off
version 16

/*------------------------------------*/
/*-----------TEST TEST TEST-----------*/
/*----------undid_stage_two-----------*/
/*-----------TEST TEST TEST-----------*/
/*--------------UNTESTED---------------*/
/*-------version 1.1.0 2025-09-30-----*/
/*------------------------------------*/
/*EXITS 1 to 13: PASSING --------------*/


* Load this checkout without changing installed upstream packages.
local pkg_path "`c(pwd)'"
capture confirm file "`pkg_path'/suite_undid.pkg"
if _rc local pkg_path "`c(pwd)'/.."
confirm file "`pkg_path'/suite_undid.pkg"
foreach part in helpers stage_one stage_two stage_three {
    adopath ++ "`pkg_path'/package_functions/`part'"
}

* ---------------------------------------------- *
* Step 3: Load in silo data and try variations of undid_stage_two
* make sure proper error messages display
* ensure outputted csv files are correct
* ---------------------------------------------- *






use "test_dta_files\merit.dta", clear



qui levelsof state, local(states)
foreach s of local states {
	use "test_dta_files\merit.dta", clear
	keep if state == `s'
	if `s' == 71 {
		keep if year != 1993
	}
	if `s' == 11 {
		keep if year != 1992
	}
	tostring year, replace
	undid_stage_two, empty_diff_filepath("test_csv_files\empty_diff_df_staggered.csv") silo_name(`s') time_column(year) outcome_column(coll) silo_date_format("yyyy") filepath("test_csv_files\stage_three\staggered\missing_vals\noyr93_ins71_noyr92_ins11") anonymize_weights(0)


}


 
