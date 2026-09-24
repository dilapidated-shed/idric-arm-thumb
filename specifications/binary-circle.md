# Binary circle machine representation

This note specifies a finite circular value as a machine representation, not
merely as an abstract modular-number type.

The immediate machine precedent is Binary Angle Measurement / the Binary
Angular Measurement System (BAM/BAMS): an unsigned binary word represents a
fraction of one complete turn. Hardware and DSP documentation uses this form
because ordinary fixed-width addition and subtraction already perform the
required wraparound.

Reference precedents:

- Microchip BAMS definition:
  https://onlinedocs.microchip.com/oxy/GUID-66AC09C2-8D1C-4C0C-A351-24C77EC714B0-en-US-6/GUID-D42077A2-62CF-4949-B15B-E0DEF7894036.html
- BBG binary-angle bit table:
  https://www.bbginc.com/wp-content/uploads/2022/01/DataSheet_BBG-1108b.pdf
- Ada modular types are a useful language-level analogue:
  https://www.adaic.org/resources/add_content/standards/22rm/html/RM-3-5-4.html

## Finite circle

For a power-of-two circle with

```text
m = 2^n
```

points, store a point as an unsigned `n`-bit integer

```text
u = 0 .. m-1
```

and interpret it as

```text
u / m turns
```

around the circle.

A source spelling may therefore use the number of points:

```text
Circle 256
Circle 65536
```

while the machine representation is respectively 8 or 16 bits.

For `Circle 256`, one step is

```text
1 / 256 turn = 1.40625 degrees
```

and the familiar binary fractions of a turn are visible directly:

```text
00000000    0 turns       0 degrees
00100000    1/8 turn     45 degrees
01000000    1/4 turn     90 degrees
10000000    1/2 turn    180 degrees
11000000    3/4 turn    270 degrees
```

## Circle operations

The public operations are geometric circle operations.

### Rotate

Rotate a point by a circular displacement:

```text
rotate(point, delta) = (point + delta) mod m
```

Composition of rotations is the same modular addition:

```text
compose(a, b) = (a + b) mod m
```

For `Circle 256`:

```text
rotate_45(x)  = x + 32  mod 256
rotate_90(x)  = x + 64  mod 256
rotate_180(x) = x + 128 mod 256
```

These are additions on the circle, not bit shifts.

### Reflect

Reflection through zero reverses orientation:

```text
reflect(x) = (-x) mod m
```

Together, rotations and reflection give the usual symmetries of the regular
`m`-gon.

### Local signed difference

The difference between two circle points is not another global circle point when
we are asking for local motion. It is a signed tangent displacement.

Define

```text
difference(to, from)
    = signed_n((to - from) mod 2^n)
```

where `signed_n` reinterprets the same `n` bits as two's-complement.

The result lies in

```text
[-m/2, m/2)
```

steps, corresponding to

```text
[-1/2, 1/2)
```

turn.

The exact half-turn is geometrically ambiguous; this representation chooses the
negative half-turn as the canonical signed result.

This operation is the one to use when a later calculation needs an ordinary
linear displacement, derivative, Jacobian entry, or tangent coordinate.

## Equality and order

Equality is equality of circular position.

There is no intrinsic global less-than order on a circle. A backend may compare
the raw unsigned encodings for implementation purposes, but that raw ordering
must not silently become semantic circle ordering.

## Shifts are not circle operations

The underlying storage word can of course be shifted as bits, but left shift,
right shift, and rotate-through-carry are representation operations rather than
operations of this circle type.

In particular, a left shift would implement an angle-doubling map after
truncation; it is not a rigid rotation. It should therefore not appear in the
ordinary `Circle` interface merely because the payload is binary.

## Exact named rotations

A named fraction of a turn is exact when its denominator divides the number of
points.

For every power-of-two circle, halves, quarters, eighths, and so on are exact.
Thirds and sixths are not exact in `Circle 256`:

```text
30 degrees = 21 1/3 steps
60 degrees = 42 2/3 steps
```

If exact 30- and 60-degree rotations are a requirement, the number of points
must include a factor of 3; that is a different representation tradeoff from
pure power-of-two BAM/BAMS.

## Choosing the number of points

Do not choose 16 bits merely because 16 bits are cheap.

Choose the smallest circle whose step is comfortably finer than the physical
setting or measurement uncertainty. More stored positions than the mechanism
can distinguish add no useful information.

For the present cam-rotation work, `Circle 256` is a plausible machine scale
because one step is about 1.4 degrees. The final choice should follow measured
repeatability rather than an arbitrary preference for a wider word.

## ARM Thumb lowering

For a power-of-two circle, lowering is ordinary fixed-width integer arithmetic
with explicit narrowing at the type boundary.

For `Circle 256`:

```text
rotate       ADD then keep low 8 bits
reflect      negate then keep low 8 bits
difference   SUB then reinterpret low 8 bits as signed
```

Thumb can express the boundary cheaply with byte narrowing/sign extension
operations such as `UXTB` and `SXTB`.

For `Circle 65536`, the analogous boundary uses the low 16 bits and unsigned
or signed halfword extension.

No floating-point degrees or radians are needed for internal circle arithmetic.
Convert to human units only at an input/output boundary.

## Compiler consequence

Keep circular position distinct from ordinary linear number semantics through
the compiler.

A circle point wraps. A local signed difference does not wrap semantically; it
is a tangent displacement. Lowering must not erase that distinction before the
compiler has used it.
