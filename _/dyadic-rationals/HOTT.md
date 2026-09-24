# HoTT Book: dyadics as an approximate field

Pinned upstream:

- repository: `HoTT/book`
- commit: `578b85cc8d586b1677ec4335148adeb443057d24`
- source: `reals.tex`
- upstream license: Creative Commons Attribution-ShareAlike 3.0 Unported

The relevant passage is in the chapter's section on rational numbers. The book observes that the rationals used to build the reals could be replaced by an **approximate field**: a subring of the rationals with arbitrarily precise approximate inverses. It gives the dyadic rationals, numbers of the form

```
n / 2^k
```

as an example, and explicitly says that such an approximate field is more suitable when implementing constructive mathematics on a computer.

## What this establishes

This is direct mathematical precedent for treating dyadics as a computationally useful number system rather than as a formatting trick around binary floating point.

For our compiler work, the useful consequences are:

- exact dyadic addition/subtraction/multiplication stay inside the representation;
- powers of two are structural, not decimal constants;
- arbitrary inverse/division is an approximation operation and should carry an explicit requested precision/error boundary;
- a machine/backend can preserve that structure before any final target-specific approximation.

The HoTT Book does **not** prescribe our concrete ARM ABI, register layout, overflow policy, or fixed word width. Those remain backend decisions.

An exact copy of the pinned upstream `reals.tex` and its upstream README/license statement is under `mirror/hott-book/`.
