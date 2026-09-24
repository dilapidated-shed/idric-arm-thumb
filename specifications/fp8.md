# FP8: OCP 8-bit Floating Point Specification (OFP8)

## Exact upstream reference

Open Compute Project, *OCP 8-bit Floating Point Specification (OFP8)*,
Revision 1.0:

https://www.opencompute.org/documents/ocp-8-bit-floating-point-specification-ofp8-revision-1-0-2023-06-20-pdf

The specification defines two 8-bit interchange encodings: E4M3 and E5M2.
It specifies conversion from wider floating formats. It does **not** specify
arithmetic operations directly on FP8 values.

## Common field interpretation

For either format:

```text
value(normal) =
    (-1)^S * 2^(E - bias) * (1 + M / 2^m)

value(subnormal) =
    (-1)^S * 2^(1 - bias) * (M / 2^m)
```

where `m` is the number of mantissa/trailing-significand bits.

## E4M3

```text
bit 7       bits 6..3       bits 2..0
+------+----------------+---------------+
| sign | exponent: 4    | mantissa: 3   |
+------+----------------+---------------+
```

Parameters:

```text
bias                    7
minimum normal exponent -6
maximum normal exponent +8
minimum subnormal       2^-9
minimum normal          2^-6
maximum finite          448
infinity                not represented
```

Special encodings:

```text
zero:  S 0000 000
NaN:   S 1111 111
```

Every `E = 15` pattern except `M = 7` is finite. Thus the largest finite
encoding is `S 1111 110`.

## E5M2

```text
bit 7       bits 6..2       bits 1..0
+------+----------------+---------------+
| sign | exponent: 5    | mantissa: 2   |
+------+----------------+---------------+
```

Parameters:

```text
bias                    15
minimum normal exponent -14
maximum normal exponent +15
minimum subnormal       2^-16
minimum normal          2^-14
maximum finite          57344
```

Special encodings:

```text
zero:      S 00000 00
infinity:  S 11111 00
NaN:       S 11111 01
           S 11111 10
           S 11111 11
```

The OCP specification does not assign distinct meanings to the three E5M2 NaN
mantissa values.

## Conversion from wider formats

OFP8 requires conversion support from IEEE binary32, IEEE binary16, and
bfloat16.

Required conversion behavior:

- round-to-nearest, ties-to-even must be supported;
- both saturating and non-saturating overflow modes must be supported;
- source NaN converts to an implementation-defined destination NaN;
- source sign is preserved except when a NaN is produced;
- values below the smallest destination subnormal round to signed zero.

After rounding, overflow behaves as follows.

### Saturating mode

```text
E4M3 -> signed maximum finite magnitude
E5M2 -> signed maximum finite magnitude
```

### Non-saturating mode

```text
E4M3 -> NaN
E5M2 -> signed infinity
```

The same rule applies when the source is infinity.

## Arithmetic

OFP8 Revision 1.0 explicitly leaves arithmetic on E4M3/E5M2 out of scope.
Therefore a backend must name its arithmetic policy separately, for example:

- widen, compute, round back;
- explicitly wider accumulator;
- or a separately specified strict low-precision arithmetic.

Do not attribute one of those policies to OCP OFP8 itself.

## License provenance

The OCP document states that contributions are under the Open Web Foundation
Modified Contributor License Agreement and usage is governed by the Open Web
Foundation Modified Final Specification Agreement. See the license section of
the upstream PDF and OCP legal documents for the exact terms.

## Thanks

Thank you to the OFP8 specification authors:

Paulius Micikevicius, Stuart Oberman, Pradeep Dubey, Marius Cornea,
Andres Rodriguez, Ian Bratt, Richard Grisenthwaite, Norm Jouppi,
Chiachen Chou, Amber Huffman, Michael Schulte, Ralph Wittig,
Dharmesh Jani, and Summer Deng; and to the other contributors and reviewers who
helped standardize the format.
