# Method specification

This suite adapter supports cluster-period microdata with finite required row values, absorbing
cluster-level adoption, never-treated controls, and weighting="both".
Never-treated adoption is 0. Positive adoption dates need both pre and post
observations. The baseline for cohort g is the last observed period before g.

For each treated state s and post period t, estimate a contrast against the
never-treated states. Control-state contrasts receive weights N[c,t]+N[c,b].
The resulting ATT(s,t) receives target weight N[s,t]. The scalar estimate is
sum(N[s,t]*ATT(s,t))/sum(N[s,t]). This equals the canonical target-weight
hierarchy through group-time and cohort aggregates for weighting="both".
No pooling of treated states replaces the state-time primitive.

UN-DID: fit Y on intercept, post indicator and supplied X separately inside
each state and baseline/post pair. The post coefficient is that state's
adjusted difference. Without X use the difference of cell means. This
preserves silo-specific pair slopes; it is not pooled residualization.

DID-INT: fit state-time intercepts and CCC slopes on the full sample. CCC int
allows a separate slope per state-time cell; hom/state/time share the slope
in the corresponding blocks after removing cell means. Evaluate ALL source
cell models on the same treated target-cell X distribution, form each source
post-minus-baseline prediction, then contrast. Linear models permit exact
evaluation at target X means. This is the historical fitted-value target,
not the older intercept-only target. Supplied time-varying X is not frozen.

The Stata DID-INT adapter supports CCC int. Each required contrast or fitted
prediction must be identified by its observed design. Redundant nuisance columns
do not invalidate an identified target, and an unadjusted fallback is never
substituted for an unidentified adjusted contrast. Missing cells and unidentified
control comparisons can reduce support; a treated state-time effect contributes
only when the required target and at least one eligible comparison are estimable.
The final aggregate normalizes its weights over the supported state-time effects.

Observation weights, not-yet-treated controls and policy-specific targets remain
unsupported by these suite adapters. UN-DID additionally permits the documented
comparison-period aggregation-weight option; the default uses post-period treated
counts. The original distributed UN-DID API has a different option surface.

Panel mode validates unit-time uniqueness and cluster membership. RCS uses
cell distributions and never constructs individual differences. The estimate
is the same for identical microdata in both representations.

## Linearity

With fixed assignment, sample and X, each least-squares fit is linear in Y.
UN-DID pair contrasts and DID-INT predictions are linear maps with weights
depending only on X and cell sizes. The final contrasts and aggregation are
therefore exactly linear in Y on the full-rank supported domain. Assignment
and cluster deletion change targets, weights and any shared slope fits;
these are recomputed. Numerical superposition tests supplement this argument.
