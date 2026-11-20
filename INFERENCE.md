# Inference

Native analytic clustered inference and native-studentized RI are N/A.
Official UN-DID displays other standard errors; those are not presumed to be
a canonical cluster VCE for this suite target.

Each deletion recomputes support and renormalizes the eligible weights. A deletion with no identifiable treated-control comparison is undefined.
Return every deletion slot and missing p-value on any failed deletion.
CV3J = (G-1)/G * sum((theta[-g]-mean(theta[-g]))^2).
Student t uses G-1 degrees of freedom. Zero or roundoff-scale standard errors
are numerical failures, never p=1.

Inclusive tails use 64 machine eps * max(1, statistic magnitudes) for numerical
ties. The p-value is (1+hits)/(B+1). Failed draws are not dropped or counted
as successful draws; the affected method returns an unavailable p-value.
R and Stata support exact multiset enumeration through 100000 total assignments and
seeded unique random sampling otherwise; sampling preserves the caller's RNG
state and has a documented bounded retry budget. Supplied matrices are
recommended for cross-language reproducibility. Both languages provide generators; seeded draws need not match between
languages. Supply the same matrix to obtain paired comparisons.

## November 2026 support revision

The Stata delete-cluster calculation now recomputes the estimator on surviving support. Disappearance of an adoption cohort by itself does not invalidate a deletion. Every required deletion must yield an estimate for a jackknife standard error. Covariate adjustment requires estimability of the requested contrast or target prediction; redundant nuisance coefficients are allowed. Each retained treated state-year uses supported control contrasts with renormalized weights.
