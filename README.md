# UN-DID in Stata

Estimate a staggered policy effect from comparisons of changes within treated and never-treated schools.

The suite_undid command constructs treated-school/time contrasts against eligible never-treated schools and aggregates the supported effects. It works with a dataset already available in one Stata session. The original three-stage UN-DID workflow for data held in separate silos remains available in this repository.

## Install

Requires **Stata 16 or later**. No R, Python, or additional Stata estimation
packages are required to use this command.

Install the command directly from GitHub:

```stata
net install suite_undid, from("https://raw.githubusercontent.com/mattdwebb/suiteundidstata/main/") replace
discard
which suite_undid
```

For a source-only trial, `adopath ++ "."` makes this checkout available for the
current session. Use one known version and record it for reproducible work.

## A school-policy example

The included fictional data contain 960 pupil observations: ten pupils in each of 12 schools and eight years (2010–2017). Pupils are repeated cross sections, so their row numbers are not longitudinal identifiers.
Four schools adopt in 2013, four in 2015, and four never adopt. The outcome is
`test_score`, measured in score points. `baseline_score` is a predetermined
covariate. Schools are the independent inference clusters.

The data generator adds a two-point policy effect, alongside school, year,
covariate, and varying disturbance components. This is a software teaching
example, not evidence about an actual policy. The [data guide](examples/DATA_GUIDE.md)
defines every variable and links the reproducible generator.

Run from the extracted repository folder:

```stata
clear
set type double
insheet using "examples/school_policy.csv", comma names clear
suite_undid test_score baseline_score, time(year) cluster(school) gvar(first_treat) inference(jackknife)
display e(estimate)
display e(jackknife_se)
```

The executed example gives:

| Estimate (score points) | Native clustered SE | Jackknife SE |
|---:|---:|---:|
| 2.391928 | Not reported | 0.523918 |

The estimated effect is about **2.39 score points**. The jackknife
standard error is **0.52 points**, calculated by leaving each of the twelve
schools out in turn. It describes uncertainty around this estimate; it does not
change the point estimate or establish the identifying assumptions of a policy
study. Standalone jackknife p-values use Student t with 11 degrees of freedom here.

`do examples/school_policy.do` runs this example, prints a compact table, and
saves `examples/school_results.csv`. Its [recorded output](examples/expected_output.txt)
is checked against the release example. Small last-digit differences may depend
on numerical libraries; they should not change the substantive result.

## Adapt it to your data

Use zero for never-treated schools and repeat each school’s first treatment year on all its rows. Treatment must be absorbing and common to observations in a school-year.

Covariates follow the outcome in the variable list. Omit `baseline_score` for an unadjusted specification. Use numeric covariates whose timing makes sense for your study;
the command does not make post-treatment controls causally appropriate.

Request `inference(jackknife)` for the delete-school calculation. The native analytic option is unavailable for this aggregate.

When a deletion removes a cohort, the jackknife recomputes the estimator’s
supported aggregate and its weights using the surviving estimable effects.
All cluster deletions must yield a scalar estimate. A genuinely unidentified
deletion is reported as a failure; it is never silently omitted.

Coefficient randomization inference and the supported studentized variants use
alternative cohort assignments while preserving treatment counts. These require
more input than the introductory example; see [inference options](INFERENCE.md).
Changing the treatment assignment must also change any treatment-dependent fits.

## Supported scope

The suite adapter uses absorbing treatment and never-treated controls. Required row values must be finite; absent cells or unidentified comparisons are excluded from the aggregate only when supported estimable comparisons remain. It supports covariate adjustment but not observation weights. It does not report a separate analytic clustered standard error for its aggregate.

Different DiD estimators can target different weighted averages when effects
vary. Comparing their coefficients does not by itself show that one is correct.
Unsupported options return explicit errors rather than substituting another model.

## Help, methods, and validation

- [Estimator definition and references](METHOD_SPECIFICATION.md)
- [Inference definitions](INFERENCE.md)
- [Technical development reference](docs/DEVELOPMENT_REFERENCE.md)
- [Runnable example](examples/school_policy.do) and [data definitions](examples/DATA_GUIDE.md)
- [License](LICENSE)

Use the repository’s Issues page for a reproducible problem report. Include your
software version, a small artificial dataset, and the exact command. Do not post
confidential research data. For developers, `tests/run_release_tests.ps1` runs the
native Stata checks and records their status with a licensed Stata installation.

## Data held in separate silos

The original `undid_init`, `undid_diff`, `undid_stage_two`, and
`undid_stage_three` commands implement the distributed three-stage workflow.
Their [original guide](docs/DEVELOPMENT_REFERENCE.md) is preserved. Installing
the original SSC package does not install this separately named suite adapter.
The [suite guide](SUITE_README.md) describes the single-dataset route used above.

## Package identity

Install `suite_undid` from this repository. This installer contains only the separately named suite adapter and does not overwrite Eric Jamieson's SSC `undid` command. The repository retains its `-dev` URL during review.
