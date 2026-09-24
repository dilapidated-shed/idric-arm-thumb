# Lean 4 core dyadic implementation

Pinned upstream:

- repository: `leanprover/lean4`
- commit: `2c2bdd9630a7a6c51d7620d5efefcdba104f38f3`
- files: `src/Init/Data/Dyadic/{Basic,Inv,Round,Instances}.lean`
- upstream license: Apache-2.0

Lean's implementation is the strongest concrete model here because it carries the representation, normalization rules, arithmetic, proofs, and bounded inverse/division in one maintained core library.

## Representation

Lean represents a dyadic as either zero or

```
ofOdd n k
```

with a proof that `n` is odd. Its mathematical value is

```
n * 2^(-k)
```

where `k` is an integer.

That gives a canonical nonzero representation: powers of two are removed from the numerator.

## Normalization

`ofIntWithPrec i prec` counts the trailing binary zeros of a nonzero integer `i`, shifts them out of the numerator, and adjusts the precision/exponent accordingly.

This is especially relevant to ARM/Thumb: the normalization model is integer arithmetic plus binary shifts. We do not need to invent a decimal or floating normalization scheme.

## Arithmetic

The core operations follow the expected exact rules:

- addition aligns exponents with left shifts and renormalizes only when necessary;
- multiplication multiplies numerators and adds exponents;
- negation changes numerator sign;
- left/right dyadic shifts adjust the exponent;
- conversion to `Rat` proves the intended rational value.

## Division is explicitly bounded

Dyadics are not closed under arbitrary reciprocal. Lean therefore has:

- `invAtPrec x prec`
- `divAtPrec a b prec`

These return the greatest dyadic, at the requested maximum precision, below the exact rational inverse/division result. The library proves interval-style bounds describing the approximation.

That is a useful design constraint for Idriç: do not pretend arbitrary division is exact. Preserve exact dyadic operations where they are exact, and make requested precision part of the operation where approximation genuinely enters.

## ARM consequence

A first native implementation does not need all of Lean. The transferable kernel is:

1. zero versus normalized odd numerator + binary exponent;
2. trailing-zero normalization;
3. exponent-aligned addition;
4. integer multiplication + exponent addition;
5. explicit bounded division later.

Exact pinned source is mirrored under `mirror/lean4/`.
