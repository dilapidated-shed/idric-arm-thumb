# Compact storage, wider computation

Low-precision storage and arithmetic precision are separate decisions.

For Float16, E4M3, E5M2, and E3M2, the backend-local arithmetic contract is:

```text
compact payload
  → exact represented value
  → computation carrier with additional headroom
  → one requested operation
  → destination-format rounding / saturation
  → compact payload again
```

The compact payload remains the observable stored state. The wider carrier is
temporary computational headroom; it does not add measurement information and
must not silently become the stored result.

For the current ARM Thumb and x86-64 implementations the computation carrier is
Float32. Thus an E3M2 operation is semantically:

```text
E3M2 → Float32 → operate → E3M2
```

and another operation begins by promoting that newly stored E3M2 result again.

This operation boundary matters. A chain such as

```text
a × b + c
```

does not retain an unrounded Float32 product unless a separately named wider
accumulator operation is requested. Ordinary compact arithmetic means:

```text
p = store_E3M2(Float32(a) × Float32(b))
r = store_E3M2(Float32(p) + Float32(c))
```

rather than one fused wide expression followed by a single final narrowing.

## Measurement meaning

Promotion is not a claim of increased physical precision. If a measurement was
observed only to quarters, sevenths, one decimal place, or another declared
resolution, promoting its represented value to Float32 merely prevents the
computation from adding avoidable numerical error. It does not create new
measured digits.

The preferred pipeline is therefore:

```text
measurement
  → honest measurement representation
  → promote for computation
  → requantize to the chosen compact stored representation
  → report no more precision than the measurement supports
```

When a compact format is too coarse to preserve information actually present in
the measurement, use a less coarse compact format for storage. For example,
moving from E3M2 to E5M2/E4M3 or Float16 can be justified by the required
resolution or by repeated computation. The justification is not that a wider
format manufactures extra measurement precision.

## Tiny targets

A target does not have to materialize Float32 in hardware to implement these
semantics. For E3M2 there are only 64 payloads, so a table generated from exact
E3M2 values can return the same post-operation payload directly. That is an
implementation of the same abstract boundary:

```text
exact represented operands → operation → E3M2 rounding → stored E3M2 payload
```

The ATmega, ESP/RV32, MSP430, and RP2040 table paths use this interpretation.
The tables are an implementation technique, not a different numerical contract.

Ootomo–Naruse E5M3 remains storage-only. No arithmetic contract is inferred from
its encoding paper.
