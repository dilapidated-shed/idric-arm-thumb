# Scalar numeric reference specifications

This directory keeps the five scalar-format references currently used by the
ARM Thumb work:

1. [Float16 / IEEE binary16](float16.md)
2. [FP8 / OCP OFP8](fp8.md)
3. [E3M2 / OCP FP6 element format](e3m2.md)
4. [E5M3 / Ootomo-Naruse unsigned 8-bit storage format](e5m3.md)
5. [Bits8 / Idris 2 unsigned 8-bit primitive](bits8.md)

Each local file is a complete implementation-oriented restatement of the format
contract needed by this repository and links to the exact upstream reference.
The upstream document or source remains authoritative where it specifies
behavior outside the local backend's scope.

The formats are deliberately kept distinct. In particular:

- OCP FP8 means the signed 8-bit E4M3 and E5M2 interchange formats.
- OCP E3M2 is a signed 6-bit FP6 element format.
- Ootomo-Naruse E5M3 is an **unsigned** 8-bit storage format: five exponent
  bits plus three mantissa bits and no sign bit.
- Bits8 is an unsigned modular integer, not a floating-point format.
