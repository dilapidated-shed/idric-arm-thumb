# Machine-representation conclusion

The sources support a concrete compiler experiment, but they establish different things.

## Mathematical existence

The HoTT Book identifies dyadic rationals `n / 2^k` as an approximate field suitable for constructive computation. This establishes that dyadics are a legitimate computational number system, not merely a property of IEEE binary floats.

## Executable representations

Lean 4 and ConwayHs independently implement essentially the same machine-friendly carrier:

```
integer numerator + binary exponent
```

with powers of two removed from the numerator for normalization.

Lean's stronger canonical form is:

```
zero
or
odd numerator * 2^(-integer exponent)
```

## What Float32 is doing now

IEEE binary floating-point values are mathematically dyadic rationals when finite, but the current ARM Float32 path does not expose the dyadic structure as a semantic compiler object. It exposes a fixed IEEE encoding with bounded significand/exponent and IEEE rounding behavior.

An explicit dyadic representation would therefore be a different semantic choice even if some values coincide bit-for-value with Float32.

## What ARM can exploit

A normalized small-word dyadic path maps naturally to:

- integer add/subtract/multiply;
- count-trailing-zero operations or equivalent loops;
- left/right shifts for exponent alignment;
- comparisons after alignment;
- explicit overflow checks or widening where required.

No claim is made yet that one particular two-word ABI is optimal. The first experiment should measure that rather than predeclare it.

## Triadics

The same high-level idea can represent `n / 3^k`, but ARM does not get the same shift-based realization. Triadics therefore belong in the semantic numeric discussion while their lowering cost remains distinct.

Related trackers:

- `isomorphisms/idric-arm-thumb#83` — arithmetic width follows the error budget.
- `isomorphisms/idric-arm-thumb#84` — preserve dyadic/triadic scales instead of decimal-round constants.
- `bl4ckb4ll/econometrician#61` and `#62` — accuracy versus numerical precision and structurally justified rational scales.
- `isomorphisms/idris-shader-backend#61` and `#62` — visible-error budgets and rational scale families.
