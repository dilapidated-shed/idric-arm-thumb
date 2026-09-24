# Float16: IEEE 754 binary16

## Exact upstream reference

- IEEE Std 754-2019, *IEEE Standard for Floating-Point Arithmetic*:
  https://standards.ieee.org/standard/754-2019.html
- DOI: https://doi.org/10.1109/IEEESTD.2019.8766229

IEEE 754 is broader than this repository. This file gives the complete binary16
encoding contract needed by the ARM Thumb backend. The IEEE standard remains
authoritative for the full arithmetic environment, exception flags, NaN
propagation details, alternate rounding directions, and other operations.

## Storage

Binary16 occupies 16 bits:

```text
15          14        10 9                         0
+-------------+----------+--------------------------+
| sign: 1 bit | exponent | trailing significand: 10|
+-------------+----------+--------------------------+
                   5 bits
```

Let:

- `S` be the sign bit.
- `E` be the unsigned 5-bit exponent field.
- `M` be the unsigned 10-bit trailing-significand field.
- exponent bias = 15.

## Values

### Normal numbers

For `1 <= E <= 30`:

```text
value = (-1)^S * 2^(E - 15) * (1 + M / 1024)
```

The unbiased normal exponent range is -14 through +15.

### Subnormal numbers

For `E = 0` and `M != 0`:

```text
value = (-1)^S * 2^(-14) * (M / 1024)
      = (-1)^S * M * 2^(-24)
```

### Zeros

For `E = 0` and `M = 0`:

- `S = 0`: +0
- `S = 1`: -0

### Infinities

For `E = 31` and `M = 0`:

- `S = 0`: +infinity
- `S = 1`: -infinity

### NaNs

For `E = 31` and `M != 0`, the value is NaN. IEEE 754 further specifies
quiet/signaling NaNs, payloads, exception behavior, and propagation rules; those
rules come from the upstream standard rather than being redefined here.

## Boundary values

```text
minimum positive subnormal = 2^-24
minimum positive normal    = 2^-14
maximum finite             = 65504
```

The maximum finite encoding is `0 11110 1111111111`.

## Rounding

When this repository converts a wider binary floating value to binary16 without
an explicitly requested rounding direction, the default is round-to-nearest,
ties-to-even. Other IEEE 754 rounding directions are separate policy choices and
must not be silently substituted.

## ARM Thumb consequence

A 16-bit binary16 payload may live in a larger general-purpose register, but the
payload is exactly the low 16 bits. Register width does not change the binary16
format.

## Thanks

Thank you to the IEEE 754 working group and the many contributors who developed
and standardized binary floating-point arithmetic, including binary16.
