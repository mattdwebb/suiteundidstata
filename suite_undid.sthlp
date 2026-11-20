{smcl}
{title:Native UNDID suite adapter}
{pstd}Development supported subset; not full certification.{p_end}
{pstd}{cmd:suite_undid y [covariates], time(var) cluster(var)}
{cmd:gvar(var)} [{cmd:treatment(var) ivar(var) datamode(panel|rcs|auto)}
{cmd:inference(point|standard|full|method list) assignments(matrix)}
{cmd:reps(#) seed(#) exact null(#) ccc(int)}]{p_end}
{pstd}Supply gvar or treatment. Zero means never treated. Absorbing treatment
must be constant within cluster-period. Required row values must be finite. Identified surviving state-time comparisons are aggregated when some cells are absent.
Covariate designs must be full rank. No observation weights.{p_end}
{pstd}RI supports zero null only. Method list: native jackknife ri_beta
ri_t_native  . Native methods return missing, not substituted JK.
observed assignment, and have no duplicates. Columns follow sorted clusters.
Automatic generation preserves the caller's RNG state.{p_end}
{pstd}CV3J is mean-centered over every delete-cluster estimate and uses
Failed deletions/draws yield missing p-values. No failed draws are dropped.{p_end}
{pstd}e(estimate), e(att_st), e(delete_estimates), e(ri_delete_estimates),
e(ri_statistics), e(assignments), e(jackknife_se), e(jackknife_t),
e(jackknife_df), e(jackknife_p), e(ri_beta_p), e(ri_beta_p),
0 pass; 1 undefined deletion/draw; 2 zero or roundoff-scale JK variance;
missing means not requested. e(status) describes point success only.{p_end}
{pstd}Target: state-time effects weighted by treated target-cell size;
control differences weighted by baseline plus target cell size.
UN-DID uses silo-specific pair regressions. DID-INT uses target-standardized
predictions with separate state-time slopes (CCC int).{p_end}
