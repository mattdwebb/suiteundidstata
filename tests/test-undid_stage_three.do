clear all
set more off
version 16

/*------------------------------------*/
/*-----------TEST TEST TEST-----------*/
/*----------undid_stage_three-----------*/
/*-----------TEST TEST TEST-----------*/
/*-------version 1.0.0 2025-08-16-----*/
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
* Step 3: Load in silo data and try variations of undid_stage_three
* make sure proper error messages display
* ensure outputs are correct
* ---------------------------------------------- *
// show trace for up to, say, 1 levels of calls

clear
set trace off
set tracedepth 1

undid_stage_three, dir_path("test_csv_files\stage_three\staggered\") only("88 11")
