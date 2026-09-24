# ConwayHs dyadic implementation

Pinned upstream:

- repository: `ming-t18/ConwayHs`
- commit: `d80a4ced80527c28306c781b60ae560975ab394a`
- primary file: `src/Data/Conway/Dyadic.hs`
- related division exploration: `src/Data/Conway/Dyadic/Ratio.hs`
- repository license: no license declared at the pinned revision

Because no repository license is declared, the source is **not copied into this repository**. Use the pinned upstream commit when inspecting it.

## Representation

ConwayHs describes its `Dyadic` as an arbitrary-precision dyadic rational represented by a pair

```
(n, p)
```

with value

```
n / 2^p
```

where `n` and `p` are integers and the constructor simplifies the pair so the denominator exponent is minimal.

Its `makeDyadic` normalization repeatedly divides an even numerator by two while decrementing `p`.

## Operations

The implementation supplies:

- construction/decomposition;
- conversion to and from binary `RealFloat` values;
- numerator/denominator access;
- multiplication/division by powers of two;
- addition/subtraction;
- multiplication;
- ordering/equality;
- a `Fractional` instance that rejects non-power-of-two rational denominators.

This independently confirms the same practical representation family as Lean: integer numerator plus a power-of-two exponent, normalized by removing factors of two.

## What to borrow conceptually

For the ARM slice, ConwayHs is useful independent evidence that a simple pair representation is enough for ordinary arithmetic. Lean is the better source for a canonical odd-numerator invariant and precision-bounded division proofs.

Do not copy ConwayHs source unless its licensing status changes.
