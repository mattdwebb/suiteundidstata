version 16
clear all
set more off
* Load this checkout without changing installed upstream packages.
local pkg_path "`c(pwd)'"
capture confirm file "`pkg_path'/suite_undid.pkg"
if _rc local pkg_path "`c(pwd)'/.."
confirm file "`pkg_path'/suite_undid.pkg"
foreach part in helpers stage_one stage_two stage_three {
    adopath ++ "`pkg_path'/package_functions/`part'"
}
foreach command in undid_init undid_diff undid_stage_two undid_stage_three undid_plot {
    findfile `command'.ado
    assert strpos(subinstr(r(fn),"\","/",.),"package_functions/")>0
}
di "LEGACY_SOURCE_LOADER_PASS; no package installation or removal"
