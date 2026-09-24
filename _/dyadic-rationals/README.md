# Dyadic rationals

Research/reference notes for a possible native ARM/Thumb dyadic-rational path.

This directory belongs to the archived/native ARM research side of the repository. It does not change or redefine the active direct-DEX `main` line.

The recurring representation is

```
value = numerator * 2^exponent
```

or equivalently

```
value = numerator / 2^precision
```

with powers of two removed from a nonzero numerator so that a canonical numerator can be kept odd.

## Why this is here

The existing native ARM slice already has word arithmetic and Float32 arithmetic. A first dyadic experiment can stay much narrower than a new general numeric tower: constructor/normalization, addition, multiplication, shifts, and an observable exact result.

Do not widen the whole floating pipeline merely to support this. Issue #83 already records the rule that arithmetic width must be justified by the error budget; issue #84 records the requirement to preserve dyadic/triadic semantic scales instead of replacing them with decimal-looking constants.

## Sources

- [HOTT.md](HOTT.md) — the HoTT Book explicitly identifies dyadic rationals `n / 2^k` as an approximate field suitable for constructive computer implementation.
- [LEAN.md](LEAN.md) — Lean 4 core implements canonical dyadics, exact ring operations, shifts, conversion to rationals, rounding, and precision-bounded inversion/division.
- [CONWAYHS.md](CONWAYHS.md) — ConwayHs implements arbitrary-precision dyadics as an integer numerator plus a power-of-two denominator exponent.
- [MACHINE-REPRESENTATION.md](MACHINE-REPRESENTATION.md) — what these sources do and do not establish for an ARM machine representation.
- [RESEARCH-PASS-2.md](RESEARCH-PASS-2.md) — broader exact-real literature: Coq, RZ, iRRAM, MPFR, dyadic streams, scaled integers, and arbitrary-radix certified arithmetic.
- [mirror/](mirror/) — exact pinned upstream source where redistribution terms are clear.

## First ARM acceptance slice

Keep the first executable claim small:

1. represent zero and one nonzero canonical dyadic;
2. normalize a numerator by removing powers of two;
3. add two values with different exponents;
4. multiply two values;
5. expose the exact resulting numerator/exponent pair;
6. compare against an integer/rational oracle.

Division should be a separate slice because dyadics are a ring, not a field: arbitrary reciprocals such as `1/3` are not dyadic. Lean's `invAtPrec` / `divAtPrec` are a useful model for making that approximation boundary explicit.
