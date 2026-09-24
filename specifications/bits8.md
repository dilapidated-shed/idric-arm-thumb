# Bits8: Idris 2 unsigned 8-bit primitive

## Exact upstream references

This repository follows the Idris 2 primitive `Bits8` contract. The links
below are pinned to Idris 2 commit
`1c630e67c386629a0fbbc6b78a59176fde7f0a76`.

- numeric operations:
  https://github.com/idris-lang/Idris2/blob/1c630e67c386629a0fbbc6b78a59176fde7f0a76/libs/prelude/Prelude/Num.idr
- bit operations:
  https://github.com/idris-lang/Idris2/blob/1c630e67c386629a0fbbc6b78a59176fde7f0a76/libs/base/Data/Bits.idr
- backend primitive-type guidance:
  https://github.com/idris-lang/Idris2/blob/1c630e67c386629a0fbbc6b78a59176fde7f0a76/docs/source/backends/backend-cookbook.rst
- changelog entry introducing Bits8:
  https://github.com/idris-lang/Idris2/blob/1c630e67c386629a0fbbc6b78a59176fde7f0a76/CHANGELOG.md

## Value set

`Bits8` is an unsigned fixed-width integer with exactly 256 values:

```text
0 .. 255
```

It is not a floating-point type.

## Representation

The mathematical value is the unsigned integer represented by eight bits:

```text
b7 b6 b5 b4 b3 b2 b1 b0
```

The all-zero pattern is 0. The all-one pattern is 255 (`0xff`).

## Arithmetic

Idris 2 supplies primitive `Bits8` addition, subtraction, multiplication,
division, remainder, and negation.

The fixed-width operations are modulo `2^8 = 256` where overflow is possible:

```text
add(a,b) = (a + b) mod 256
sub(a,b) = (a - b) mod 256
mul(a,b) = (a * b) mod 256
neg(a)   = (-a) mod 256
```

For example, `255 * 255 = 1` as a `Bits8` value.

Division and remainder are unsigned operations and require a nonzero divisor.

## Order and equality

Equality compares the eight-bit values.

Ordering is unsigned numeric ordering:

```text
0 < 1 < ... < 255
```

## Bit operations

Idris 2 defines for `Bits8`:

- bitwise AND;
- bitwise OR;
- bitwise XOR;
- complement via XOR with `0xff`;
- logical left shift;
- logical right shift;
- bit test/set/clear helpers.

The public `Data.Bits` instance uses an eight-position bit index, `Fin 8`.

## Casts

Conversions into `Bits8` produce an eight-bit result; conversions out expose
the corresponding unsigned value. Backend lowering must therefore preserve the
low eight bits and must not reinterpret bit 7 as a sign bit.

## ARM Thumb consequence

The canonical scalar register representation for this backend is a
zero-extended value whose meaningful payload is the low eight bits. Arithmetic
that can overflow must be reduced back to those eight bits before the result is
observed as `Bits8`.

## Thanks

Thank you to Edwin Brady and the Idris 2 contributors who designed, implemented,
documented, and maintain the `Bits8` primitive and its operations.
