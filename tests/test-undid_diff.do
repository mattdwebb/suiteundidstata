* Run from the package root; commands are loaded from this checkout.
clear all
set more off

/*------------------------------------*/
/*-----------TEST TEST TEST-----------*/
/*----------create_diff_df------------*/
/*-----------TEST TEST TEST-----------*/
/*-------version 1.0.0 2025-02-15-----*/
/* exit 2: PASSING -------------------*/
/* exit 3: PASSING -------------------*/
/* exit 4: PASSING -------------------*/
/* exit 5: PASSING -------------------*/
/* exit 6: PASSING -------------------*/
/* exit 7: PASSING -------------------*/
/* exit 8: PASSING -------------------*/
/* exit 9: PASSING -------------------*/
/* exit 10: PASSING ------------------*/
/* COVARIATE PROCESSING: PASSING -----*/
/* exit 11: PASSING ------------------*/
/* exit 12: PASSING ------------------*/
/* exit 13: PASSING ------------------*/
/* exit 14: PASSING ------------------*/
/* exit 15: PASSING ------------------*/
/* COMMON ADOPTION: PASSING ----------*/
/* STAGGERED ADOPTION: PASSING  ------*/



/*------------------------------------*/

* Load this checkout without changing installed upstream packages.
local pkg_path "`c(pwd)'"
capture confirm file "`pkg_path'/suite_undid.pkg"
if _rc local pkg_path "`c(pwd)'/.."
confirm file "`pkg_path'/suite_undid.pkg"
foreach part in helpers stage_one stage_two stage_three {
    adopath ++ "`pkg_path'/package_functions/`part'"
}

* ---------------------------------------------- *
* Step 3: Try variations of create_diff_df
* make sure proper error messages display
* ensure outputted csv files and frames are correct
* ---------------------------------------------- *

undid_diff , init_filepath("tests/test_csv_files\stage_three\staggered\missing_vals\only11control\init_only11.csv") date_format("yyyy") freq("years") filepath("`c(pwd)'////")