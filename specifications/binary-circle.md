# Finite circle machine representations

This note specifies circular machine values. BAM/BAMS is an important machine
precedent, but a power of two is not required: different finite circles preserve
different exact rotations.

References:

- Microchip BAMS:
  https://onlinedocs.microchip.com/oxy/GUID-66AC09C2-8D1C-4C0C-A351-24C77EC714B0-en-US-6/GUID-D42077A2-62CF-4949-B15B-E0DEF7894036.html
- BBG binary-angle table:
  https://www.bbginc.com/wp-content/uploads/2022/01/DataSheet_BBG-1108b.pdf
- Ada modular types, as a language-level analogue:
  https://www.adaic.org/resources/add_content/standards/22rm/html/RM-3-5-4.html

## Machine model

A `Circle N` has exactly `N` positions around one complete turn.

A canonical stored code `u` denotes

```text
u / N turns
```

for

```text
0 <= u < N
```

The storage container may have spare bit patterns when `N` is not a power of
two. Those spare patterns are not circle values.

The source language need not expose integer addition or subtraction on circle
points.

## Public geometric operations

The ordinary interface should speak in geometric operations.

### Rotation

A rotation is a displacement around the circle.

```text
rotate : Rotation N -> Circle N -> Circle N
```

The backend may implement rotation using modular integer addition:

```text
rotate(code, r) = (code + r) mod N
```

but that integer addition is an implementation detail, not the source-level
meaning.

Composition belongs to rotations:

```text
compose_rotations : Rotation N -> Rotation N -> Rotation N
```

### Reflection

A reflection reverses orientation around an axis.

The zero-axis case lowers to

```text
reflect_zero(code) = (-code) mod N
```

More general reflections can be represented as a rotation composed with this
basic reflection.

Rotations and reflections generate the dihedral symmetries of the regular
`N`-gon.

### Local displacement

When a derivative or local linear model needs motion between two nearby circle
positions, use an explicit operation such as

```text
local_displacement : Circle N -> Circle N -> Tangent N
```

rather than giving `Circle N` a general subtraction operator.

The result is the shortest signed displacement, with a documented tie rule at an
exact half turn when `N` is even. This result is linear/tangent data, not
another circle point.

## Shifts are not circle operations

Bit shifts may exist on a storage word. They are not rotations or reflections
and should not appear in the ordinary `Circle` interface.

For a binary BAM value, left shift happens to implement angle doubling modulo
one turn. That is a different map from rigid rotation.

## Sector-plus-binary representations

A useful non-power-of-two family is

```text
Circle (q * 2^n)
```

where `q` is a small exact symmetry count and the remaining `n` bits give a
binary position inside that sector.

Conceptually the machine coordinate is

```text
(sector, position_within_sector)
```

with

```text
sector                 = 0 .. q-1
position_within_sector = 0 .. 2^n-1
```

The packed unsigned code

```text
code = sector * 2^n + position_within_sector
```

already has this form in ordinary binary. If the container has more tag patterns
than `q` needs, the remaining patterns are spare/noncanonical.

This preserves an exact non-dyadic symmetry globally while retaining ordinary
binary subdivision locally.

### Circle 96 = 3 * 32

`Circle96` fits in seven bits and naturally splits as

```text
00xxxxx   first third
01xxxxx   second third
10xxxxx   third third
11xxxxx   spare / noncanonical
```

so the three third-turn landmarks are visually immediate:

```text
0000000     0 degrees
0100000   120 degrees
1000000   240 degrees
```

Halfway through each third gives the sixth-turn landmarks:

```text
0010000    60 degrees
0110000   180 degrees
1010000   300 degrees
```

Thus the factor of three is carried by the sector tag while the five low bits
retain exact repeated binary subdivision within each third.

The representation does not require the source language to expose the pair as
two ordinary integers. `Circle96` remains one geometric circle type; the
factorization is a useful machine view and a source of exact named rotations.

### Fifth sectors

The same construction works for five-fold symmetry:

```text
Circle (5 * 2^n)
```

A packed representation needs enough high tag patterns to name sectors
0 through 4; the remaining tag patterns can be spare. The low `n` bits still
give exact halves, quarters, eighths, and so on inside each fifth.

This gives exact fifth-turn landmarks without giving up binary refinement
inside each fifth. It is useful for regular-pentagon geometry and the associated
`sqrt(5)` / golden-ratio constructions.

## Useful finite circles

There should not be one mandatory circle size. Choose a representation whose
exact rotations match the problem.

### Circle 144

```text
step = 2.5 degrees
```

Exact examples:

```text
10 degrees    4 ticks
12.5 degrees  5 ticks
15 degrees    6 ticks
30 degrees   12 ticks
45 degrees   18 ticks
60 degrees   24 ticks
90 degrees   36 ticks
```

