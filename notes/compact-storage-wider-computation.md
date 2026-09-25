# Deferred experiment: compact storage with wider computation

This is an experiment to revisit later, not the selected arithmetic policy.

For now, keep the current E3M2 implementation unchanged and continue measuring
its behavior. The active work is to run the primitive arithmetic, powers,
square root, rotations, caster examples, and the full 14×26 Dakota Jacobian and
record the observed values and residuals.

Do not infer from those measurements yet that E3M2 is too coarse, that a wider
format is required, or that an explicit wider-headroom computation strategy is
preferable.

## Later comparison

Once the E3M2 baseline is large enough to be useful, compare it against an
explicit variant of this form:

```text
compact measurement/storage
  → temporarily promote for computation
  → perform a larger computation with additional numerical headroom
  → requantize/store compactly afterward
```

The possible attraction is that computational headroom and measurement
precision are different things. A wider temporary carrier could reduce added
numerical error without claiming that the original measurement contained more
information.

That is only a hypothesis to test.

In particular, a quarter-degree, seventh, or one-decimal observation should
remain an observation at that resolution even if some future experiment uses a
wider arithmetic carrier internally.

## Baseline first

The current comparison order is:

1. preserve the present E3M2 behavior;
2. collect residuals;
3. inspect where information is lost, retained, or changes sign;
4. only then decide which alternative arithmetic/storage experiments are worth
   running.

Issue #98 records the deferred wider-headroom experiment.

No implementation change is requested by this note.