This is a compact choice when 10 and 12.5 degrees matter.

### Circle 192

```text
step = 1.875 degrees
```

Exact examples:

```text
3.75 degrees   2 ticks
7.5 degrees    4 ticks
15 degrees     8 ticks
30 degrees    16 ticks
45 degrees    24 ticks
60 degrees    32 ticks
90 degrees    48 ticks
```

This matches the classical repeated-bisection family particularly well.

### Circle 240

```text
step = 1.5 degrees
```

Exact examples:

```text
7.5 degrees    5 ticks
15 degrees    10 ticks
30 degrees    20 ticks
45 degrees    30 ticks
60 degrees    40 ticks
72 degrees    48 ticks
90 degrees    60 ticks
```

Because 240 = 2^4 * 3 * 5, this circle preserves many square/triangle/pentagon
symmetries at once. Five-fold rotation is exact, making it especially useful for
regular-pentagon and golden-ratio constructions.

### Circle 256

```text
step = 1.40625 degrees
```

This is the ordinary 8-bit BAM-style choice. Dyadic fractions of a turn are
visually immediate in the bits, but thirds and fifths are not exact.

### Circle 360

```text
step = 1 degree
```

This is the straightforward exact-degree circle. It needs at least 9 storage
bits and modular reduction by 360 rather than a simple bit mask.

### Circle 384

```text
step = 0.9375 degrees
```

Exact examples:

```text
3.75 degrees   4 ticks
7.5 degrees    8 ticks
15 degrees    16 ticks
30 degrees    32 ticks
45 degrees    48 ticks
60 degrees    64 ticks
90 degrees    96 ticks
```

This is a useful 9-bit extension of the bisection/thirds family: resolution is
finer than one degree while the classical 30/45/60/90 and repeated-halving
angles remain exact. One degree itself is not exact.

### Circle 720

```text
step = 0.5 degree
```

This exactly represents every half degree, every integer degree, 12.5 degrees,
and five-fold rotations. It also matches the half-degree spacing of Ptolemy's
surviving chord table. It needs 10 bits.

## Historical angle-table connection

The old trigonometric tables suggest useful machine scales rather than one
universal binary scale.

Hipparchus's chord table is reconstructed with 7.5-degree spacing; a related
Indian tradition uses 3.75-degree spacing. Ptolemy's Almagest table uses
half-degree spacing. Ptolemy also obtained 30, 15, 7.5, and 3.75 degrees by
successive bisection.

These are not merely historical curiosities: `Circle 192`, `Circle 384`,
and `Circle 720` line up naturally with those step families.

## Exact geometry above the machine circle

Do not force exact classical geometry into the finite circle code.

The compiler/type layer can represent exact algebraic quantities separately,
including for example

```text
sqrt(5)
phi = (1 + sqrt(5)) / 2
```

and exact fractions of a turn such as

```text
1/5 turn
1/10 turn
1/16 turn
```

A regular pentagon naturally connects the circular and algebraic layers:
five-fold rotation is circular, while its chord/diagonal relations introduce
`sqrt(5)` and `phi`.

Likewise, pi is unnecessary for internal rotation when turns are the unit. Pi
enters when converting a turn measure to radians or when relating angular data
to circumference.

Continued fractions should also live at this exact symbolic layer rather than be
baked into one finite circle encoding. Useful canonical examples include the
periodic continued fractions of quadratic irrationals such as `phi`,
`sqrt(2)`, and `sqrt(5)`.

## ARM Thumb lowering

For power-of-two circles, modular reduction may be a mask/narrowing operation.

For non-power-of-two circles such as 144, 192, 240, 360, 384, or 720, lowering
must reduce modulo the actual number of positions. The source semantics remain
rotation/reflection semantics even when the backend uses ADD, SUB, compare,
conditional subtract, multiply-high, or another integer reduction sequence.

For 8-bit circles up to 256, a byte can contain the canonical code. For larger
circles, use the next convenient integer container; unused bit patterns remain
invalid/noncanonical circle values.

For `Circle96 = 3 * 32`, a seven-bit canonical payload admits particularly
simple field inspection even though rotation itself still reduces modulo 96:

```text
canonical(code)       = code < 96
third_sector(code)    = code >> 5
position_in_third     = code & 31
```

Thus extracting the geometric third and the binary coordinate within that third
needs only ordinary shift/mask operations. Those are representation inspection
operations; they are not themselves circle rotations.

No floating-point degrees or radians are required for the internal finite-circle
operations.

## Compiler consequence

Preserve the distinction among:

- a point on a finite circle;
- a rotation acting on that circle;
- a reflection;
- a local tangent displacement;
- and an exact symbolic angle or algebraic construction.

Do not collapse these into ordinary integer arithmetic merely because integer
instructions are used to lower them.
